"""MCP server exposing dbt-graphify snapshot history.

Each tool that accepts `ref` understands:
  "latest"                    → most recent snapshot
  "2026-07-27"                → nearest snapshot on or before that date (prefix match)
  "2026-07-27T1130Z_a1b2c3d"  → exact snapshot_id
  "a1b2c3d"                   → SHA prefix match against head_sha

Two backends:
  SnapshotStore   — reads from a local graphify-out/ directory
  S3SnapshotStore — downloads from S3 into a local cache, same interface

Designed to pair with a git MCP server:
  git MCP  → which commits touched models/staging/stg_orders.sql?
  this MCP → find_by_sha("abc1234") → get_blast_radius("stg_orders", ref=snapshot_id)
"""

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Optional


# ── Shared resolution logic ───────────────────────────────────────────────────

def _resolve_ref(index: list[dict], ref: str) -> Optional[str]:
    """Resolve a ref string to a snapshot_id."""
    if ref == "latest":
        return index[0]["snapshot_id"] if index else None

    for entry in index:
        if entry.get("snapshot_id") == ref:
            return ref
    for entry in index:
        if entry.get("head_sha", "").startswith(ref):
            return entry["snapshot_id"]
    for entry in index:
        if entry.get("timestamp", "").startswith(ref):
            return entry["snapshot_id"]
    for entry in index:
        if entry.get("snapshot_id", "").startswith(ref):
            return entry["snapshot_id"]
    return None


# ── Local snapshot store ──────────────────────────────────────────────────────

class SnapshotStore:
    """Reads snapshots from a local graphify-out/ directory."""

    def __init__(self, snapshots_dir: str | Path):
        self.root = Path(snapshots_dir)
        if not self.root.exists():
            raise FileNotFoundError(f"Snapshots directory not found: {self.root}")

    def index(self) -> list[dict]:
        p = self.root / "index.json"
        return json.loads(p.read_text(encoding="utf-8")) if p.exists() else []

    def resolve(self, ref: str) -> Optional[str]:
        return _resolve_ref(self.index(), ref)

    def resolve_or_raise(self, ref: str) -> str:
        sid = self.resolve(ref)
        if sid is None:
            available = [e["snapshot_id"] for e in self.index()[:5]]
            raise ValueError(
                f"Snapshot {ref!r} not found. "
                f"Recent snapshots: {available}. "
                "Use list_snapshots() to browse all."
            )
        return sid

    def snap_dir(self, snapshot_id: str) -> Path:
        """Return the directory containing graph.json for this snapshot."""
        if snapshot_id == "__root__":
            return self.root
        return self.root / snapshot_id

    def graph_path(self, snapshot_id: str) -> Path:
        return self.snap_dir(snapshot_id) / "graph.json"

    def read_json(self, snapshot_id: str, filename: str) -> dict:
        p = self.snap_dir(snapshot_id) / filename
        if not p.exists():
            raise FileNotFoundError(f"No {filename} for snapshot {snapshot_id!r}")
        return json.loads(p.read_text(encoding="utf-8"))

    def read_meta(self, snapshot_id: str) -> dict:
        return self.read_json(snapshot_id, "meta.json")

    def read_graph(self, snapshot_id: str) -> dict:
        return self.read_json(snapshot_id, "graph.json")

    def read_lineage(self, snapshot_id: str) -> dict:
        return self.read_json(snapshot_id, "lineage.json")


# ── S3 snapshot store ─────────────────────────────────────────────────────────

