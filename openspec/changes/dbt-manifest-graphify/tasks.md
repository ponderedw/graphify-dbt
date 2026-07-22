## 1. Python Package Structure

- [x] 1.1 Create `dbt_graphify/` package directory with `__init__.py` and `__main__.py` entry point
- [x] 1.2 Move core logic into `dbt_graphify/parser.py` (manifest parsing, graph_summary fallback, SQL extraction) and `dbt_graphify/builder.py` (graph.json, lineage.json, GRAPH_REPORT.md generation)
- [x] 1.3 Add `dbt_graphify/cli.py` with a `main()` function that handles CLI argument parsing (`--out`, positional manifest path)
- [x] 1.4 Wire `__main__.py` to call `dbt_graphify.cli:main`

## 2. Poetry Setup & PyPI Metadata

- [x] 2.1 Create `pyproject.toml` with Poetry — package name `dbt-graphify`, version `0.1.0`, description, author, license (MIT), homepage, and Python >=3.9 constraint
- [x] 2.2 Add `[tool.poetry.scripts]` entry: `dbt-graphify = "dbt_graphify.cli:main"`
- [x] 2.3 Add optional dependencies: PyYAML under `[tool.poetry.extras]` key `yaml`, networkx under extras key `clustering`
- [x] 2.4 Add PyPI classifiers: `Development Status :: 3 - Alpha`, `Topic :: Software Development :: Libraries`, `Intended Audience :: Developers`
- [x] 2.5 Run `poetry check` and verify it exits 0

## 3. Manifest Parser (dbt_graphify/parser.py)

- [x] 3.1 Implement `parse_manifest(manifest: dict, project_root: Path) -> dict` — extracts nodes, sources, macros, and uses `parent_map`/`child_map` for upstream/downstream edges
- [x] 3.2 Implement `parse_graph_summary(summary: dict, project_root: Path) -> dict` — fallback parser for `graph_summary.json` that reads raw SQL for ref/source extraction
- [x] 3.3 Implement `infer_layer(resource_type, name, fqn)` — classifies nodes into source/staging/intermediate/mart/seed/macro using name prefix (`stg_`, `int_`) and fqn
- [x] 3.4 Implement `extract_refs_from_sql(sql)` and `extract_sources_from_sql(sql)` — regex-based Jinja2 call extraction
- [x] 3.5 Implement `_extract_columns_sql(sql)` — best-effort column name extraction from final SELECT clause, handling nested parens and `AS` aliases
- [x] 3.6 Add `find_manifest(start: Path)` and `find_graph_summary(start: Path)` search helpers that check standard dbt target/ locations

## 4. Graph Builder (dbt_graphify/builder.py)

- [x] 4.1 Implement `assign_community(node_data, layer) -> int` — priority chain: (1) dbt `group` field, (2) first `tag`, (3) Louvain topology clustering if networkx available, (4) layer-based fallback (source=0, staging=1, intermediate=2, mart=3, seed=4)
- [x] 4.2 Implement `bfs_reachable(start, adjacency) -> list[str]` — BFS traversal for full ancestor/descendant maps
- [x] 4.3 Implement `build_graph_json(parsed, project_name) -> dict` — assembles `directed: true`, `nodes`, and `edges` in NetworkX node-link format; all node properties MUST be flat at the top level (no nested `"properties"` key); required flat fields: `id`, `label`, `community`, `type`, `layer`, `source_file`, `description`, `materialized`, `upstream`, `downstream`
- [x] 4.4 Implement `build_lineage_json(nodes, upstream_adj, downstream_adj) -> dict` — runs BFS for every node to populate `ancestors` and `descendants` maps
- [x] 4.5 Implement `write_report(parsed, out_dir, project_name)` — generates `GRAPH_REPORT.md` with architecture diagram, per-layer node inventory (label, materialization, description, reads-from, feeds-into, columns), blast-radius table, and community legend
- [x] 4.6 Add `_auto_desc(name, layer) -> str` — lookup table of hand-written descriptions for known model names, falling back to a generic template
- [x] 4.7 Implement `write_graphify_root(out_dir, project_root)` — writes `.graphify_root` as a plain-text file containing the absolute path to the dbt project root
- [x] 4.8 Implement `write_graphify_labels(out_dir, communities)` — writes `.graphify_labels.json` as `{"0": "label", "1": "label", ...}` mapping each community integer to its human-readable name (from dbt group, tag, or layer name)
- [x] 4.9 Implement `generate_html(out_dir, project_root)` — after writing `graph.json`, attempt `graphify cluster-only <project_root>` via subprocess; if graphify is not on PATH or exits non-zero, print a graceful warning and continue without error

## 5. Slash Command & Graphify Skill

- [x] 5.1 Create `.claude/commands/dbt-graphify.md` — slash command that runs `python3 -m dbt_graphify` (or `dbt-graphify` if installed), shows node/edge counts and layer breakdown, and surfaces any errors with actionable next steps
- [x] 5.2 Copy graphify skill from `~/.claude/skills/graphify/` into `.claude/skills/graphify/` so `/graphify` queries work project-locally without global install

## 6. Project Hygiene

- [x] 6.1 Add `graphify-out/` and `dist/` to `.gitignore`
- [x] 6.2 Update proposal to note the `python-package` capability (PyPI distribution via Poetry)
- [x] 6.3 Run `python3 -m dbt_graphify` against this project (using `graph_summary.json` fallback) and verify all output files are written: `graph.json`, `GRAPH_REPORT.md`, `lineage.json`, `.graphify_root`, `.graphify_labels.json`
- [x] 6.4 Verify `graph.json` nodes are flat (no nested `"properties"` key) and loadable with `networkx.readwrite.json_graph.node_link_graph()`
- [x] 6.5 Verify `graphify cluster-only .` successfully generates `graph.html` from our `graph.json`
- [x] 6.6 Verify `/graphify query "what models use stg_students?"` returns a correct answer from the generated graph
