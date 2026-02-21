# ── Stage 1: dependency install ─────────────────────────────────────────────
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder

# build-essential needed to compile asyncmy's Cython extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency manifests first – changes to src/ won't bust this cache layer
COPY pyproject.toml uv.lock* ./

# Install only core (non-embedding) deps into an in-project venv
RUN uv sync --no-dev --no-install-project

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

# CMD uses SERVER_BASEPATH env var (default: /mcp, can be overridden at runtime)
CMD ["python", "src/server.py", "--host", "0.0.0.0", "--transport", "http", "--port", "30003"]
