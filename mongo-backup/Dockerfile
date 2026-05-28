FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    gnupg \
    curl \
    ca-certificates \
    awscli \
 # MongoDB 8.0 database tools (mongodump, mongorestore, etc.)
 && curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
    | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg \
 && echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" \
    > /etc/apt/sources.list.d/mongodb-org-8.0.list \
 # Google Cloud CLI
 && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    mongodb-database-tools \
    google-cloud-cli \
 && rm -rf /var/lib/apt/lists/*

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/backup.sh"]
