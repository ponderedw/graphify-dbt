"""CLI entry point for dbt-graphify."""

import json
import sys
from collections import defaultdict
from pathlib import Path

from dbt_graphify.parser import (
    find_manifest,
    find_graph_summary,
    parse_manifest,
    parse_graph_summary,
)
from dbt_graphify.builder import (
    build_community_map,
    build_graph_json,
    build_lineage_json,
    write_report,
    write_graphify_root,
    write_graphify_labels,
    write_claude_md,
    generate_html,
)


def _resolve_manifest(path: Path | None, cwd: Path) -> tuple[Path | None, Path]:
    """Return (manifest_path, search_root). Handles explicit file, directory, or None."""
    if path is None:
        return find_manifest(cwd), cwd
    if path.is_dir():
        return find_manifest(path), path
    return path, cwd


def _run_build(manifest_path: Path, out_dir: Path, skip_html: bool) -> None:
    """Core build: parse manifest → write all outputs. Called by main() and watch."""
    cwd = Path.cwd()

    if manifest_path.exists() and manifest_path.stat().st_size > 10:
        print(f"Reading manifest: {manifest_path}")
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)
        project_root = manifest_path.parent.parent
        parsed = parse_manifest(manifest, project_root)
        source_label = "manifest.json"
    else:
        summary_path = find_graph_summary(manifest_path.parent if manifest_path else cwd)
        if summary_path is None:
            raise RuntimeError(
                "No manifest.json or graph_summary.json found with content.\n"
                "Run `dbt compile` or `dbt parse` first, then retry."
            )
        print(f"manifest.json empty — falling back to: {summary_path}")
        with open(summary_path, encoding="utf-8") as f:
            summary = json.load(f)
        project_root = summary_path.parent.parent
        parsed = parse_graph_summary(summary, project_root)
        source_label = "graph_summary.json"

    project_name = parsed.get("project_name", "dbt_project")
    nodes = parsed["nodes"]

    out_dir.mkdir(parents=True, exist_ok=True)

    uid_to_community, community_labels = build_community_map(nodes)

    graph = build_graph_json(parsed, project_name, uid_to_community, community_labels)
    with open(out_dir / "graph.json", "w", encoding="utf-8") as f:
        json.dump(graph, f, indent=2)

    lineage = build_lineage_json(nodes, parsed)
    with open(out_dir / "lineage.json", "w", encoding="utf-8") as f:
        json.dump(lineage, f, indent=2)

    write_report(parsed, out_dir, project_name, lineage, uid_to_community, community_labels)
    write_graphify_root(out_dir, project_root)
    write_graphify_labels(out_dir, community_labels)
    write_claude_md(cwd, manifest_path)

    if not skip_html:
        generate_html(out_dir, out_dir.parent.resolve())

    layer_counts: dict[str, int] = defaultdict(int)
    for n in nodes:
        layer_counts[n["layer"]] += 1

    n_nodes = len(graph["nodes"])
    n_edges = len(graph["edges"])

    print(f"\n✓ {out_dir}/graph.json          ({n_nodes} nodes, {n_edges} edges) [source: {source_label}]")
    print(f"✓ {out_dir}/lineage.json")
    print(f"✓ {out_dir}/GRAPH_REPORT.md")
    print(f"✓ {out_dir}/.graphify_root")
    print(f"✓ {out_dir}/.graphify_labels.json")
    print(f"✓ CLAUDE.md                    (graphify lineage instruction upserted)")
    print(f"\nNode breakdown:")
    for layer in ["source", "staging", "intermediate", "mart", "seed", "macro", "test"]:
        if layer_counts[layer]:
            print(f"  {layer:14s} {layer_counts[layer]}")
    print(f"\nQuery the graph:")
    print(f'  graphify query "which models use stg_students?"')
    print(f'  graphify query "trace the lineage of student_at_risk_report"')
    print(f'  graphify query "what breaks if I change stg_departments?"')


