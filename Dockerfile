# dbt-graphify MCP server
#
# Exposes snapshot history to AI agents via MCP (stdio or SSE).
# Supports reading from a local volume or from S3.
#
# ── Build ──────────────────────────────────────────────────────────────────────
#
#   docker build -t dbt-graphify-mcp .
#
# ── Run — local volume (stdio, for Claude Code) ───────────────────────────────
#
#   docker run --rm -i \
#     -v /path/to/your/graphify-out:/snapshots:ro \
#     dbt-graphify-mcp
#
# ── Run — S3 backend (stdio, for Claude Code) ─────────────────────────────────
#
#   docker run --rm -i \
#     -e S3_PATH=s3://my-bucket/psdw \
#     -e AWS_ACCESS_KEY_ID=AKIA... \
#     -e AWS_SECRET_ACCESS_KEY=... \
#     -e AWS_DEFAULT_REGION=us-east-1 \
#     dbt-graphify-mcp
#
# ── Run — SSE (HTTP / browser) ────────────────────────────────────────────────
#
#   docker run --rm -p 8080:8080 \
#     -e S3_PATH=s3://my-bucket/psdw \
#     -e AWS_ACCESS_KEY_ID=AKIA... \
#     -e AWS_SECRET_ACCESS_KEY=... \
#     -e TRANSPORT=sse \
#     dbt-graphify-mcp
#
# ── Claude Code .claude/settings.json ─────────────────────────────────────────
#
#   Local mode:
#   {
#     "mcpServers": {
#       "dbt-graphify": {
#         "command": "docker",
#         "args": ["run","--rm","-i","-v","${workspaceFolder}/graphify-out:/snapshots:ro","dbt-graphify-mcp"]
#       }
#     }
#   }
#
#   S3 mode:
#   {
#     "mcpServers": {
#       "dbt-graphify": {
#         "command": "docker",
#         "args": ["run","--rm","-i",
#                  "-e","S3_PATH=s3://my-bucket/psdw",
#                  "-e","AWS_ACCESS_KEY_ID=...",
#                  "-e","AWS_SECRET_ACCESS_KEY=...",
#                  "dbt-graphify-mcp"]
#       }
#     }
#   }

FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml poetry.lock* README.md ./
COPY dbt_graphify/ ./dbt_graphify/

# Install package with MCP + S3 extras, plus graphify for query tools
RUN pip install --no-cache-dir ".[mcp-server,s3]" \
 && pip install --no-cache-dir graphifyy

# ── Environment variables ──────────────────────────────────────────────────────
# S3_PATH              s3://bucket/project   (use S3 backend)
# AWS_ACCESS_KEY_ID    AWS access key        (required for S3 mode)
# AWS_SECRET_ACCESS_KEY  AWS secret key      (required for S3 mode)
# AWS_DEFAULT_REGION   AWS region            (default: us-east-1)
# SNAPSHOTS_DIR        local volume path     (default: /snapshots, used when S3_PATH unset)
# TRANSPORT            stdio | sse           (default: stdio)
# PORT                 HTTP port for SSE     (default: 8080)
# MANIFEST_PATH        path to manifest.json (enables --watch mode when set)

ENV SNAPSHOTS_DIR=/snapshots
ENV TRANSPORT=stdio
ENV PORT=8080
ENV TOKEN=""
ENV MANIFEST_PATH=""

VOLUME /snapshots

ENTRYPOINT ["sh", "-c", \
  "dbt-graphify mcp --snapshots-dir \"$SNAPSHOTS_DIR\" --transport \"$TRANSPORT\" --port \"$PORT\" ${TOKEN:+--token \"$TOKEN\"} ${MANIFEST_PATH:+--watch --manifest \"$MANIFEST_PATH\"}"]