class S3SnapshotStore(SnapshotStore):
    """Downloads snapshots from S3 into a local cache, then delegates to SnapshotStore.

    Expected S3 layout:
      s3://{bucket}/{project}/
        index.json
        runs/{snapshot_id}/graph.json
        runs/{snapshot_id}/lineage.json
        runs/{snapshot_id}/meta.json
        runs/{snapshot_id}/GRAPH_REPORT.md
        runs/{snapshot_id}/.graphify_labels.json
    """

    _SNAPSHOT_FILES = [
        "graph.json", "lineage.json", "meta.json",
        "GRAPH_REPORT.md", ".graphify_labels.json", ".graphify_analysis.json",
    ]

    def __init__(self, bucket: str, project: str, region: str = "us-east-1"):
        try:
            import boto3
            self._s3 = boto3.client("s3", region_name=region)
        except ImportError:
            raise ImportError(
                "boto3 is required for S3 mode. "
                "Install with: pip install 'dbt-graphify[s3]'"
            )
        self.bucket = bucket
        self.s3_prefix = project

        # Local cache at ~/.cache/dbt-graphify/{bucket}/{project}/
        cache_root = Path.home() / ".cache" / "dbt-graphify" / bucket / project
        cache_root.mkdir(parents=True, exist_ok=True)
        super().__init__(cache_root)

    def _s3_key(self, *parts: str) -> str:
        return "/".join([self.s3_prefix, *parts])

    def index(self) -> list[dict]:
        try:
            resp = self._s3.get_object(Bucket=self.bucket, Key=self._s3_key("index.json"))
            data = json.loads(resp["Body"].read().decode("utf-8"))
            (self.root / "index.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
            return data
        except Exception:
            # Fall back to cached copy
            p = self.root / "index.json"
            return json.loads(p.read_text(encoding="utf-8")) if p.exists() else []

    def snap_dir(self, snapshot_id: str) -> Path:
        """Download snapshot from S3 if not already cached, return local dir."""
        if snapshot_id == "__root__":
            # Resolve "latest" to the most recent snapshot via index
            idx = self.index()
            if not idx:
                return self.root
            snapshot_id = idx[0]["snapshot_id"]

        local_dir = self.root / "runs" / snapshot_id
        if not local_dir.exists():
            local_dir.mkdir(parents=True, exist_ok=True)
            for fname in self._SNAPSHOT_FILES:
                key = self._s3_key("runs", snapshot_id, fname)
                dest = local_dir / fname
                try:
                    self._s3.download_file(self.bucket, key, str(dest))
                except Exception:
                    pass
        return local_dir



# ── Graphify subprocess helpers ───────────────────────────────────────────────

def _graphify_bin() -> Optional[str]:
    return shutil.which("graphify")


def _run_graphify(graph_json_path: Path, *cmd_args: str) -> str:
    """Run any graphify command with --graph pointing at a specific graph.json."""
    gbin = _graphify_bin()
    if not gbin:
        return (
            "graphify is not installed in this environment. "
            "Install with: pip install graphifyy"
        )
    try:
        result = subprocess.run(
            [gbin, *cmd_args, "--graph", str(graph_json_path)],
            capture_output=True, text=True, timeout=60,
        )
        output = result.stdout.strip()
        if result.returncode != 0 and result.stderr.strip():
            output = (output + "\n\n[stderr]\n" + result.stderr.strip()[:500]).strip()
        return output or "(no output)"
    except subprocess.TimeoutExpired:
        return f"Error: graphify timed out (60 s)."
    except Exception as exc:
        return f"Error running graphify: {exc}"


# ── MCP server ────────────────────────────────────────────────────────────────

def run_mcp_server(
    store: SnapshotStore,
    transport: str = "stdio",
    port: int = 8080,
    token: Optional[str] = None,
) -> None:
    try:
        from mcp.server.fastmcp import FastMCP
    except ImportError:
        raise ImportError(
            "mcp package is required. "
            "Install with: pip install 'dbt-graphify[mcp-server]'"
        )

    server = FastMCP("dbt-graphify")

    def _sid(ref: str) -> str:
        """Resolve ref → snapshot_id, defaulting to latest."""
        if ref == "latest":
            sid = store.resolve("latest")
            return sid or "__root__"
        return store.resolve_or_raise(ref)

    @server.tool()
    def list_snapshots(limit: int = 20) -> str:
        """List available graph snapshots, newest first.

        Returns snapshot_id, head_sha, timestamp, nodes_count, edges_count.
        Pass a snapshot_id from this list as `ref` in query() or diff().
        """
        return json.dumps(store.index()[:limit], indent=2)

    @server.tool()
    def find_by_sha(sha: str) -> str:
        """Resolve a git commit SHA to a snapshot_id.

        Use this to bridge git MCP → graph query:
          1. git MCP finds the SHA that changed a model
          2. find_by_sha("abc1234") → snapshot_id
          3. query("what broke?", ref=snapshot_id)

        Accepts full or partial SHA. Checks head_sha first, then scans
        commits inside each meta.json.
        """
        idx = store.index()
        if not idx:
            return json.dumps({"error": "No snapshots found."})

        for entry in idx:
            if entry.get("head_sha", "").startswith(sha):
                return json.dumps({
                    "snapshot_id": entry["snapshot_id"],
                    "matched": "head_sha",
                    "timestamp": entry["timestamp"],
                    "nodes_count": entry.get("nodes_count"),
                }, indent=2)

        for entry in idx:
            try:
                meta = store.read_meta(entry["snapshot_id"])
                for commit in meta.get("commits", []):
                    if commit.get("sha", "").startswith(sha):
                        return json.dumps({
                            "snapshot_id": entry["snapshot_id"],
                            "matched": "commit_in_snapshot",
                            "commit_sha": commit["sha"],
                            "commit_message": commit.get("message"),
                        }, indent=2)
            except FileNotFoundError:
                continue

        return json.dumps({
            "error": f"No snapshot found for SHA {sha!r}.",
            "tip": "Use list_snapshots() to browse available snapshots.",
        })

    @server.tool()
    def query(question: str, ref: str = "latest") -> str:
        """Query the dbt lineage graph with a natural-language question.

        This is the primary tool. It routes the question to the right graph
        version and returns the lineage answer.

        question: anything about models, dependencies, blast radius, lineage paths.
          "which models depend on stg_orders?"
          "what breaks if I change stg_students?"
          "trace the lineage of mart_revenue"
          "how does data get from src_ps_students to mart_at_risk_report?"

        ref: which graph version to query — defaults to the latest snapshot.
          "latest"                   → most recent snapshot
          "2026-07-27"               → snapshot nearest to that date
          "a1b2c3d"                  → snapshot whose head_sha starts with this
          "2026-07-27T1130Z_a1b2c3d" → exact snapshot_id from list_snapshots()

        Typical workflow with git MCP:
          git MCP → find_by_sha("abc1234") → snapshot_id
          query("what models changed?", ref=snapshot_id)
        """
        sid = _sid(ref)
        return _run_graphify(store.graph_path(sid), "query", question)

    @server.tool()
    def diff_snapshots(from_ref: str, to_ref: str) -> str:
        """Compare two graph snapshots: nodes and edges added or removed.

        from_ref / to_ref: "latest" | date prefix "2026-07-27" | SHA prefix "a1b2c3d" | exact snapshot_id
        Use list_snapshots() to browse available snapshot_ids.

        Example: diff_snapshots("2026-07-01", "latest")
        """
        from_sid = _sid(from_ref)
        to_sid = _sid(to_ref)

        old = store.read_graph(from_sid)
        new = store.read_graph(to_sid)
        old_ids = {n["id"] for n in old.get("nodes", [])}
        new_ids = {n["id"] for n in new.get("nodes", [])}
        old_edges = {(e["source"], e["target"]) for e in old.get("edges", [])}
        new_edges = {(e["source"], e["target"]) for e in new.get("edges", [])}

        return json.dumps({
            "from_snapshot": from_sid,
            "to_snapshot": to_sid,
            "nodes_added": sorted(new_ids - old_ids),
            "nodes_removed": sorted(old_ids - new_ids),
            "edges_added": [{"source": s, "target": t} for s, t in sorted(new_edges - old_edges)],
            "edges_removed": [{"source": s, "target": t} for s, t in sorted(old_edges - new_edges)],
        }, indent=2)

    if transport == "sse" and token:
        # Authenticated SSE: mount MCP behind a FastAPI app with bearer-token middleware
        try:
            import uvicorn
            from fastapi import FastAPI
            from fastapi.responses import JSONResponse
            from starlette.status import HTTP_401_UNAUTHORIZED
            from starlette.types import ASGIApp, Receive, Scope, Send
        except ImportError:
            raise ImportError(
                "fastapi and uvicorn are required for authenticated SSE. "
                "Install with: pip install 'dbt-graphify[mcp-server]'"
            )

        _token = token

        class _AuthMiddleware:
            """ASGI bearer-token middleware — safe for SSE streaming."""

            def __init__(self, app: ASGIApp) -> None:
                self.app = app

            async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
                if scope["type"] == "http":
                    headers = {k.lower(): v for k, v in scope.get("headers", [])}
                    auth = headers.get(b"authorization", b"").decode()
                    bearer = auth.removeprefix("Bearer ").strip()
                    if not auth.startswith("Bearer ") or bearer != _token:
                        resp = JSONResponse(
                            status_code=HTTP_401_UNAUTHORIZED,
                            content={"detail": "Missing or invalid authorization header"},
                        )
                        await resp(scope, receive, send)
                        return
                await self.app(scope, receive, send)

        app = FastAPI(title="dbt-graphify MCP")
        app.add_middleware(_AuthMiddleware)
        app.mount("/", server.sse_app())
        uvicorn.run(app, host="0.0.0.0", port=port)
    elif transport == "sse":
        server.run(transport="sse", port=port)
    else:
        server.run()


def main() -> None:
    import sys
    args = sys.argv[1:]

    snapshots_dir: Optional[str] = None
    s3_bucket: Optional[str] = None
    s3_project: Optional[str] = None
    s3_region = "us-east-1"
    transport = "stdio"
    port = 8080

    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--snapshots-dir", "-d") and i + 1 < len(args):
            snapshots_dir = args[i + 1]; i += 2
        elif a.startswith("--snapshots-dir="):
            snapshots_dir = a.split("=", 1)[1]; i += 1
        elif a == "--s3-bucket" and i + 1 < len(args):
            s3_bucket = args[i + 1]; i += 2
        elif a.startswith("--s3-bucket="):
            s3_bucket = a.split("=", 1)[1]; i += 1
        elif a == "--s3-project" and i + 1 < len(args):
            s3_project = args[i + 1]; i += 2
        elif a.startswith("--s3-project="):
            s3_project = a.split("=", 1)[1]; i += 1
        elif a == "--s3-region" and i + 1 < len(args):
            s3_region = args[i + 1]; i += 2
        elif a == "--transport" and i + 1 < len(args):
            transport = args[i + 1]; i += 2
        elif a == "--port" and i + 1 < len(args):
            port = int(args[i + 1]); i += 2
        else:
            i += 1

    if s3_bucket and s3_project:
        store: SnapshotStore = S3SnapshotStore(s3_bucket, s3_project, s3_region)
        print(
            f"[dbt-graphify mcp] S3 mode: s3://{s3_bucket}/dbt-graphify/{s3_project}/",
            flush=True,
        )
    else:
        path = snapshots_dir or "graphify-out"
        store = SnapshotStore(path)
        print(f"[dbt-graphify mcp] local mode: {Path(path).resolve()}", flush=True)

    run_mcp_server(store, transport=transport, port=port)
