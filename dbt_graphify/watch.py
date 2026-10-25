"""Watch a dbt manifest.json for changes and auto-rebuild the knowledge graph."""
from __future__ import annotations

import time
from pathlib import Path

_POLL_INTERVAL = 2.0  # seconds


def watch(manifest_path: Path, out_dir: Path, skip_html: bool = False) -> None:
    """Poll manifest_path and rebuild whenever dbt regenerates it.

    Run this in the foreground while dbt compile / dbt run / dbt parse
    is running in another terminal. Press Ctrl-C to stop.
    """
    print(f"Watching {manifest_path}")
    print(
        "  Rebuild triggers when dbt regenerates it "
        "(dbt compile / dbt run / dbt parse)"
    )
    print("  Press Ctrl-C to stop.\n")

    last_mtime: float | None = (
        manifest_path.stat().st_mtime if manifest_path.exists() else None
    )
    if last_mtime is None:
        print(
            f"  [waiting] {manifest_path} does not exist yet"
            " — will rebuild once it appears"
        )

    while True:
        try:
            time.sleep(_POLL_INTERVAL)
        except KeyboardInterrupt:
            print("\nStopped.")
            return

        current_mtime = (
            manifest_path.stat().st_mtime if manifest_path.exists() else None
        )

        if current_mtime is None:
            continue

        if last_mtime is None or current_mtime != last_mtime:
            last_mtime = current_mtime
            _rebuild(manifest_path, out_dir, skip_html)


def _rebuild(manifest_path: Path, out_dir: Path, skip_html: bool) -> None:
    from dbt_graphify.cli import _run_build
    from dbt_graphify.snapshot import run_snapshot

    print("[dbt-graphify] manifest changed — rebuilding...")
    try:
        _run_build(manifest_path, out_dir, skip_html)
        print("[dbt-graphify] graph updated.")
    except Exception as exc:
        print(f"[dbt-graphify] rebuild failed: {exc}\n")
        return

    try:
        run_snapshot(out_dir)
        print("[dbt-graphify] snapshot created.\n")
    except Exception as exc:
        print(f"[dbt-graphify] snapshot failed: {exc}\n")
