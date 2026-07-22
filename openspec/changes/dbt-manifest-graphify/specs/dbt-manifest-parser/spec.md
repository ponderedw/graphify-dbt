## ADDED Requirements

### Requirement: Parse manifest.json as primary DAG source
The script SHALL read a dbt `manifest.json` file and extract nodes (`nodes`, `sources`, `macros`), dependency maps (`parent_map`, `child_map`), and metadata. When `manifest.json` is non-empty (>10 bytes), it MUST be preferred over any fallback source.

#### Scenario: Valid manifest.json provided
- **WHEN** a non-empty `manifest.json` is found at the default path or passed as an argument
- **THEN** the parser extracts all node entries, source entries, macro entries, and uses `parent_map`/`child_map` for upstream/downstream edges

#### Scenario: Explicit manifest path via CLI argument
- **WHEN** the user runs `python3 dbt_graphify.py path/to/manifest.json`
- **THEN** the script reads from that path instead of searching default locations

### Requirement: Fall back to graph_summary.json when manifest is empty
The script SHALL detect when `manifest.json` is empty or absent and automatically fall back to `dbt_project/target/graph_summary.json`.

#### Scenario: Empty manifest.json with graph_summary.json present
- **WHEN** `manifest.json` has 0 bytes and `graph_summary.json` exists with content
- **THEN** the script prints a warning, reads `graph_summary.json`, and continues without error

#### Scenario: Neither source available
- **WHEN** both `manifest.json` and `graph_summary.json` are absent or empty
- **THEN** the script exits with a non-zero code and a message: "Run `dbt compile` or `dbt parse` first"

### Requirement: Infer model layer from node name and fqn
The parser SHALL classify each model node into a layer — `source`, `staging`, `intermediate`, `mart`, `seed`, or `macro` — using the node name prefix (`stg_`, `int_`) and the `fqn` array.

#### Scenario: Staging model detection
- **WHEN** a model node has `name` starting with `stg_`
- **THEN** its layer is `staging`

#### Scenario: Intermediate model detection
- **WHEN** a model node has `name` starting with `int_`
- **THEN** its layer is `intermediate`

#### Scenario: Mart model detection
- **WHEN** a model node has no recognized prefix and its `fqn` contains `marts`, `core`, `academic`, or `finance`
- **THEN** its layer is `mart`

### Requirement: Extract refs and sources from raw SQL when columns are absent
When `manifest.json` provides a model with empty columns, the parser SHALL read the raw SQL file (located via `original_file_path`) and extract `{{ ref('model') }}` and `{{ source('schema', 'table') }}` calls.

#### Scenario: Column list enrichment from SQL
- **WHEN** a model node has no columns in the manifest and a SQL file is found at its path
- **THEN** `refs` and `sources` properties are populated from regex extraction on the raw SQL

#### Scenario: SQL file not found
- **WHEN** the SQL file path does not resolve to an existing file
- **THEN** `refs` and `sources` remain empty lists; no error is thrown
