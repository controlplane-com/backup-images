FROM debian:bookworm-slim

ARG TIDB_VERSION=v8.5.3
ARG TARGETARCH=amd64

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
 && ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo "arm64" || echo "amd64") \
 && mkdir /tmp/tidb-toolkit \
 && curl -fsSL "https://download.pingcap.com/tidb-community-toolkit-${TIDB_VERSION}-linux-${ARCH}.tar.gz" \
    | tar -xz -C /tmp/tidb-toolkit \
 && tar -xz -C /tmp/tidb-toolkit \
    -f /tmp/tidb-toolkit/tidb-community-toolkit-${TIDB_VERSION}-linux-${ARCH}/br-${TIDB_VERSION}-linux-${ARCH}.tar.gz \
 && find /tmp/tidb-toolkit -name br -type f | head -1 | xargs -I{} mv {} /usr/local/bin/br \
 && test -f /usr/local/bin/br \
 && rm -rf /tmp/tidb-toolkit \
 && rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/backup.sh"]