def main():
    args = sys.argv[1:]

    if args and args[0] == "snapshot":
        _cmd_snapshot(args[1:])
        return

    if args and args[0] == "mcp":
        _cmd_mcp(args[1:])
        return

    if args and args[0] == "upload":
        _cmd_upload(args[1:])
        return

    if args and args[0] == "install":
        subcmd = args[1] if len(args) > 1 else ""
        if subcmd == "claude":
            from dbt_graphify.install import install_claude
            install_claude(project="--project" in args[2:])
            return
        print(
            f"Unknown install target: {subcmd!r}. "
            "Did you mean: dbt-graphify install claude",
            file=sys.stderr,
        )
        sys.exit(1)

    raw_path: Path | None = None
    out_dir = Path("graphify-out")
    skip_html = False
    watch_mode = False

    i = 0
    while i < len(args):
        if args[i] in ("--out", "-o") and i + 1 < len(args):
            out_dir = Path(args[i + 1])
            i += 2
        elif args[i].startswith("--out="):
            out_dir = Path(args[i].split("=", 1)[1])
            i += 1
        elif args[i] == "--no-html":
            skip_html = True
            i += 1
        elif args[i] == "--watch":
            watch_mode = True
            i += 1
        elif args[i] in ("-h", "--help"):
            _print_help()
            sys.exit(0)
        elif args[i] in ("-V", "--version"):
            from importlib.metadata import version, PackageNotFoundError
            try:
                print(version("dbt-graphify"))
            except PackageNotFoundError:
                print("dbt-graphify (version unknown)")
            sys.exit(0)
        elif not args[i].startswith("-"):
            raw_path = Path(args[i])
            i += 1
        else:
            print(f"Unknown argument: {args[i]}", file=sys.stderr)
            i += 1

    cwd = Path.cwd()
    manifest_path, _ = _resolve_manifest(raw_path, cwd)

    if watch_mode:
        if manifest_path is None:
            # No manifest found yet — still watch; it may appear after `dbt compile`.
            # Pick the most likely location to watch.
            watch_root = raw_path if (raw_path and raw_path.is_dir()) else cwd
            manifest_path = (
                watch_root / "target" / "manifest.json"
                if (watch_root / "target").exists() or not (watch_root / "dbt_project").exists()
                else watch_root / "dbt_project" / "target" / "manifest.json"
            )
        from dbt_graphify.watch import watch
        watch(manifest_path, out_dir, skip_html)
        return

    if manifest_path is None:
        print(
            "ERROR: No manifest.json or graph_summary.json found with content.\n"
            "Run `dbt compile` or `dbt parse` first, then retry.",
            file=sys.stderr,
        )
        sys.exit(1)

    _run_build(manifest_path, out_dir, skip_html)


def _cmd_snapshot(args: list[str]) -> None:
    """Handle: dbt-graphify snapshot [out_dir] [options]"""
    from dbt_graphify.snapshot import run_snapshot

    out_dir = Path("graphify-out")
    sha: str | None = None
    pr_number: int | None = None
    pr_title: str | None = None
    pr_url: str | None = None
    pr_merged_at: str | None = None

    i = 0
    while i < len(args):
        if args[i] == "--sha" and i + 1 < len(args):
            sha = args[i + 1]; i += 2
        elif args[i].startswith("--sha="):
            sha = args[i].split("=", 1)[1]; i += 1
        elif args[i] == "--pr-number" and i + 1 < len(args):
            pr_number = int(args[i + 1]); i += 2
        elif args[i] == "--pr-title" and i + 1 < len(args):
            pr_title = args[i + 1]; i += 2
        elif args[i] == "--pr-url" and i + 1 < len(args):
            pr_url = args[i + 1]; i += 2
        elif args[i] == "--pr-merged-at" and i + 1 < len(args):
            pr_merged_at = args[i + 1]; i += 2
        elif not args[i].startswith("-"):
            out_dir = Path(args[i]); i += 1
        else:
            i += 1

    run_snapshot(
        out_dir=out_dir,
        sha=sha,
        pr_number=pr_number,
        pr_title=pr_title,
        pr_url=pr_url,
        pr_merged_at=pr_merged_at,
    )


