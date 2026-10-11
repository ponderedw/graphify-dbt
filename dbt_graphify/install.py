"""dbt-graphify install claude — write skill + register in ~/.claude/CLAUDE.md."""

import shutil
import subprocess
import sys
from pathlib import Path

_SKILL_CONTENT = """\
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
# or explicitly:
dbt-graphify path/to/target/manifest.json --out path/to/graphify-out
```

### Step 3 — check / start the watch process

If no watch process is running, start one so future `dbt` commands trigger automatic rebuilds:

```bash
PYTHONUNBUFFERED=1 nohup dbt-graphify <manifest_path> --out <out_dir> --watch \\
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

Always use graphify commands for dependency and lineage questions.
Do not grep `.sql` files — the graph has complete pre-computed lineage that is
70–90% fewer tokens per question.
"""

_CLAUDE_START = "<!-- dbt-graphify-skill start -->"
_CLAUDE_END = "<!-- dbt-graphify-skill end -->"

_CLAUDE_BLOCK = """\
<!-- dbt-graphify-skill start -->
# dbt-graphify
- **dbt-graphify** (`~/.claude/skills/dbt-graphify/SKILL.md`) - dbt lineage graph queries and watch process. Trigger: `/dbt-graphify`
When the user types `/dbt-graphify`, use the installed dbt-graphify skill before doing anything else.
<!-- dbt-graphify-skill end -->"""


def install_claude() -> None:
    # Run graphify install claude first so its output lands before ours
    graphify_bin = shutil.which("graphify")
    if graphify_bin:
        subprocess.run([graphify_bin, "install", "claude"], text=True)
        print()
    else:
        print("  Note: install graphifyy (`pip install graphifyy`) to also install the graphify skill.")
        print()

    skill_dir = Path.home() / ".claude" / "skills" / "dbt-graphify"
    skill_dir.mkdir(parents=True, exist_ok=True)
    skill_path = skill_dir / "SKILL.md"
    skill_path.write_text(_SKILL_CONTENT, encoding="utf-8")
    print(f"  skill installed  ->  {skill_path}")

    claude_md = Path.home() / ".claude" / "CLAUDE.md"
    if claude_md.exists():
        existing = claude_md.read_text(encoding="utf-8")
        if _CLAUDE_START in existing:
            start = existing.index(_CLAUDE_START)
            end = existing.index(_CLAUDE_END) + len(_CLAUDE_END)
            claude_md.write_text(existing[:start] + _CLAUDE_BLOCK + existing[end:], encoding="utf-8")
            print(f"  CLAUDE.md        ->  updated")
        else:
            claude_md.write_text(existing.rstrip() + "\n\n" + _CLAUDE_BLOCK + "\n", encoding="utf-8")
            print(f"  CLAUDE.md        ->  registered")
    else:
        claude_md.write_text(_CLAUDE_BLOCK + "\n", encoding="utf-8")
        print(f"  CLAUDE.md        ->  created")

    print()
    print("Done. Open your AI coding assistant and type:")
    print()
    print("  /dbt-graphify")
