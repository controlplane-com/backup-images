# Control Plane Backup Images

This repository contains the source code for the database backup Docker images used in the [Control Plane Templates Catalog](https://docs.controlplane.com/template-catalog).

Built images are published to DockerHub at [hub.docker.com/u/controlplanecorporation](https://hub.docker.com/u/controlplanecorporation).

---

## Images

| Image | Base | Tool |
|---|---|---|
| `backup-mysql` | `mysql:8-debian` | `mysqldump` |
| `backup-mongo` | `mongo:7-jammy` | `mongodump` |
| `backup-postgres` | `postgres:18` | `pg_dumpall` |
| `backup-redis` | `redis:7-bookworm` | `redis-cli --rdb` |
| `backup-tidb` | `debian:bookworm-slim` | TiDB BR |

Each image runs a single backup on container start and exits. They are intended to be run as cron jobs or one-shot workloads within Control Plane.

---

## Cloud Storage Providers

All images support backing up to either AWS S3 or Google Cloud Storage. The target is controlled by the `BACKUP_PROVIDER` environment variable.

Cloud credentials must be available at runtime — either via workload identity (recommended) or by injecting the appropriate environment variables (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` for AWS, or `GOOGLE_APPLICATION_CREDENTIALS` for GCP).

---

## Environment Variables

### Common (all images)

| Variable | Description |
|---|---|
| `BACKUP_PROVIDER` | `aws` or `gcp` |
| `BACKUP_BUCKET` | Bucket name |
| `BACKUP_PREFIX` | Path prefix within the bucket |

### MySQL

| Variable | Description |
|---|---|
| `MYSQL_HOST` | Database host |
| `MYSQL_PORT` | Database port |
| `MYSQL_ROOT_PASSWORD` | Root password |

### MongoDB

| Variable | Description |
|---|---|
| `MONGO_URI` | Full connection URI (takes precedence if set) |
| `MONGO_HOST` | Database host (used if `MONGO_URI` is not set) |
| `MONGO_PORT` | Database port (default: `27017`) |
| `MONGO_USER` | Username |
| `MONGO_PASSWORD` | Password |
| `MONGO_DB` | Specific database to back up (optional — backs up all if omitted) |

### PostgreSQL

| Variable | Description |
|---|---|
| `PG_HOST` | Database host |
| `PG_PORT` | Database port |
| `PG_USER` | Username (default: `root`) |
| `PG_PASSWORD` | Password |
| `AWS_REGION` | Required when `BACKUP_PROVIDER=aws` |

### Redis

| Variable | Description |
|---|---|
| `REDIS_HOST` | Redis host |
| `REDIS_PORT` | Redis port (default: `6379`) |
| `REDIS_PASSWORD` | Password (optional) |

For Redis **cluster mode**, the following are also required:

| Variable | Description |
|---|---|
| `NUM_PRIMARIES` | Number of primary nodes in the cluster |
| `REDIS_WORKLOAD_NAME` | Control Plane workload name for the Redis statefulset |
| `CPLN_GVC` | Control Plane GVC name |
| `CPLN_LOCATION` | Control Plane location |

### TiDB

| Variable | Description |
|---|---|
| `TIDB_PD_ADDR` | PD server address |
| `AWS_REGION` | Required when `BACKUP_PROVIDER=aws` |

---

## Repository Structure

```
backups/
├── backup-mongo/
│   ├── Dockerfile
│   └── backup.sh
├── backup-mysql/
│   ├── Dockerfile
│   └── backup.sh
├── backup-postgres/
│   ├── Dockerfile
│   └── backup.sh
├── backup-redis/
│   ├── Dockerfile
│   └── backup.sh
└── backup-tidb/
    ├── Dockerfile
    └── backup.sh
```

---

## Contributing

Pull requests are welcome. If you are fixing a bug or adding support for a new provider, please:

1. Fork the repo and create a branch from `main`.
2. Test your changes by building the image locally:
   ```bash
   docker build -t backup-<db>:local ./backup-<db>
   ```
3. Open a pull request with a clear description of the change.

---

## Documentation

Full documentation for template backups, including how to configure cron jobs and cloud credentials in Control Plane, can be found at [docs.controlplane.com/template-catalog](https://docs.controlplane.com/template-catalog).
