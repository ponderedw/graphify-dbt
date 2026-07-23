"""Build graphify-out/ artifacts from parsed dbt graph data."""

import json
import shutil
import subprocess
from collections import defaultdict, deque
from pathlib import Path


# ── Community detection ───────────────────────────────────────────────────────

_LAYER_COMMUNITY = {
    "source": 0,
    "staging": 1,
    "intermediate": 2,
    "mart": 3,
    "seed": 4,
    "macro": 5,
    "test": 6,
}


def build_community_map(nodes: list[dict]) -> tuple[dict[str, int], dict[int, str]]:
    """
    Assign community integers via priority chain:
      1. dbt group field
      2. first tag
      3. Louvain topology clustering (if networkx available)
      4. layer-based fallback

    Returns (uid -> community_int, community_int -> label).
    """
    # Check if any node has groups or tags
    group_index: dict[str, int] = {}
    tag_index: dict[str, int] = {}
    counter = [0]

    def _get_or_create(index: dict, key: str) -> int:
        if key not in index:
            index[key] = counter[0]
            counter[0] += 1
        return index[key]

    has_groups = any(n.get("group") for n in nodes)
    has_tags = any(n.get("tags") for n in nodes) and not has_groups

    if has_groups:
        uid_to_community = {}
        for n in nodes:
            group = n.get("group") or ""
            cid = _get_or_create(group_index, group or "__ungrouped__")
            uid_to_community[n["uid"]] = cid
        labels = {v: k for k, v in group_index.items()}
        return uid_to_community, labels

    if has_tags:
        uid_to_community = {}
        for n in nodes:
            tags = n.get("tags") or []
            key = tags[0] if tags else "__untagged__"
            cid = _get_or_create(tag_index, key)
            uid_to_community[n["uid"]] = cid
        labels = {v: k for k, v in tag_index.items()}
        return uid_to_community, labels

    # Try topology clustering with networkx
    try:
        import networkx as nx
        G = nx.DiGraph()
        for n in nodes:
            G.add_node(n["uid"])
        for n in nodes:
            for tgt in n.get("downstream", []):
                G.add_edge(n["uid"], tgt)

        undirected = G.to_undirected()
        try:
            from networkx.algorithms.community import louvain_communities
            communities = louvain_communities(undirected, seed=42)
        except (ImportError, Exception):
            # greedy modularity as fallback
            from networkx.algorithms.community import greedy_modularity_communities
            communities = list(greedy_modularity_communities(undirected))

        uid_to_community = {}
        labels = {}
        for cid, members in enumerate(communities):
            # Name the community after the most-connected node in the cluster
            best = max(members, key=lambda n: G.degree(n), default=next(iter(members)))
            labels[cid] = best.split(".")[-1]
            for uid in members:
                uid_to_community[uid] = cid
        # Fill any missing (isolated nodes)
        for n in nodes:
            if n["uid"] not in uid_to_community:
                uid_to_community[n["uid"]] = _LAYER_COMMUNITY.get(n["layer"], 0)
        return uid_to_community, labels

    except ImportError:
        pass

    # Layer fallback
    uid_to_community = {n["uid"]: _LAYER_COMMUNITY.get(n["layer"], 0) for n in nodes}
    labels = {v: k.capitalize() for k, v in _LAYER_COMMUNITY.items()}
    return uid_to_community, labels


# ── BFS ───────────────────────────────────────────────────────────────────────

def bfs_reachable(start: str, adjacency: dict[str, list]) -> list[str]:
    visited, queue = set(), deque(adjacency.get(start, []))
    while queue:
        node = queue.popleft()
        if node not in visited:
            visited.add(node)
            queue.extend(n for n in adjacency.get(node, []) if n not in visited)
    return sorted(visited)


# ── Descriptions ──────────────────────────────────────────────────────────────

