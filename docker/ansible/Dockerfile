FROM quay.io/ansible/ansible-runner:latest as base

# Use a small downloader stage to fetch the Docker static CLI binary
FROM alpine:3.18 as downloader
ARG DOCKER_VERSION=24.0.5
RUN apk add --no-cache curl tar jq \
    && mkdir -p /out \
    && curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz -C /out \
    && cp /usr/bin/jq /out/jq

FROM base

# Copy docker binary from downloader stage

COPY --from=downloader /out/docker/docker /usr/local/bin/docker

COPY --from=downloader /out/jq /usr/local/bin/jq

RUN chmod +x /usr/local/bin/docker /usr/local/bin/jq || true

# Install Docker Compose V2 plugin
RUN mkdir -p /usr/local/lib/docker/cli-plugins && \
    curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

WORKDIR /project
# Copy entire project for docker-compose context
COPY . /project

WORKDIR /ansible
COPY ansible /ansible

# Make sure the script is executable
RUN chmod +x /ansible/authealer.sh

# Run the authealer script as the main process
CMD ["/ansible/authealer.sh"]
