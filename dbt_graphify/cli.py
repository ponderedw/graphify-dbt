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

    if args and args[0] == "install":
        subcmd = args[1] if len(args) > 1 else ""
        if subcmd == "claude":
            from dbt_graphify.install import install_claude
            install_claude()
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


def _print_help():
    print(
        "dbt-graphify — parse dbt manifest.json into a graphify knowledge graph\n"
        "\n"
        "Usage:\n"
        "  dbt-graphify [manifest.json|dir] [--out DIR] [--no-html] [--watch]\n"
        "  dbt-graphify install claude\n"
        "  python -m dbt_graphify [manifest.json|dir] [--out DIR] [--no-html] [--watch]\n"
        "\n"
        "Arguments:\n"
        "  manifest.json   Path to dbt manifest.json (auto-detected if omitted)\n"
        "  dir             Directory to search for manifest.json (e.g. .)\n"
        "  --out DIR       Output directory (default: graphify-out/)\n"
        "  --no-html       Skip graph.html generation via graphify cluster-only\n"
        "  --watch         Rebuild whenever manifest.json changes on disk\n"
        "                  (run dbt compile / dbt run in another terminal)\n"
        "\n"
        "Examples:\n"
        "  dbt-graphify                                   # one-shot, auto-detect\n"
        "  dbt-graphify --watch                           # watch, auto-detect\n"
        "  dbt-graphify . --watch                         # watch cwd\n"
        "  dbt-graphify path/to/target/manifest.json --watch\n"
        "\n"
        "Outputs:\n"
        "  graphify-out/graph.json          NetworkX node-link graph\n"
        "  graphify-out/lineage.json        Ancestor/descendant blast-radius maps\n"
        "  graphify-out/GRAPH_REPORT.md     Human-readable architecture summary\n"
        "  graphify-out/.graphify_root      Project root path\n"
        "  graphify-out/.graphify_labels.json Community labels\n"
        "  graphify-out/graph.html          Interactive visualization (via graphify)\n"
    )
