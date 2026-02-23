# ── Stage 1: dependency install ─────────────────────────────────────────────
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder

# Build argument to optionally install embedding providers
# Options: "none" (default), "openai", "gemini", "huggingface", "all"
ARG EMBEDDING_EXTRAS=none

# build-essential needed to compile asyncmy's Cython extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency manifests first – changes to src/ won't bust this cache layer
COPY pyproject.toml uv.lock* ./

# Install dependencies based on EMBEDDING_EXTRAS
# --no-dev: skip dev dependencies
# --no-install-project: don't install the project itself, just dependencies
# --extra: install optional dependency groups only when needed
RUN if [ "$EMBEDDING_EXTRAS" = "none" ]; then \
        uv sync --no-dev --no-install-project; \
    elif [ "$EMBEDDING_EXTRAS" = "all" ]; then \
        uv sync --no-dev --no-install-project --extra all-embeddings; \
    else \
        uv sync --no-dev --no-install-project --extra "$EMBEDDING_EXTRAS"; \
    fi

# Copy application source
COPY src/ ./src/

# ── Stage 2: minimal runtime image ──────────────────────────────────────────
FROM python:3.11-slim-bookworm

WORKDIR /app
ENV PATH="/app/.venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Copy venv and source from builder – no build tools carried over
COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/src   /app/src

EXPOSE 30003

# Healthcheck using Python (no curl needed)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:30003/mcp').read()" || exit 1

# CMD uses SERVER_BASEPATH env var (default: /mcp, can be overridden at runtime)
CMD ["python", "src/server.py", "--host", "0.0.0.0", "--transport", "http", "--port", "30003"]