_AUTO_DESCS: dict[str, str] = {
    "stg_students": "Cleans raw students. Derives: full_name, age, years_enrolled, academic_standing, current_status.",
    "stg_courses": "Cleans raw courses. Derives: difficulty_description, credit_category.",
    "stg_departments": "Cleans raw departments. Derives: department_size, budget_millions.",
    "stg_faculty": "Cleans raw faculty. Derives: full_name, years_of_service, rank_level, salary_band.",
    "stg_enrollments": "Cleans raw enrollments. Derives: grade_category, enrollment_status, attendance_level.",
    "stg_semesters": "Cleans raw semesters. Derives: semester_type, semester_duration_days, semester_status.",
    "stg_class_sessions": "Cleans raw class sessions. Derives: day_of_week, session_hour, time_block, day_name.",
    "stg_assignments": "Cleans raw assignments. Derives: assignment_category, due_status, days_until_due, weight_category.",
    "stg_assignment_submissions": "Cleans raw submissions. Derives: grading_status, submission_timeliness, feedback_status.",
    "stg_financial_aid": "Cleans raw financial aid. Derives: aid_category, support_level, disbursement_period.",
    "stg_tuition_payments": "Cleans raw tuition payments. Derives: total_payment, payment_timeliness, payment_method_category.",
    "int_student_enrollment_history": "Per-enrollment grain with window aggregates per student: total_enrollments, credits_attempted/earned, failed_courses_count, avg_grade_points.",
    "int_course_performance_metrics": "Per-course aggregates: total_enrollments, pass_rate, withdrawal_rate, avg_grade_points, avg_attendance.",
    "int_department_analytics": "Per-department aggregates: faculty_count, course_count, student_count, avg_faculty_salary, student_faculty_ratio.",
    "int_faculty_teaching_load": "Per-faculty workload: unique_courses_taught, total_students_taught, salary_per_course, teaching_load_category.",
    "int_student_at_risk_indicators": "Per-student risk scoring: 8 binary flags summed into risk_level (Low/Moderate/High/Critical) + recommended_intervention.",
    "student_academic_summary": "Final mart: student academic profile with class_standing, completion_rate, progress_indicator.",
    "student_financial_profile": "Final mart: student financial summary with aid_recipient_category, payment_reliability, primary_aid_type.",
    "faculty_performance_dashboard": "Final mart: faculty dashboard with teaching_impact_category, engagement_effectiveness, career_stage.",
    "department_overview": "Final mart: department overview with scale, efficiency ratios, faculty/student metrics.",
    "course_performance_summary": "Final mart: course performance category (High/Good/Average/Needs Improvement) with grade distribution.",
    "student_at_risk_report": "Final mart: at-risk students only (risk_level != Low Risk), ordered by total_risk_score for intervention prioritization.",
}


def _auto_desc(name: str, layer: str) -> str:
    return _AUTO_DESCS.get(name, f"{layer.capitalize()} model: {name}")


def _infer_materialized(layer: str, config: dict) -> str:
    if config and "materialized" in config:
        return config["materialized"]
    return {
        "source": "external",
        "staging": "view",
        "intermediate": "view",
        "mart": "table",
        "seed": "seed",
        "macro": "macro",
    }.get(layer, "view")


# ── graph.json ────────────────────────────────────────────────────────────────

def build_graph_json(
    parsed: dict,
    project_name: str,
    uid_to_community: dict[str, int],
    community_labels: dict[int, str],
) -> dict:
    """Build graphify-compatible graph.json in NetworkX node-link format.

    All node properties are FLAT at the top level — no nested 'properties' key.
    Required by graphify's node_link_graph() loader.
    """
    nodes_out = []
    edges_out = []

    for n in parsed["nodes"]:
        uid = n["uid"]
        name = n["name"]
        layer = n["layer"]
        description = n.get("description") or _auto_desc(name, layer)
        materialized = _infer_materialized(layer, n.get("config", {}))

        # FLAT node — all fields at top level
        node = {
            "id": uid,
            "label": name,
            "community": uid_to_community.get(uid, 0),
            "type": n["resource_type"],
            "layer": layer,
            "source_file": n.get("file_path", ""),
            "description": description,
            "materialized": materialized,
            "upstream": n.get("upstream", []),
            "downstream": n.get("downstream", []),
            "columns": n.get("columns", []),
            "refs": n.get("refs", []),
            "sources_used": n.get("sources", []),
            "tags": n.get("tags", []),
            "database": n.get("database", ""),
            "schema": n.get("schema", ""),
        }

        nodes_out.append(node)

        # Edges: upstream → this node
        for parent_uid in n.get("upstream", []):
            edges_out.append({
                "source": parent_uid,
                "target": uid,
                "type": "LINEAGE",
                "provenance": "EXTRACTED",
                "key": 0,
            })

    # God nodes: one per layer (not added as graph nodes to avoid polluting BFS)
    layer_groups: dict[str, list[str]] = defaultdict(list)
    for n in parsed["nodes"]:
        if n["layer"] not in ("test", "macro"):
            layer_groups[n["layer"]].append(n["name"])

    god_nodes = [
        {
            "layer": layer,
            "label": f"LAYER:{layer.upper()}",
            "count": len(names),
            "models": sorted(names),
        }
        for layer, names in sorted(layer_groups.items())
    ]

    return {
        "directed": True,
        "multigraph": False,
        "graph": {
            "project": project_name,
            "generated_by": "dbt-graphify",
            "communities": {
                str(cid): label for cid, label in community_labels.items()
            },
        },
        "god_nodes": god_nodes,
        "nodes": nodes_out,
        "edges": edges_out,
    }


