"""Snapshot command: archive current graphify-out into a dated folder with provenance."""

import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

try:
    from importlib.metadata import version as _pkg_version, PackageNotFoundError
    try:
        _GRAPHIFY_VERSION = _pkg_version("dbt-graphify")
    except PackageNotFoundError:
        _GRAPHIFY_VERSION = "unknown"
except ImportError:
    _GRAPHIFY_VERSION = "unknown"

_SNAPSHOT_ARTIFACTS = [
    "graph.json",
    "lineage.json",
    "GRAPH_REPORT.md",
    ".graphify_labels.json",
    ".graphify_analysis.json",
    "graph.html",
]


# ── ID and index ──────────────────────────────────────────────────────────────

def generate_snapshot_id(sha: str) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%MZ")
    return f"{ts}_{sha[:7]}"


def load_index(out_dir: Path) -> list[dict]:
    index_path = out_dir / "index.json"
    if index_path.exists():
        return json.loads(index_path.read_text(encoding="utf-8"))
    return []


def save_index(out_dir: Path, index: list[dict]) -> None:
    (out_dir / "index.json").write_text(
        json.dumps(index, indent=2), encoding="utf-8"
    )


# ── Git helpers ───────────────────────────────────────────────────────────────

def _git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], capture_output=True, text=True, check=True,
    )
    return result.stdout.strip()


def get_head_sha() -> Optional[str]:
    try:
        return _git("rev-parse", "HEAD")
    except subprocess.CalledProcessError:
        return None


def get_git_commits(base_sha: str, head_sha: str) -> list[dict]:
    if base_sha == head_sha:
        return []
    try:
        out = _git("log", "--format=%H|%an|%aI|%s", f"{base_sha}..{head_sha}")
        commits = []
        for line in out.splitlines():
            parts = line.split("|", 3)
            if len(parts) == 4:
                commits.append({
                    "sha": parts[0],
                    "author": parts[1],
                    "date": parts[2],
                    "message": parts[3],
                })
        return commits
    except subprocess.CalledProcessError:
        return []



def resolve_base_sha(out_dir: Path, head_sha: str) -> tuple[str, Optional[str]]:
    """Return (base_sha, previous_snapshot_id).

    Uses the previous snapshot's head_sha so the diff covers exactly the
    changes between the two archived folders.  Falls back to HEAD~1 on first run.
    """
    index = load_index(out_dir)
    if index:
        prev = index[0]
        return prev["head_sha"], prev["snapshot_id"]
    try:
        return _git("rev-parse", "HEAD~1"), None
    except subprocess.CalledProcessError:
        return head_sha, None  # single-commit repo, diff will be empty



# ── Meta and index entry ──────────────────────────────────────────────────────

def build_meta(
    snapshot_id: str,
    head_sha: str,
    base_sha: str,
    previous_snapshot: Optional[str],
    commits: list[dict],
    pr_info: Optional[dict] = None,
) -> dict:
    meta: dict = {
        "snapshot_id": snapshot_id,
        "head_sha": head_sha,
        "base_sha": base_sha,
        "previous_snapshot": previous_snapshot,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "commits": commits,
        "dbt_graphify_version": _GRAPHIFY_VERSION,
    }
    if pr_info:
        meta["pr"] = pr_info
    return meta


def build_index_entry(meta: dict) -> dict:
    entry: dict = {
        "snapshot_id": meta["snapshot_id"],
        "head_sha": meta["head_sha"],
        "base_sha": meta["base_sha"],
        "timestamp": meta["timestamp"],
        "nodes_count": meta.get("nodes_count", 0),
        "edges_count": meta.get("edges_count", 0),
    }
    if pr := meta.get("pr"):
        entry["pr_number"] = pr.get("number")
        entry["pr_title"] = pr.get("title")
        entry["pr_url"] = pr.get("url")
        entry["merged_at"] = pr.get("merged_at")
    return entry


# ── Main snapshot orchestrator ────────────────────────────────────────────────

