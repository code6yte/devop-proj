FROM quay.io/ansible/ansible-runner:latest as base

# Use a small downloader stage to fetch the Docker static CLI binary
FROM alpine:3.18 as downloader
ARG DOCKER_VERSION=24.0.5
RUN apk add --no-cache curl tar \
    && mkdir -p /out \
    && curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz -C /out

FROM base
# Copy docker binary from downloader stage
COPY --from=downloader /out/docker/docker /usr/local/bin/docker
RUN chmod +x /usr/local/bin/docker || true

# Install docker compose (python implementation) so we can run compose from this container
RUN set -eux; \
    if command -v pip3 >/dev/null 2>&1; then \
        pip3 install --no-cache-dir 'docker compose==1.29.2' || pip3 install --no-cache-dir docker compose; \
    elif command -v pip >/dev/null 2>&1; then \
        pip install --no-cache-dir 'docker compose==1.29.2' || pip install --no-cache-dir docker compose; \
    else \
        echo 'pip not found; docker compose will not be available' >&2; \
    fi

WORKDIR /ansible

CMD ["sleep", "infinity"]
