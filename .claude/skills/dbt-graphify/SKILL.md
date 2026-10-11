# /dbt-graphify

Rebuild the dbt knowledge graph and answer lineage questions using graphify.

## Usage

```
/dbt-graphify                    # check watch status, rebuild if stale
/dbt-graphify "<question>"       # answer a lineage question
/dbt-graphify rebuild            # force a graph rebuild now
```

## What to do when invoked

### Step 1 — find the graph

Check for `graphify-out/graph.json` in the current directory or any parent up to `$HOME`.
Also check `~/.cache/dbt-graphify-watch.log` to confirm the watch process is active.

### Step 2 — answer or rebuild

If the user asked a lineage question, run graphify commands directly against the graph:

```bash
graphify query "<question>"
graphify explain "<model_name>"
graphify path "<source>" "<target>"
```

If the graph is missing or the user asked for a rebuild:

```bash
dbt-graphify            # auto-detects manifest.json
```

### Step 3 — check / start the watch process

If no watch process is running, start one so future `dbt` commands trigger automatic rebuilds:

```bash
PYTHONUNBUFFERED=1 nohup dbt-graphify <manifest_path> --out <out_dir> --watch \
  > ~/.cache/dbt-graphify-watch.log 2>&1 &
echo $! > ~/.cache/dbt-graphify-watch.pid
echo "Watch started"
```

## Ongoing behavior — after any dbt command

After the user runs any of these commands:

```bash
dbt ls        # always regenerates manifest.json
dbt parse     # validate and compile
dbt compile   # compile SQL
dbt run       # execute models
```

The watch process detects the updated `manifest.json` and rebuilds the graph within a few
seconds. **Always re-query the graph after these commands** — do not answer lineage
questions from stale data. Wait ~5 seconds then run your query.

## Never grep SQL for lineage

Always use graphify commands for dbt dependency and lineage questions.
Do not grep `.sql` files — the graph has complete pre-computed lineage that is
70–90% fewer tokens per question.