# ── lineage.json ──────────────────────────────────────────────────────────────

def build_lineage_json(nodes: list[dict], parsed: dict) -> dict:
    adj_up = parsed.get("upstream", {})
    adj_down = parsed.get("downstream", {})

    ancestors = {n["uid"]: bfs_reachable(n["uid"], adj_up) for n in nodes}
    descendants = {n["uid"]: bfs_reachable(n["uid"], adj_down) for n in nodes}

    return {
        "description": (
            "Blast-radius maps. "
            "'ancestors' = full upstream chain (what a node reads from). "
            "'descendants' = full downstream chain (what breaks if this node changes)."
        ),
        "ancestors": ancestors,
        "descendants": descendants,
    }


# ── GRAPH_REPORT.md ───────────────────────────────────────────────────────────

def write_report(
    parsed: dict,
    out_dir: Path,
    project_name: str,
    lineage: dict,
    uid_to_community: dict[str, int],
    community_labels: dict[int, str],
):
    nodes = parsed["nodes"]

    layer_order = ["source", "staging", "intermediate", "mart", "seed", "macro"]
    layer_labels = {
        "source": "Sources",
        "staging": "Staging — views, clean & standardize",
        "intermediate": "Intermediate — views, aggregate & join",
        "mart": "Marts — tables, BI-ready",
        "seed": "Seeds — static reference data",
        "macro": "Macros — reusable Jinja2 logic",
    }

    lines = [
        f"# dbt Knowledge Graph — {project_name}",
        "",
        "_Generated by dbt-graphify. Query: `graphify query \"<question>\"`_",
        "",
        "## Architecture",
        "",
        "```",
        "Source tables ──► staging/ (views, clean + standardize)",
        "                      │",
        "                      ▼",
        "               intermediate/ (views, aggregate + join)",
        "                      │",
        "                      ▼",
        "                  marts/ (tables, BI-ready outputs)",
        "```",
        "",
        "## Node Inventory",
        "",
    ]

    for layer in layer_order:
        layer_nodes = [n for n in nodes if n["layer"] == layer]
        if not layer_nodes:
            continue
        lines.append(f"### {layer_labels.get(layer, layer)} ({len(layer_nodes)})")
        lines.append("")
        for n in sorted(layer_nodes, key=lambda x: x["name"]):
            desc = n.get("description") or _auto_desc(n["name"], layer)
            mat = _infer_materialized(layer, n.get("config", {}))
            up = [u.split(".")[-1] for u in n.get("upstream", [])]
            down = [d.split(".")[-1] for d in n.get("downstream", [])]
            cols = n.get("columns", [])
            community_label = community_labels.get(uid_to_community.get(n["uid"], 0), "")
            lines.append(f"**{n['name']}** `[{mat}]` · community: _{community_label}_")
            lines.append(f"> {desc}")
            if up:
                lines.append(f"- Reads from: `{'`, `'.join(sorted(up))}`")
            if down:
                lines.append(f"- Feeds into: `{'`, `'.join(sorted(down))}`")
            if cols:
                shown = cols[:15]
                suffix = "..." if len(cols) > 15 else ""
                lines.append(f"- Columns: `{'`, `'.join(shown)}`{suffix}")
            lines.append("")

    # Blast-radius table
    lines += [
        "## Blast Radius",
        "",
        "Downstream models affected when a model changes:",
        "",
        "| Model | Affected downstream |",
        "|---|---|",
    ]

    for n in sorted(nodes, key=lambda x: -len(lineage["descendants"].get(x["uid"], []))):
        if n["layer"] in ("test", "macro", "seed"):
            continue
        desc = [d.split(".")[-1] for d in lineage["descendants"].get(n["uid"], [])]
        if desc:
            lines.append(f"| `{n['name']}` | {', '.join(sorted(desc))} |")

    # Community legend
    lines += [
        "",
        "## Communities",
        "",
        "| ID | Label |",
        "|---|---|",
    ]
    for cid in sorted(community_labels):
        lines.append(f"| {cid} | {community_labels[cid]} |")

    lines += [
        "",
        "---",
        "_Regenerate: `dbt-graphify` or `python -m dbt_graphify`_",
    ]

    (out_dir / "GRAPH_REPORT.md").write_text("\n".join(lines), encoding="utf-8")


