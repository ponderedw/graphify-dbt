"""Parse dbt manifest.json or graph_summary.json into a unified graph dict."""

import json
import re
from collections import defaultdict
from pathlib import Path


# ── Layer inference ───────────────────────────────────────────────────────────

def infer_layer(resource_type: str, name: str, fqn: list[str]) -> str:
    if resource_type == "source":
        return "source"
    if resource_type == "seed":
        return "seed"
    if resource_type in ("test", "analysis"):
        return resource_type
    if resource_type == "macro":
        return "macro"
    # model — name prefix first
    if name.startswith("stg_"):
        return "staging"
    if name.startswith("int_"):
        return "intermediate"
    # fqn segments
    mart_segments = {"marts", "mart", "core", "academic", "finance", "financial", "reporting"}
    staging_segments = {"staging", "stg"}
    intermediate_segments = {"intermediate", "int"}
    for seg in fqn:
        seg_lower = seg.lower()
        if seg_lower in staging_segments:
            return "staging"
        if seg_lower in intermediate_segments:
            return "intermediate"
        if seg_lower in mart_segments:
            return "mart"
    return "mart"


# ── SQL extraction ────────────────────────────────────────────────────────────

def extract_refs_from_sql(sql: str) -> list[str]:
    return re.findall(r"\{\{\s*ref\s*\(\s*['\"](\w+)['\"]\s*\)\s*\}\}", sql)


def extract_sources_from_sql(sql: str) -> list[tuple[str, str]]:
    return re.findall(
        r"\{\{\s*source\s*\(\s*['\"](\w+)['\"]\s*,\s*['\"](\w+)['\"]\s*\)\s*\}\}", sql
    )


def _extract_columns_sql(sql: str) -> list[str]:
    """Best-effort: extract column alias names from the final SELECT clause."""
    clean = re.sub(r"\{\{.*?\}\}", "__jinja__", sql, flags=re.DOTALL)
    clean = re.sub(r"\{%-?.*?-?%\}", "", clean, flags=re.DOTALL)

    selects = list(re.finditer(r"\bselect\b(.*?)\bfrom\b", clean, re.IGNORECASE | re.DOTALL))
    if not selects:
        return []

    clause = selects[-1].group(1).strip()
    if clause.strip() == "*" and len(selects) > 1:
        clause = selects[-2].group(1).strip()

    depth, current, parts = 0, [], []
    for ch in clause:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append("".join(current).strip())
            current = []
            continue
        current.append(ch)
    if current:
        parts.append("".join(current).strip())

    result = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        alias = re.search(r"\bas\s+(\w+)\s*$", part, re.IGNORECASE)
        if alias:
            result.append(alias.group(1))
        else:
            word = re.search(r"(\w+)\s*$", part)
            if word:
                result.append(word.group(1))
    return result


# ── File discovery ────────────────────────────────────────────────────────────

def find_manifest(start: Path) -> Path | None:
    candidates = [
        start / "target" / "manifest.json",
        start / "dbt_project" / "target" / "manifest.json",
        start / "manifest.json",
    ]
    for c in candidates:
        if c.exists() and c.stat().st_size > 10:
            return c
    return None


def find_graph_summary(start: Path) -> Path | None:
    candidates = [
        start / "target" / "graph_summary.json",
        start / "dbt_project" / "target" / "graph_summary.json",
        start / "graph_summary.json",
    ]
    for c in candidates:
        if c.exists() and c.stat().st_size > 10:
            return c
    return None


def _find_sql_file(name: str, project_root: Path) -> Path | None:
    for p in project_root.rglob(f"{name}.sql"):
        # Skip compiled/run output directories
        if "compiled" not in p.parts and "run" not in p.parts:
            return p
    return None


# ── Manifest parser ───────────────────────────────────────────────────────────

