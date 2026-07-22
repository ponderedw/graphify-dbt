---
name: dbt-graphify
description: Parse the dbt manifest.json into a graphify knowledge graph, then query it
---

Run the dbt-graphify pipeline to convert this project's dbt manifest into a queryable graphify knowledge graph.

**Steps:**

1. Run the pipeline:
   ```bash
   # Use installed CLI if available, otherwise module
   if command -v dbt-graphify &>/dev/null; then
     dbt-graphify
   else
     python3 -m dbt_graphify
   fi
   ```

2. Parse the output and report:
   - Number of nodes and edges generated
   - Layer breakdown (source / staging / intermediate / mart / seed)
   - Which source was used (manifest.json or graph_summary.json fallback)
   - Whether graph.html was generated
   - Any errors with actionable next steps

3. If successful, confirm the user can now query with:
   ```
   /graphify query "<question>"
   ```
   Examples:
   - `graphify query "which models depend on stg_students?"`
   - `graphify query "trace the lineage of student_at_risk_report"`
   - `graphify query "what breaks if I change stg_departments?"`

**If the pipeline fails:**
- "No manifest.json or graph_summary.json found" → suggest running `dbt compile` or `dbt parse` in the dbt_project/ directory
- "Permission denied" → suggest `chmod +x` or using `python3 -m dbt_graphify`
- Any other error → print the full error and wait for guidance
