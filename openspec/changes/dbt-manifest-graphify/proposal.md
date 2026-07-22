## Why

The graphify skill works poorly with dbt projects because dbt models are Jinja2-templated SQL files — graphify can't understand `{{ ref('model') }}` calls, implicit lineage, or layer semantics (staging/intermediate/mart). The result is a noisy, context-poor graph that costs more tokens to query than just reading the files directly. The fix: parse the dbt `manifest.json` (the compiled artifact dbt generates) and produce a clean, graphify-native `graph.json` that an AI can navigate in O(1) without touching any SQL.

## What Changes

- New Python script `dbt_graphify.py` at project root — reads `manifest.json` (primary) or `graph_summary.json` (fallback), enriches nodes with SQL metadata, and writes `graphify-out/graph.json`, `graphify-out/lineage.json`, `graphify-out/GRAPH_REPORT.md`
- New slash command `.claude/commands/dbt-graphify.md` — runs the script and summarizes the graph
- Graphify skill symlinked/copied into `.claude/skills/graphify/` so `/graphify` queries work on the generated graph
- `graphify-out/` added to `.gitignore` (generated artifact, not source)

## Capabilities

### New Capabilities

- `dbt-manifest-parser`: Parse dbt `manifest.json` (or `graph_summary.json` fallback) to extract the full DAG — nodes (sources, models, seeds, macros), edges (LINEAGE relationships), parent/child maps, materialization, columns, and descriptions
- `graphify-graph-builder`: Transform the parsed dbt DAG into `graphify-out/graph.json` with community detection (Academic, Financial, Faculty, Risk, Sources), god nodes per layer, blast-radius lineage maps, and a human-readable `GRAPH_REPORT.md`
- `dbt-graphify-command`: Slash command `/dbt-graphify` that orchestrates the pipeline end-to-end and surfaces a summary of the generated graph

### Modified Capabilities

## Impact

- New root-level file: `dbt_graphify.py`
- New directory: `graphify-out/` (generated, gitignored)
- New command file: `.claude/commands/dbt-graphify.md`
- Graphify skill available in `.claude/skills/graphify/`
- No changes to dbt project files or existing models
