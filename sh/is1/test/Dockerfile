FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        bash git shellcheck bats \
        ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root test user with ~/.local/bin in PATH
RUN useradd -m -s /bin/bash testuser && \
    mkdir -p /home/testuser/.local/bin

ENV PATH="/home/testuser/.local/bin:$PATH"
ENV HOME=/home/testuser

WORKDIR /repo
