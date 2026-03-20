FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-docker.txt /tmp/requirements-docker.txt

RUN python -m pip install --upgrade pip \
    && python -m pip install -r /tmp/requirements-docker.txt

WORKDIR /usr/app

CMD ["/bin/sh", "-lc", "cp -n profiles.example.yml profiles.yml && tail -f /dev/null"]
