# dbt-graphify

Parse a dbt `manifest.json` into a [graphify](https://github.com/graphifyy/graphifyy)-queryable knowledge graph. Ask AI questions about your dbt lineage without reading hundreds of SQL files.

```
dbt manifest.json  ──►  dbt-graphify  ──►  graphify-out/graph.json
                                                    │
                              ┌─────────────────────┤
                              ▼                     ▼
                    graphify query              graph.html
                  "what breaks if I            (interactive
                  change stg_orders?"           D3 viewer)
```

## Why

Graphify can't read dbt projects directly — Jinja2 SQL (`{{ ref('model') }}`) breaks its extractor, and it doesn't understand dbt's layer semantics (staging → intermediate → mart). The result is a noisy, incomplete graph that costs more tokens to query than just grepping the files.

dbt already computes the perfect graph in `manifest.json`. This tool reshapes it into the format graphify expects, with zero LLM calls.

## Installation

```bash
pip install dbt-graphify

# With topology-based community detection (recommended):
pip install "dbt-graphify[clustering]"

# With YAML source description parsing:
pip install "dbt-graphify[yaml]"

# Everything:
pip install "dbt-graphify[all]"
```

No runtime dependencies without extras — stdlib only.

## Usage

```bash
# Auto-detect manifest.json in standard dbt locations
dbt-graphify

# Explicit manifest path
dbt-graphify path/to/target/manifest.json

# Custom output directory
dbt-graphify --out /tmp/my-graph

# Skip graph.html generation
dbt-graphify --no-html

# Module form (no install required)
python -m dbt_graphify
```

### Fallback: no compiled manifest

If `manifest.json` is empty (dbt not compiled), the tool falls back to `graph_summary.json`, which dbt writes even during `dbt parse`:

```bash
cd your-dbt-project/
dbt parse               # fast, no DB connection needed
dbt-graphify            # auto-finds target/graph_summary.json
```

## Output

All files written to `graphify-out/` (or `--out` dir):

| File | Description |
|---|---|
| `graph.json` | NetworkX node-link graph — loaded by `graphify query` |
| `lineage.json` | Full ancestor/descendant maps for blast-radius analysis |
| `GRAPH_REPORT.md` | Human-readable architecture summary with blast-radius table |
| `.graphify_root` | Project root path (read by graphify for incremental updates) |
| `.graphify_labels.json` | Community integer → label name mapping |
| `graph.html` | Interactive D3 visualization (generated via `graphify cluster-only`) |

## Querying with graphify

After running `dbt-graphify`, use [graphify](https://github.com/graphifyy/graphifyy) to query the graph:

```bash
graphify query "which models depend on stg_customers?"
graphify query "trace the full lineage of orders_mart"
graphify query "what breaks if I change stg_payments?"
graphify path "raw_orders" "revenue_report"
graphify explain "int_order_metrics"
```

### Claude Code integration

Install the graphify skill and run `/dbt-graphify` to regenerate the graph, then use `/graphify query` for any lineage question:

```bash
graphify install claude   # installs the graphify skill + hook
```

After that, any `graphify query` or `graphify path` command in Claude Code will use the knowledge graph instead of reading raw SQL files — typically 70–90% fewer tokens per question.

## Node structure

Each node in `graph.json` carries these flat fields (readable by `graphify query`):

| Field | Example |
|---|---|
| `id` | `model.my_project.stg_orders` |
| `label` | `stg_orders` |
| `layer` | `staging` |
| `type` | `model` |
| `materialized` | `view` |
| `description` | `Cleans raw orders. Derives: status_label, days_to_ship.` |
| `source_file` | `models/staging/stg_orders.sql` |
| `community` | `1` |
| `upstream` | `["source.my_project.raw.orders"]` |
| `downstream` | `["model.my_project.int_order_metrics", ...]` |
| `columns` | `["order_id", "customer_id", "status_label", ...]` |

## Community detection

Communities are assigned via this priority chain so the tool works on any dbt project, not just a specific domain:

1. **dbt `group`** — if your models use [dbt groups](https://docs.getdbt.com/docs/build/groups), each group becomes a community
2. **dbt `tags`** — first tag on each model becomes the community
3. **Topology clustering** — Louvain modularity on the DAG (requires `pip install "dbt-graphify[clustering]"`)
4. **Layer fallback** — source / staging / intermediate / mart / seed (always available)

## Blast-radius analysis

`lineage.json` contains full ancestor and descendant maps computed via BFS:

```python
import json

with open("graphify-out/lineage.json") as f:
    lineage = json.load(f)

# Everything downstream of stg_customers
affected = lineage["descendants"]["model.my_project.stg_customers"]
print(f"Changing stg_customers breaks: {affected}")
```

## Requirements

- Python ≥ 3.9
- A dbt project with `dbt compile` or `dbt parse` run (produces `target/manifest.json` or `target/graph_summary.json`)
- [graphify](https://github.com/graphifyy/graphifyy) (`pip install graphifyy`) for `graph.html` and query CLI — optional but recommended

## License

MIT