def _cmd_mcp(args: list[str]) -> None:
    """Handle: dbt-graphify mcp [options]

    S3 env vars (alternative to CLI flags):
      S3_PATH               s3://bucket/project  (e.g. s3://my-bucket/dbt-graphify-output)
      AWS_ACCESS_KEY_ID     AWS access key
      AWS_SECRET_ACCESS_KEY AWS secret key
      AWS_DEFAULT_REGION    AWS region (default: us-east-1)
    """
    import os
    from dbt_graphify.mcp_server import SnapshotStore, S3SnapshotStore, run_mcp_server

    snapshots_dir: str | None = None
    s3_bucket: str | None = None
    s3_project: str | None = None
    s3_region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
    transport = os.environ.get("TRANSPORT", "stdio")
    port = int(os.environ.get("PORT", "8080"))
    token: str | None = os.environ.get("TOKEN") or None
    watch_mode = False
    manifest_path: str | None = os.environ.get("MANIFEST_PATH") or None

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
        elif a == "--token" and i + 1 < len(args):
            token = args[i + 1]; i += 2
        elif a.startswith("--token="):
            token = a.split("=", 1)[1]; i += 1
        elif a == "--watch":
            watch_mode = True; i += 1
        elif a in ("--manifest", "-m") and i + 1 < len(args):
            manifest_path = args[i + 1]; i += 2
        elif a.startswith("--manifest="):
            manifest_path = a.split("=", 1)[1]; i += 1
        else:
            i += 1

    # LOCAL_GRAPHIFY=true forces local file mode even if S3_PATH is set
    local_mode = os.environ.get("LOCAL_GRAPHIFY", "").lower() in ("1", "true", "yes")

    # S3_PATH env var: s3://bucket/project
    s3_path_env = os.environ.get("S3_PATH", "")
    if s3_path_env and not s3_bucket and not local_mode:
        stripped = s3_path_env.lstrip("s3://").lstrip("/")
        parts = stripped.split("/", 1)
        s3_bucket = parts[0]
        s3_project = parts[1].strip("/") if len(parts) > 1 else s3_project

    if s3_bucket and s3_project and not local_mode:
        store: SnapshotStore = S3SnapshotStore(s3_bucket, s3_project, s3_region)
    else:
        store = SnapshotStore(snapshots_dir or "graphify-out")

    if watch_mode:
        import sys
        import threading
        from dbt_graphify.watch import watch as _watch
        if not manifest_path:
            print(
                "[dbt-graphify mcp] --watch requires --manifest <path> or MANIFEST_PATH env var",
                file=sys.stderr,
            )
            sys.exit(1)
        out_dir = Path(snapshots_dir or "graphify-out")
        t = threading.Thread(
            target=_watch,
            args=(Path(manifest_path), out_dir),
            kwargs={"skip_html": True},
            daemon=True,
            name="dbt-graphify-watch",
        )
        t.start()
        print(f"[dbt-graphify mcp] watch started → {manifest_path}", flush=True)

    run_mcp_server(store, transport=transport, port=port, token=token)


