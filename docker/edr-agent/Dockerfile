# ── Stage 1: Builder ─────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ── Stage 2: Runtime ─────────────────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Agent code — only what the agent needs, not the server
COPY agent/ agent/
COPY shared/ shared/
COPY templates/ templates/
COPY config.py logger.py collector.py fim.py hasher.py reporter.py vt_checker.py ./
COPY agent/config.yaml .

# Default config — overridable via env vars
ENV MINIEDR_MODE=monitor \
    MINIEDR_LOG_LEVEL=INFO

ENTRYPOINT ["python", "-m", "agent.main"]
CMD ["--mode", "monitor"]
