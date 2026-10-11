"""dbt-graphify install claude — write skill + register in CLAUDE.md."""

import shutil
import subprocess
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

Always use graphify commands for dbt dependency and lineage questions.
Do not grep `.sql` files — the graph has complete pre-computed lineage that is
70–90% fewer tokens per question.
"""

_CLAUDE_START = "<!-- dbt-graphify-skill start -->"
_CLAUDE_END = "<!-- dbt-graphify-skill end -->"


def _claude_block(skill_path: Path) -> str:
    return (
        f"{_CLAUDE_START}\n"
        "# dbt-graphify\n"
        f"- **dbt-graphify** (`{skill_path}`) - dbt lineage queries. Trigger: `/dbt-graphify`\n"
        "When the user types `/dbt-graphify`, use the dbt-graphify skill before doing anything else.\n"
        "- Use `/dbt-graphify` for **dbt lineage questions** (models, dependencies, blast radius, lineage).\n"
        "- Use `/graphify` for **all other codebase questions** (code architecture, file relationships, non-dbt content).\n"
        f"{_CLAUDE_END}"
    )


def _upsert_claude_md(claude_md: Path, skill_path: Path) -> str:
    block = _claude_block(skill_path)
    if claude_md.exists():
        existing = claude_md.read_text(encoding="utf-8")
        has_start = _CLAUDE_START in existing
        has_end = _CLAUDE_END in existing
        if has_start and has_end:
            start = existing.index(_CLAUDE_START)
            end = existing.index(_CLAUDE_END) + len(_CLAUDE_END)
            claude_md.write_text(
                existing[:start] + block + existing[end:], encoding="utf-8"
            )
            return "updated"
        elif has_end:
            # Orphaned end sentinel (start stripped by editor/linter) — remove
            # everything from the last occurrence of "# dbt-graphify" before
            # the end sentinel, then append a clean block.
            end_pos = existing.index(_CLAUDE_END) + len(_CLAUDE_END)
            before_end = existing[:end_pos]
            marker = "\n# dbt-graphify\n"
            if marker in before_end:
                cut = before_end.rindex(marker)
                cleaned = existing[:cut] + existing[end_pos:]
            else:
                cleaned = existing[:before_end.rfind(_CLAUDE_END) - 1]
                cleaned = cleaned + existing[end_pos:]
            claude_md.write_text(
                cleaned.rstrip() + "\n\n" + block + "\n", encoding="utf-8"
            )
            return "registered (replaced orphan)"
        else:
            claude_md.write_text(
                existing.rstrip() + "\n\n" + block + "\n", encoding="utf-8"
            )
            return "registered"
    else:
        claude_md.parent.mkdir(parents=True, exist_ok=True)
        claude_md.write_text(block + "\n", encoding="utf-8")
        return "created"


def install_claude(project: bool = False) -> None:
    cwd = Path.cwd()
    skill_base = cwd / ".claude" if project else Path.home() / ".claude"

    # 1. Run graphify install claude first so its output lands before ours
    graphify_bin = shutil.which("graphify")
    if graphify_bin:
        cmd = [graphify_bin, "install", "claude"]
        if project:
            cmd.append("--project")
        subprocess.run(cmd, text=True)
        print()
    else:
        print(
            "  Note: install graphifyy (`pip install graphifyy`) "
            "to also install the graphify skill."
        )
        print()

    # 2. Install dbt-graphify skill
    skill_dir = skill_base / "skills" / "dbt-graphify"
    skill_dir.mkdir(parents=True, exist_ok=True)
    skill_path = skill_dir / "SKILL.md"
    skill_path.write_text(_SKILL_CONTENT, encoding="utf-8")
    display_path = skill_path.relative_to(cwd) if project else skill_path
    print(f"  skill installed  ->  {display_path}")

    claude_md = skill_base / "CLAUDE.md"
    status = _upsert_claude_md(claude_md, display_path)
    print(f"  CLAUDE.md        ->  {status} at {claude_md}")

    if project:
        print()
        print("Project-scoped install. Add to version control:")
        print("  git add .claude/")

    # 3. Build the graph for the current project
    print()
    from dbt_graphify.cli import _resolve_manifest, _run_build
    manifest_path, _ = _resolve_manifest(None, cwd)
    if manifest_path is None:
        print(
            "  graph            ->  skipped (no manifest.json found — "
            "run `dbt compile` first, then re-run `dbt-graphify install claude`)"
        )
    else:
        _run_build(manifest_path, Path("graphify-out"), skip_html=True)

    print()
    print("Done. Open your AI coding assistant and type:")
    print()
    print("  /dbt-graphify")