def parse_manifest(manifest: dict, project_root: Path) -> dict:
    """Parse dbt manifest.json into a unified graph dict."""
    nodes_raw = manifest.get("nodes", {})
    sources_raw = manifest.get("sources", {})
    macros_raw = manifest.get("macros", {})
    parent_map = manifest.get("parent_map", {})
    child_map = manifest.get("child_map", {})

    # Build upstream/downstream from parent_map
    upstream: dict[str, set] = defaultdict(set)
    downstream: dict[str, set] = defaultdict(set)
    for node_id, parents in parent_map.items():
        for parent_id in parents:
            upstream[node_id].add(parent_id)
            downstream[parent_id].add(node_id)

    nodes = []

    def _process_model(uid: str, raw: dict, resource_type: str):
        name = raw.get("name", uid.split(".")[-1])
        fqn = raw.get("fqn", [])
        layer = infer_layer(resource_type, name, fqn)
        config = raw.get("config", {})
        description = raw.get("description", "").strip()
        columns = list(raw.get("columns", {}).keys())
        file_path = raw.get("original_file_path", raw.get("path", ""))
        raw_code = raw.get("raw_code", raw.get("raw_sql", ""))
        tags = raw.get("tags", [])
        group = raw.get("group", None)
        database = raw.get("database", "") or config.get("database", "")
        schema = raw.get("schema", "") or config.get("schema", "")

        refs_in_code = extract_refs_from_sql(raw_code) if raw_code else []
        sources_in_code = extract_sources_from_sql(raw_code) if raw_code else []

        # Enrich from SQL file if code or columns missing
        if (not raw_code or not columns) and project_root and file_path:
            sql_path = project_root / file_path
            if not sql_path.exists():
                found = _find_sql_file(name, project_root)
                if found:
                    sql_path = found
            if sql_path.exists():
                raw_code = sql_path.read_text(encoding="utf-8")
                refs_in_code = extract_refs_from_sql(raw_code)
                sources_in_code = extract_sources_from_sql(raw_code)
                if not columns:
                    columns = _extract_columns_sql(raw_code)
                if not file_path:
                    try:
                        file_path = str(sql_path.relative_to(project_root.parent))
                    except ValueError:
                        file_path = str(sql_path)

        up_ids = sorted(upstream.get(uid, set()))
        down_ids = sorted(downstream.get(uid, set()))

        nodes.append({
            "uid": uid,
            "name": name,
            "resource_type": resource_type,
            "layer": layer,
            "description": description,
            "file_path": file_path,
            "config": config,
            "columns": columns[:40],
            "refs": refs_in_code,
            "sources": [f"{s[0]}.{s[1]}" for s in sources_in_code],
            "tags": tags,
            "group": group,
            "database": database,
            "schema": schema,
            "upstream": up_ids,
            "downstream": down_ids,
        })

    for uid, raw in nodes_raw.items():
        rt = raw.get("resource_type", "model")
        if rt in ("test", "analysis"):
            continue
        _process_model(uid, raw, rt)

    for uid, raw in sources_raw.items():
        name = raw.get("name", "")
        source_name = raw.get("source_name", "")
        description = raw.get("description", "").strip()
        columns = list(raw.get("columns", {}).keys())
        down_ids = sorted(downstream.get(uid, set()))

        nodes.append({
            "uid": uid,
            "name": name,
            "resource_type": "source",
            "layer": "source",
            "description": description or f"Source table: {source_name}.{name}",
            "file_path": raw.get("original_file_path", ""),
            "config": {"materialized": "external"},
            "columns": columns[:40],
            "refs": [],
            "sources": [],
            "tags": raw.get("tags", []),
            "group": raw.get("group", None),
            "database": raw.get("database", ""),
            "schema": source_name,
            "upstream": [],
            "downstream": down_ids,
        })

    for uid, raw in macros_raw.items():
        name = raw.get("name", uid.split(".")[-1])
        nodes.append({
            "uid": uid,
            "name": name,
            "resource_type": "macro",
            "layer": "macro",
            "description": raw.get("description", "").strip() or f"Jinja2 macro: {name}",
            "file_path": raw.get("original_file_path", ""),
            "config": {"materialized": "macro"},
            "columns": [],
            "refs": [],
            "sources": [],
            "tags": [],
            "group": None,
            "upstream": [],
            "downstream": [],
        })

    meta = manifest.get("metadata", {})
    return {
        "meta": meta,
        "project_name": meta.get("project_name", "dbt_project"),
        "nodes": nodes,
        "upstream": {k: list(v) for k, v in upstream.items()},
        "downstream": {k: list(v) for k, v in downstream.items()},
    }


# ── graph_summary.json fallback ───────────────────────────────────────────────

def parse_graph_summary(summary: dict, project_root: Path) -> dict:
    """Fallback: parse dbt graph_summary.json + raw SQL files."""
    linked = summary.get("linked", {})

    id_to_name: dict[int, str] = {}
    id_to_type: dict[int, str] = {}
    for nid, nd in linked.items():
        id_to_name[int(nid)] = nd["name"]
        id_to_type[int(nid)] = nd["type"]

    upstream: dict[str, set] = defaultdict(set)
    downstream: dict[str, set] = defaultdict(set)

    for nid_str, nd in linked.items():
        nid = int(nid_str)
        if nd["type"] == "test":
            continue
        src_name = nd["name"]
        for succ_id in nd.get("succ", []):
            tgt_name = id_to_name[succ_id]
            if id_to_type[succ_id] == "test":
                continue
            upstream[tgt_name].add(src_name)
            downstream[src_name].add(tgt_name)

    nodes = []
    for nid_str, nd in linked.items():
        node_type = nd["type"]
        if node_type == "test":
            continue

        full_name = nd["name"]
        short_name = full_name.split(".")[-1]
        fqn = full_name.split(".")
        layer = infer_layer(node_type, short_name, fqn)

        columns, refs_in_code, sources_in_code, file_path = [], [], [], ""

        if node_type == "model" and project_root:
            sql_file = _find_sql_file(short_name, project_root)
            if sql_file:
                try:
                    file_path = str(sql_file.relative_to(project_root.parent))
                except ValueError:
                    file_path = str(sql_file)
                sql = sql_file.read_text(encoding="utf-8")
                refs_in_code = extract_refs_from_sql(sql)
                sources_in_code = extract_sources_from_sql(sql)
                columns = _extract_columns_sql(sql)

        up_ids = sorted(upstream.get(full_name, set()))
        down_ids = sorted(downstream.get(full_name, set()))

        nodes.append({
            "uid": full_name,
            "name": short_name,
            "resource_type": node_type,
            "layer": layer,
            "description": "",
            "file_path": file_path,
            "config": {},
            "columns": columns[:40],
            "refs": refs_in_code,
            "sources": [f"{s[0]}.{s[1]}" for s in sources_in_code],
            "tags": [],
            "group": None,
            "upstream": up_ids,
            "downstream": down_ids,
        })

    return {
        "meta": {"source": "graph_summary.json"},
        "project_name": "dbt_project",
        "nodes": nodes,
        "upstream": {k: list(v) for k, v in upstream.items()},
        "downstream": {k: list(v) for k, v in downstream.items()},
    }
