# The br binary comes from PingCAP's own multi-arch image (linux/amd64 +
# linux/arm64), which is both the authoritative source and vastly cheaper than
# the previous approach: that downloaded the full tidb-community-toolkit
# tarball and unpacked it to take one file. The toolkit grew from ~428 MB at
# v8.5.3 to ~1.5 GB at v8.5.7 (it now carries lightning, dumpling, dm, grafana,
# prometheus and tiup), and unpacking it exhausted the builder.
ARG TIDB_VERSION=v8.5.7
FROM pingcap/br:${TIDB_VERSION} AS br

FROM debian:bookworm-slim

# ca-certificates is required for TLS to S3/GCS endpoints.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# br sits at the filesystem root in the upstream image and is not on PATH.
COPY --from=br /br /usr/local/bin/br
RUN chmod +x /usr/local/bin/br && br --version

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/backup.sh"]
