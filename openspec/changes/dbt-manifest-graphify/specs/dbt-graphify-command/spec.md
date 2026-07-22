## ADDED Requirements

### Requirement: /dbt-graphify slash command runs the pipeline
The command SHALL invoke `python3 dbt_graphify.py` from the project root, capture its output, and present a summary to the user including node count, edge count, and layer breakdown.

#### Scenario: Successful pipeline run
- **WHEN** the user invokes `/dbt-graphify`
- **THEN** the command runs the script, shows how many nodes and edges were generated, and confirms the three output files were written

#### Scenario: Missing source files
- **WHEN** neither `manifest.json` nor `graph_summary.json` has content
- **THEN** the command surfaces the script's error message and suggests running `dbt compile` or `dbt parse`

### Requirement: Graphify skill is available locally for /graphify queries
The graphify skill SHALL be present in `.claude/skills/graphify/` so that `/graphify query "<question>"` works on the generated `graphify-out/graph.json` without requiring a global skill installation.

#### Scenario: /graphify query after /dbt-graphify
- **WHEN** the user runs `/dbt-graphify` then `/graphify query "what models depend on stg_students?"`
- **THEN** the graphify skill finds `graphify-out/graph.json`, uses the fast-path, and answers from the graph without re-extracting files

### Requirement: graphify-out/ is excluded from git tracking
A `.gitignore` entry SHALL exclude the `graphify-out/` directory since it is a generated artifact, not source.

#### Scenario: gitignore entry present
- **WHEN** `python3 dbt_graphify.py` is run and `graphify-out/` is created
- **THEN** `git status` does not show `graphify-out/` as an untracked directory
