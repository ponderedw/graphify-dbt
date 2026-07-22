## Context

dbt projects produce a `manifest.json` at compile time (`dbt compile` or `dbt parse`). This file is a complete, structured description of the entire DAG — every model, source, seed, macro, their dependencies, columns, SQL, materialization, and tests. It is the canonical artifact for dbt lineage tooling.

The graphify skill expects a `graphify-out/graph.json` file. When that file exists, `/graphify query` skips extraction entirely and navigates the graph directly. The current problem: graphify's extractor can't handle Jinja2 SQL syntax, so it produces a broken graph. The solution: generate `graph.json` from `manifest.json` instead of from raw source files.

Current state: no `graphify-out/` directory, `manifest.json` is empty in this project (dbt not compiled), `graph_summary.json` exists as an alternative lineage source.

## Goals / Non-Goals

**Goals:**
- Parse dbt `manifest.json` into a graphify-queryable `graph.json`
- Fall back to `graph_summary.json` + raw SQL parsing if manifest is empty
- Enrich nodes with layer (staging/intermediate/mart), community, columns, descriptions
- Generate `lineage.json` with full ancestor/descendant maps for blast-radius queries
- Generate `GRAPH_REPORT.md` as a human-readable data architecture summary
- Provide a `/dbt-graphify` slash command that runs the pipeline
- Install graphify skill locally so `/graphify query` works without global install

**Non-Goals:**
- Modifying dbt source files or compiling the dbt project
- Replacing the graphify skill — this feeds into it
- Supporting non-standard dbt artifacts (packages, exposures, metrics are parsed but not enriched)
- Database connectivity or query execution

## Decisions

### D1: manifest.json as primary source, graph_summary.json as fallback

**Decision:** Read `manifest.json` first; if it's empty or missing, fall back to `graph_summary.json`.

**Why:** `manifest.json` is the standard, documented dbt artifact — it has columns, descriptions, compiled SQL, and dependency maps. `graph_summary.json` is an internal dbt file without a stable schema. However, `manifest.json` requires a successful `dbt compile`; `graph_summary.json` is written even by `dbt parse`.

**Alternative considered:** Parse raw SQL only. Rejected — regex on Jinja2 SQL is brittle and misses column metadata.

### D2: graph.json MUST use NetworkX node-link format with flat node properties

**Decision:** Structure `graph.json` with `directed: true`, `nodes`, and `edges` as top-level keys. All node properties MUST be **flat** at the top level of each node object — no nesting under a `"properties"` key.

**Why (source-verified):** Graphify loads `graph.json` via `networkx.readwrite.json_graph.node_link_graph()` (confirmed in `graphify/serve.py:44-47`). NetworkX maps each node object's top-level keys directly to node attributes. Graphify then reads them with `G.nodes[nid].get("label")`, `G.nodes[nid].get("community")`, `G.nodes[nid].get("source_file")` etc. A nested `"properties": {...}` sub-object is completely invisible to graphify — it would be stored as a single opaque attribute. Additionally, graphify auto-aliases `"edges"` → `"links"` (`serve.py:31-32`), so using `"edges"` as the key is correct.

**Node fields that graphify specifically uses:**
- `label` — primary BFS/scoring search field
- `norm_label` — pre-normalized label (auto-derived if absent)
- `source_file` — secondary search field for path-based lookups
- `community` — integer, used for community grouping in query output

**Alternative considered:** Nesting properties under `"properties"`. Rejected — confirmed invisible to graphify's query engine.

### D2b: Sidecar files — .graphify_root and .graphify_labels.json

**Decision:** Generate both sidecar files alongside `graph.json`.

**Why:** `.graphify_root` tells graphify where to find the project source when running incremental commands. `.graphify_labels.json` maps community integer IDs to human-readable names — graphify reads this to label communities in query output and `GRAPH_REPORT.md`. Without it, communities show as `"Community 0"`, `"Community 1"` etc.

Format confirmed from a live graphify-out directory:
- `.graphify_root`: plain text, one line, absolute path to project root
- `.graphify_labels.json`: `{"0": "Label", "1": "Label", ...}` — integer keys as strings

### D2c: graph.html via graphify cluster-only delegation

**Decision:** After writing `graph.json`, attempt to call `graphify cluster-only <project_root>`. If graphify is installed, this generates `graph.html` using graphify's own D3 pipeline — we get the interactive visualization for free without reimplementing it. If not installed, print a hint and continue.

**Why:** Reimplementing graphify's D3 visualization is out of scope and maintenance burden. Delegation is the correct architectural choice — we own the graph data, graphify owns the rendering.

### D3: Community detection uses a priority chain — dbt metadata first, topology second, layer fallback last

**Decision:** Communities are assigned by this priority chain:
1. **dbt groups** — if manifest nodes have `group` set, use those as community labels
2. **dbt tags** — if nodes have `tags`, use the first tag as the community label
3. **Topology clustering** — if `networkx` is importable, run Louvain-style modularity clustering on the DAG
4. **Layer-based fallback** — assign community by layer: source=0, staging=1, intermediate=2, mart=3

**Why:** dbt projects vary wildly in domain (e-commerce, healthcare, education, logistics). Hardcoded domain keywords from one project are noise in another. dbt's own metadata (`groups`, `tags`) is the most reliable signal; topology is domain-agnostic; layer-based is always available.

**Alternative considered:** Keyword matching on model names. Rejected as primary strategy — breaks on any project without the expected naming conventions. Retained only as a debug/documentation hint in the report, not for community assignment.

**Note for the hs_analytics demo project:** This project has no `groups` or `tags` and networkx may not be installed, so the layer-based fallback applies. The `GRAPH_REPORT.md` will show a note suggesting users add dbt `groups` for richer communities.

### D4: Single-file Python script, no dependencies beyond stdlib

**Decision:** `dbt_graphify.py` uses only Python stdlib (json, re, sys, pathlib, collections). YAML parsing is attempted with `import yaml` but degrades gracefully if PyYAML is absent.

**Why:** The script must run in any environment where dbt runs, without pip install steps. dbt already requires Python, so stdlib is guaranteed.

**Alternative considered:** Package with pyproject.toml + CLI entry point. Overkill for a single-file utility; can be upgraded later.

## Risks / Trade-offs

- **Empty manifest.json** → Mitigation: fallback to `graph_summary.json`; script prints a clear error if neither source has content.
- **Column extraction from SQL is approximate** — only works for explicit column lists, not `SELECT *` without CTE context. Mitigation: columns are enriched but not required for graph queries.
- **graphify graph.json format may change** — the fast-path is based on file existence, not schema validation. Mitigation: format is stable; our JSON is additive.
- **Community detection is keyword-based** — fails for projects with non-descriptive model names. Mitigation: all nodes fall back to community 0 (Academic); no crash.

## Migration Plan

1. Run `python3 dbt_graphify.py` — generates `graphify-out/` on first run
2. Add `graphify-out/` to `.gitignore` — it's a generated artifact
3. After any `dbt compile`, re-run `python3 dbt_graphify.py` to refresh the graph
4. Use `/dbt-graphify` slash command for the above two steps combined

No rollback needed — the script only writes to `graphify-out/`, never modifies dbt files.

## Open Questions

- Should the slash command auto-detect and run `dbt parse` if manifest.json is missing? (Currently: no — we rely on graph_summary.json fallback)
- Should macros be included in lineage edges? (Currently: included as nodes, no edges since manifest doesn't track macro call sites)
