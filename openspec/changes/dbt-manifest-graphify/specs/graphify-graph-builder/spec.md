## ADDED Requirements

### Requirement: Write graphify-out/graph.json in NetworkX node-link format
The builder SHALL write a `graph.json` file compatible with `networkx.readwrite.json_graph.node_link_graph()`. The top-level keys MUST be `directed` (true), `nodes`, and `edges`. Graphify automatically aliases `edges` → `links` internally, so `edges` is correct.

**Critical**: All node properties MUST be **flat** at the top level of each node object. Graphify reads them via `G.nodes[nid].get("label")`, `G.nodes[nid].get("community")` etc. A nested `"properties": {...}` sub-object is invisible to graphify and MUST NOT be used.

Required node fields (all flat):
- `id` — unique identifier (e.g. `"model.project.stg_students"`)
- `label` — human-readable name (e.g. `"stg_students"`) — primary search field in graphify query
- `community` — integer community ID
- `type` — resource type (`"model"`, `"source"`, `"seed"`, `"macro"`)
- `layer` — dbt layer (`"staging"`, `"intermediate"`, `"mart"`, `"source"`, `"seed"`)
- `source_file` — relative path to the SQL/YML file — secondary search field
- `description` — plain-language summary
- `materialized` — `"view"`, `"table"`, `"external"`, `"seed"`
- `upstream` — list of upstream node IDs
- `downstream` — list of downstream node IDs

Additional flat fields (e.g. `columns`, `refs`, `tags`) are preserved by graphify and returned in query output.

#### Scenario: Node shape for a staging model
- **WHEN** a staging model is processed
- **THEN** its node entry is a flat object with `layer: "staging"`, `materialized: "view"`, `label: "stg_<name>"`, a non-empty `description`, and `upstream`/`downstream` as flat lists of node ID strings — no nested `"properties"` key

#### Scenario: Graphify query finds model by label
- **WHEN** `graphify query "stg_students"` is run against the generated graph
- **THEN** graphify locates the node via its `label` field and returns its neighbors

#### Scenario: Edge direction is upstream → downstream
- **WHEN** model B depends on model A (A is in B's `parent_map`)
- **THEN** the edge is written as `{ "source": A.id, "target": B.id, "type": "LINEAGE", "key": 0 }`

### Requirement: Assign community via dbt metadata, topology, or layer fallback
Each node SHALL be assigned a community integer using a priority chain so the tool works correctly with any dbt project domain, not just education or finance.

#### Scenario: Community from dbt groups
- **WHEN** a manifest node has a `group` field set
- **THEN** the community is derived from the group name (each unique group gets an incrementing integer ID)

#### Scenario: Community from dbt tags
- **WHEN** a manifest node has no group but has `tags` with at least one entry
- **THEN** the community is derived from the first tag (each unique tag gets an incrementing integer ID)

#### Scenario: Community from topology clustering
- **WHEN** neither group nor tags are present AND `networkx` is importable
- **THEN** Louvain-style modularity clustering is run on the DAG and community integers are assigned from cluster membership

#### Scenario: Community from layer fallback
- **WHEN** no group, no tags, and networkx is not available
- **THEN** community is assigned by layer: source=0, staging=1, intermediate=2, mart=3, seed=4, macro=5

#### Scenario: Source node community
- **WHEN** a node has `resource_type: "source"` or `resource_type: "seed"` and no group/tag
- **THEN** its community is determined by the layer fallback (always 0 or 4 respectively)

### Requirement: Include god nodes summarizing each layer
The builder SHALL include a `god_nodes` array in `graph.json` with one entry per layer listing all model names in that layer.

#### Scenario: God node content
- **WHEN** the graph contains 11 staging models
- **THEN** the god node for staging has `count: 11` and lists all staging model names in `models`

### Requirement: Write graphify-out/lineage.json with full ancestor/descendant maps
The builder SHALL write a `lineage.json` file mapping each node ID to its complete set of ancestors (all upstream nodes, recursively) and descendants (all downstream nodes, recursively) via BFS.

#### Scenario: Full ancestor chain
- **WHEN** a mart model depends on intermediate models that depend on staging models that depend on sources
- **THEN** `ancestors[mart_id]` includes the intermediate, staging, and source IDs

#### Scenario: Blast-radius lookup
- **WHEN** a staging model is referenced in `descendants`
- **THEN** all mart models that eventually read from it appear in `descendants[staging_id]`

### Requirement: Write graphify-out/GRAPH_REPORT.md as human-readable architecture summary
The builder SHALL write a `GRAPH_REPORT.md` with sections: architecture overview diagram, node inventory per layer with descriptions, blast-radius table, and community summary.

#### Scenario: Blast-radius table accuracy
- **WHEN** `stg_departments` is used by 7 downstream models (directly or transitively)
- **THEN** the blast-radius table row for `stg_departments` lists all 7 model names

#### Scenario: Node inventory completeness
- **WHEN** the graph has N nodes across all layers
- **THEN** every node appears in the GRAPH_REPORT.md inventory exactly once

### Requirement: Write graphify sidecar files — .graphify_root and .graphify_labels.json
The builder SHALL write the two sidecar files that graphify expects alongside `graph.json`:

- `.graphify_root` — plain text file containing the absolute path to the dbt project root (no trailing newline)
- `.graphify_labels.json` — JSON object mapping community integer IDs to human-readable community label strings (e.g. `{"0": "Sources", "1": "Staging", "2": "Intermediate", "3": "Marts"}`)

#### Scenario: .graphify_root written correctly
- **WHEN** the builder writes output to `graphify-out/`
- **THEN** `.graphify_root` contains the absolute path to the dbt project directory (e.g. `/Users/me/project/dbt_project`)

#### Scenario: .graphify_labels.json matches community assignments
- **WHEN** nodes are assigned community IDs 0, 1, 2, 3
- **THEN** `.graphify_labels.json` contains `{"0": "<label>", "1": "<label>", "2": "<label>", "3": "<label>"}` where each label matches the source of community assignment (group name, tag value, or layer name)

### Requirement: Delegate graph.html generation to graphify cluster-only
The builder SHALL attempt to generate `graph.html` by calling `graphify cluster-only <project_root>` after writing `graph.json`. This delegates the D3 visualization to graphify's own pipeline, which reads our `graph.json` and produces the interactive HTML.

#### Scenario: graphify is installed — HTML is generated
- **WHEN** `graphify cluster-only .` succeeds after our graph.json is written
- **THEN** `graphify-out/graph.html` exists and the CLI reports "graph.html generated via graphify"

#### Scenario: graphify is not installed — HTML is skipped gracefully
- **WHEN** `graphify` binary is not found on PATH
- **THEN** the builder prints a note "Install graphify (`pip install graphifyy`) to also generate graph.html" and continues without error

#### Scenario: graphify cluster-only fails — HTML is skipped gracefully
- **WHEN** `graphify cluster-only` exits non-zero (e.g. community naming LLM call fails)
- **THEN** the builder prints a warning but does not fail — graph.json, GRAPH_REPORT.md, and sidecar files are still valid

### Requirement: Output directory is configurable via --out flag
The builder SHALL accept an optional `--out <path>` CLI argument to write outputs to a custom directory instead of `graphify-out/`.

#### Scenario: Custom output directory
- **WHEN** the user runs `python3 dbt_graphify.py --out /tmp/my-graph`
- **THEN** all output files are written to `/tmp/my-graph/` and the directory is created if it does not exist