# ── Sidecar files ─────────────────────────────────────────────────────────────

def write_graphify_root(out_dir: Path, project_root: Path):
    (out_dir / ".graphify_root").write_text(str(project_root.resolve()), encoding="utf-8")


def write_graphify_labels(out_dir: Path, community_labels: dict[int, str]):
    data = {str(cid): label for cid, label in community_labels.items()}
    (out_dir / ".graphify_labels.json").write_text(
        json.dumps(data, indent=2), encoding="utf-8"
    )


# ── CLAUDE.md ─────────────────────────────────────────────────────────────────

_CLAUDE_START = "<!-- dbt-graphify start -->"
_CLAUDE_END = "<!-- dbt-graphify end -->"


def write_claude_md(repo_root: Path, manifest_path: Path):
    """Upsert the graphify lineage instruction block into CLAUDE.md."""
    try:
        rel_manifest = manifest_path.resolve().relative_to(repo_root.resolve())
    except ValueError:
        rel_manifest = manifest_path

    block = "\n".join([
        _CLAUDE_START,
        "## dbt lineage queries",
        "",
        "This project has a graphify knowledge graph at `graphify-out/graph.json` built from the dbt manifest.",
        "",
        "**Always use graphify commands to answer questions about models, dependencies, lineage, or blast radius — do not grep SQL files.**",
        "",
        "```bash",
        "graphify explain \"<model_name>\"      # upstream/downstream connections",
        "graphify path \"<source>\" \"<target>\"  # shortest path between two models",
        "graphify query \"<question>\"          # broader lineage questions",
        "```",
        "",
        "To rebuild the graph:",
        "",
        "```bash",
        f"dbt-graphify {rel_manifest}",
        "```",
        _CLAUDE_END,
    ])

    claude_md = repo_root / "CLAUDE.md"
    if claude_md.exists():
        existing = claude_md.read_text(encoding="utf-8")
        if _CLAUDE_START in existing:
            # Update our block in-place between the sentinels
            start = existing.index(_CLAUDE_START)
            end = existing.index(_CLAUDE_END) + len(_CLAUDE_END)
            claude_md.write_text(existing[:start] + block + existing[end:], encoding="utf-8")
        # CLAUDE.md exists without our sentinels — leave it alone
    else:
        claude_md.write_text(block + "\n", encoding="utf-8")


# ── HTML via graphify cluster-only ────────────────────────────────────────────

def generate_html(out_dir: Path, project_root: Path):
    graphify_bin = shutil.which("graphify")
    if not graphify_bin:
        print(
            "  [dbt-graphify] Note: install graphifyy (`pip install graphifyy`) "
            "to also generate graph.html"
        )
        return

    try:
        result = subprocess.run(
            [graphify_bin, "cluster-only", str(project_root), "--no-label"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode == 0:
            print("  [dbt-graphify] graph.html generated via graphify cluster-only")
        else:
            print(
                f"  [dbt-graphify] Warning: graphify cluster-only exited {result.returncode} "
                f"— graph.html not generated. graph.json is still valid."
            )
            if result.stderr:
                print(f"  {result.stderr.strip()[:200]}")
    except subprocess.TimeoutExpired:
        print("  [dbt-graphify] Warning: graphify cluster-only timed out — skipping graph.html")
    except Exception as exc:
        print(f"  [dbt-graphify] Warning: could not run graphify cluster-only ({exc})")
