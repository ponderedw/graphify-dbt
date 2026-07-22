## ADDED Requirements

### Requirement: Poetry-managed pyproject.toml for PyPI distribution
The project SHALL have a `pyproject.toml` managed by Poetry with the package name `dbt-graphify`, a `[tool.poetry.scripts]` entry point exposing a `dbt-graphify` CLI command, and all metadata required for PyPI publication (description, homepage, license, author, classifiers).

#### Scenario: CLI entry point works after pip install
- **WHEN** a user installs the package via `pip install dbt-graphify`
- **THEN** running `dbt-graphify` in a terminal executes the main pipeline (equivalent to `python3 dbt_graphify.py`)

#### Scenario: pyproject.toml is valid
- **WHEN** `poetry check` is run
- **THEN** it exits with code 0 and reports no errors

### Requirement: Package source lives in a proper Python package directory
The script SHALL be refactored into a `dbt_graphify/` package directory with `__init__.py` and `__main__.py` so it is importable and executable as a module (`python -m dbt_graphify`).

#### Scenario: Module execution
- **WHEN** the user runs `python -m dbt_graphify path/to/manifest.json`
- **THEN** the pipeline runs identically to `dbt-graphify path/to/manifest.json`

### Requirement: No runtime dependencies beyond Python stdlib
The package SHALL declare zero required runtime dependencies in `pyproject.toml`. PyYAML SHALL be listed as an optional/extras dependency only.

#### Scenario: Install without extras
- **WHEN** a user installs `dbt-graphify` without extras
- **THEN** the CLI works fully using manifest.json or graph_summary.json (no YAML parsing needed)

#### Scenario: Install with yaml extras
- **WHEN** a user installs `dbt-graphify[yaml]`
- **THEN** PyYAML is available and the parser uses it to read `sources.yml` for richer descriptions

### Requirement: Poetry build produces a distributable wheel and sdist
Running `poetry build` SHALL produce both a `.whl` and a `.tar.gz` in the `dist/` directory, suitable for upload to PyPI via `poetry publish`.

#### Scenario: Build artifacts
- **WHEN** `poetry build` is run from the project root
- **THEN** `dist/dbt_graphify-<version>-py3-none-any.whl` and `dist/dbt_graphify-<version>.tar.gz` are created
