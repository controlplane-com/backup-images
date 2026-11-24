# Major version per tag: 18.x.y image tags build the default; other majors pass the
# server image through the publish workflow's build_args input, e.g.
#   17.x.y: PG_IMAGE_TAG=17.12-trixie
#   19.x.y: PG_IMAGE_TAG=19.0-trixie
ARG PG_IMAGE_TAG=18.7-trixie
FROM postgres:${PG_IMAGE_TAG}

RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get install -y --no-install-recommends \
    awscli \
    ca-certificates \
    curl \
    gnupg \
 && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends google-cloud-cli \
 && rm -rf /var/lib/apt/lists/* \
 # gosu is only used by the upstream server entrypoint, which this image replaces
 && rm -f /usr/local/bin/gosu

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/backup.sh"]