# graphify
- **graphify** (`.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

<!-- dbt-graphify-skill start -->
# dbt-graphify
- **dbt-graphify** (`.claude/skills/dbt-graphify/SKILL.md`) - dbt lineage queries. Trigger: `/dbt-graphify`
When the user types `/dbt-graphify`, use the dbt-graphify skill before doing anything else.
- Use `/dbt-graphify` for **dbt lineage questions** (models, dependencies, blast radius, lineage).
- Use `/graphify` for **all other codebase questions** (code architecture, file relationships, non-dbt content).
<!-- dbt-graphify-skill end -->
