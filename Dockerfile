FROM python:3.11-slim-bookworm AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git pkg-config portaudio19-dev \
    libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev \
    libavutil-dev libswresample-dev libswscale-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY deploy/build-constraints.txt /app/build-constraints.txt
ENV PIP_CONSTRAINT=/app/build-constraints.txt
RUN pip install --no-cache-dir poetry==1.8.5
COPY pyproject.toml poetry.lock README.md ./
RUN poetry check --lock \
    && poetry export --only main --format=requirements.txt --without-hashes --output=/app/requirements.txt \
    && pip install --no-cache-dir --no-deps --requirement /app/requirements.txt
COPY owl ./owl
RUN poetry install --only-root --no-ansi

FROM python:3.11-slim-bookworm AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    OMP_NUM_THREADS=1 \
    HF_HOME=/data/models/huggingface \
    TORCH_HOME=/data/models/torch \
    NLTK_DATA=/data/models/nltk

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg libportaudio2 libsndfile1 libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local /usr/local
WORKDIR /app
COPY --from=builder /app/owl ./owl
COPY alembic.ini ./
COPY alembic ./alembic
LABEL org.opencontainers.image.source="https://github.com/MephistoJB/Recap"
EXPOSE 8000
ENTRYPOINT ["owl"]
CMD ["serve", "--host", "0.0.0.0", "--config", "/config/config.yaml"]