def _cmd_upload(args: list[str]) -> None:
    """Handle: dbt-graphify upload [out_dir] --s3-path S3_PATH [--snapshot ID] [--region REGION]"""
    import os
    from dbt_graphify.snapshot import upload_to_s3

    out_dir = Path("graphify-out")
    s3_path: str | None = os.environ.get("S3_PATH", "") or None
    snapshot_id: str | None = None
    region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

    i = 0
    while i < len(args):
        if args[i] == "--s3-path" and i + 1 < len(args):
            s3_path = args[i + 1]; i += 2
        elif args[i].startswith("--s3-path="):
            s3_path = args[i].split("=", 1)[1]; i += 1
        elif args[i] == "--snapshot" and i + 1 < len(args):
            snapshot_id = args[i + 1]; i += 2
        elif args[i].startswith("--snapshot="):
            snapshot_id = args[i].split("=", 1)[1]; i += 1
        elif args[i] == "--region" and i + 1 < len(args):
            region = args[i + 1]; i += 2
        elif not args[i].startswith("-"):
            out_dir = Path(args[i]); i += 1
        else:
            i += 1

    if not s3_path:
        print(
            "ERROR: --s3-path is required (or set S3_PATH env var).\n"
            "Example: dbt-graphify upload --s3-path s3://my-bucket/my-project",
            file=sys.stderr,
        )
        sys.exit(1)

    # Parse s3://bucket/project
    stripped = s3_path.lstrip("s3://").lstrip("/")
    parts = stripped.split("/", 1)
    bucket = parts[0]
    project = parts[1].strip("/") if len(parts) > 1 else ""
    if not project:
        print(
            f"ERROR: S3 path must be s3://bucket/project, got {s3_path!r}",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"Uploading {out_dir}/ → s3://{bucket}/{project}/")
    upload_to_s3(out_dir, bucket, project, region=region, snapshot_id=snapshot_id)


def _print_help():
    print(
        "dbt-graphify — parse dbt manifest.json into a graphify knowledge graph\n"
        "\n"
        "Usage:\n"
        "  dbt-graphify [manifest.json|dir] [--out DIR] [--no-html] [--watch]\n"
        "  dbt-graphify snapshot [out_dir] [--sha SHA] [--pr-number N] [--pr-title T]\n"
        "  dbt-graphify upload [out_dir] --s3-path s3://bucket/project [--snapshot ID]\n"
        "  dbt-graphify mcp [--snapshots-dir DIR] [--transport stdio|sse] [--port N]\n"
        "  dbt-graphify install claude [--project]\n"
        "\n"
        "Build graph:\n"
        "  manifest.json   Path to dbt manifest.json (auto-detected if omitted)\n"
        "  dir             Directory to search for manifest.json\n"
        "  --out DIR       Output directory (default: graphify-out/)\n"
        "  --no-html       Skip graph.html generation\n"
        "  --watch         Rebuild whenever manifest.json changes on disk\n"
        "\n"
        "Snapshot — archive current graphify-out into a dated folder:\n"
        "  dbt-graphify snapshot\n"
        "  dbt-graphify snapshot graphify-out --sha abc1234 --pr-number 42\n"
        "  Creates: graphify-out/2026-07-27T1130Z_abc1234/\n"
        "           graphify-out/index.json\n"
        "\n"
        "Upload — push snapshots to S3:\n"
        "  dbt-graphify upload                                    # push all, s3-path from S3_PATH env\n"
        "  dbt-graphify upload graphify-out --s3-path s3://bucket/project\n"
        "  dbt-graphify upload --s3-path s3://b/p --snapshot 2026-07-27T1130Z_abc1234\n"
        "  S3 env vars: S3_PATH=s3://bucket/project  AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...\n"
        "\n"
        "MCP server — expose snapshot history to AI agents:\n"
        "  dbt-graphify mcp                              # stdio, local graphify-out/\n"
        "  dbt-graphify mcp --s3-bucket BUCKET --s3-project PROJECT  # S3 backend\n"
        "  dbt-graphify mcp --transport sse --port 8080  # HTTP / SSE\n"
        "  S3 env vars: S3_PATH=s3://bucket/project  AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...\n"
        "\n"
        "Outputs (build):\n"
        "  graphify-out/graph.json          NetworkX node-link graph\n"
        "  graphify-out/lineage.json        Ancestor/descendant blast-radius maps\n"
        "  graphify-out/GRAPH_REPORT.md     Human-readable architecture summary\n"
        "  graphify-out/.graphify_labels.json Community labels\n"
        "  graphify-out/graph.html          Interactive visualization (via graphify)\n"
    )
