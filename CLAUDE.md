<!-- dbt-graphify start -->
## dbt lineage queries

This project has a graphify knowledge graph at `graphify-out/graph.json` built from the dbt manifest.

**Always use graphify commands to answer questions about models, dependencies, lineage, or blast radius — do not grep SQL files.**

```bash
graphify explain "<model_name>"      # upstream/downstream connections
graphify path "<source>" "<target>"  # shortest path between two models
graphify query "<question>"          # broader lineage questions
```

To rebuild the graph:

```bash
dbt-graphify dbt_project/target/manifest.json
```

**The graph auto-rebuilds when `manifest.json` changes.** The following dbt commands all regenerate `manifest.json` and therefore trigger an automatic graph rebuild:

```bash
dbt ls        # list models — always regenerates manifest
dbt parse     # validate and compile — regenerates manifest
dbt compile   # compile SQL — regenerates manifest
dbt run       # execute models — regenerates manifest
```

**After running any of the above dbt commands, re-query the graph** — the rebuild happens automatically in the background within a few seconds.
<!-- dbt-graphify end -->

# dbt-graphify

Python package that parses a dbt `manifest.json` into a graphify-queryable knowledge graph. The `dbt_project/` directory contains a demo university analytics dbt project used for development and testing.

## Project layout

```
dbt_graphify/       ← Python package source
  parser.py         ← reads manifest.json / graph_summary.json
  builder.py        ← builds graph.json, lineage.json, GRAPH_REPORT.md
  cli.py            ← entry point
dbt_project/        ← demo dbt project (university analytics, 22 models)
graphify-out/       ← generated output (gitignored)
```