def run_snapshot(
    out_dir: Path,
    sha: Optional[str] = None,
    pr_number: Optional[int] = None,
    pr_title: Optional[str] = None,
    pr_url: Optional[str] = None,
    pr_merged_at: Optional[str] = None,
) -> str:
    """Archive the current graphify-out into a dated snapshot folder.

    Returns the snapshot_id of the new folder.
    """
    graph_path = out_dir / "graph.json"
    if not graph_path.exists():
        raise FileNotFoundError(
            f"graph.json not found in {out_dir}. "
            "Run `dbt-graphify` first to generate the graph."
        )

    if sha is None:
        sha = get_head_sha()
        if sha is None:
            raise RuntimeError("Could not determine HEAD SHA. Pass --sha explicitly.")

    base_sha, previous_snapshot = resolve_base_sha(out_dir, sha)
    snapshot_id = generate_snapshot_id(sha)

    print(f"\n[dbt-graphify snapshot] {snapshot_id}")
    print(f"  head: {sha[:12]}  base: {base_sha[:12]}")

    commits = get_git_commits(base_sha, sha)
    print(f"  {len(commits)} commits")

    new_graph = json.loads(graph_path.read_text(encoding="utf-8"))

    pr_info = None
    if pr_number is not None:
        pr_info = {
            "number": pr_number,
            "title": pr_title or "",
            "url": pr_url or "",
            "merged_at": pr_merged_at or "",
        }

    meta = build_meta(
        snapshot_id=snapshot_id,
        head_sha=sha,
        base_sha=base_sha,
        previous_snapshot=previous_snapshot,
        commits=commits,
        pr_info=pr_info,
    )
    meta["nodes_count"] = len(new_graph.get("nodes", []))
    meta["edges_count"] = len(new_graph.get("edges", []))

    # Create snapshot folder and copy artifacts
    snap_dir = out_dir / snapshot_id
    snap_dir.mkdir(parents=True, exist_ok=True)

    copied = []
    for fname in _SNAPSHOT_ARTIFACTS:
        src = out_dir / fname
        if src.exists():
            shutil.copy2(src, snap_dir / fname)
            copied.append(fname)

    (snap_dir / "meta.json").write_text(
        json.dumps(meta, indent=2), encoding="utf-8"
    )
    print(f"  ✓ {snap_dir}/  ({', '.join(copied + ['meta.json'])})")

    # Update index.json
    index = load_index(out_dir)
    entry = build_index_entry(meta)
    index = [entry] + [e for e in index if e.get("snapshot_id") != snapshot_id]
    save_index(out_dir, index)
    print(f"  ✓ index.json  ({len(index)} snapshots total)")

    return snapshot_id


# ── S3 upload ─────────────────────────────────────────────────────────────────

def upload_to_s3(
    out_dir: Path,
    bucket: str,
    project: str,
    region: str = "us-east-1",
    snapshot_id: Optional[str] = None,
) -> None:
    """Push a snapshot (or all new snapshots) to S3 and merge the index.

    S3 layout:
      s3://{bucket}/dbt-graphify/{project}/
        index.json
        runs/{snapshot_id}/graph.json
        runs/{snapshot_id}/lineage.json
        runs/{snapshot_id}/meta.json
        ...

    If snapshot_id is None, uploads whatever is in index.json that isn't
    already on S3 (skips entries whose S3 prefix exists).
    """
    try:
        import boto3
        s3 = boto3.client("s3", region_name=region)
    except ImportError:
        raise ImportError(
            "boto3 is required for S3 upload. "
            "Install with: pip install 'dbt-graphify[s3]'"
        )

    prefix = project

    # Determine which snapshot(s) to upload
    local_index = load_index(out_dir)
    if snapshot_id is not None:
        to_upload = [snapshot_id]
    else:
        to_upload = [e["snapshot_id"] for e in local_index]

    for sid in to_upload:
        snap_dir = out_dir / sid
        if not snap_dir.is_dir():
            print(f"  [skip] {sid} — folder not found locally")
            continue

        # Check if already uploaded
        check_key = f"{prefix}/runs/{sid}/meta.json"
        try:
            s3.head_object(Bucket=bucket, Key=check_key)
            print(f"  [skip] {sid} — already on S3")
            continue
        except Exception:
            pass

        print(f"  [upload] {sid}")
        for fpath in snap_dir.iterdir():
            if fpath.is_file():
                key = f"{prefix}/runs/{sid}/{fpath.name}"
                s3.upload_file(str(fpath), bucket, key)
                print(f"    → s3://{bucket}/{key}")

    # Merge index: fetch S3 index, merge with local, push back
    s3_index: list[dict] = []
    index_key = f"{prefix}/index.json"
    try:
        resp = s3.get_object(Bucket=bucket, Key=index_key)
        s3_index = json.loads(resp["Body"].read().decode("utf-8"))
    except Exception:
        pass

    merged_by_id: dict[str, dict] = {e["snapshot_id"]: e for e in s3_index}
    for entry in local_index:
        merged_by_id[entry["snapshot_id"]] = entry
    merged = sorted(merged_by_id.values(), key=lambda e: e.get("timestamp", ""), reverse=True)

    import tempfile, os
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as tf:
        json.dump(merged, tf, indent=2)
        tf_path = tf.name
    try:
        s3.upload_file(tf_path, bucket, index_key)
        print(f"  ✓ index.json → s3://{bucket}/{index_key}  ({len(merged)} snapshots)")
    finally:
        os.unlink(tf_path)
