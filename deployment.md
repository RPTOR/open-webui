# MANTLE — Deployment Guide

## Architecture

```
Browser ──► :3001 ──► MANTLE container (FastAPI + SvelteKit :8080)
                         │              │
                         ▼              ▼
                   PostgreSQL      MinIO (S3)
                   (root-db-1)     (open-webui-data bucket)
                   └── openwebui
                         ▲
                         │
                   OpenLearning reads chat data directly
                   from openwebui.chat_message table
```

**Centralized PostgreSQL** — MANTLE uses the `openwebui` database on the shared `root-db-1` PostgreSQL instance. OpenLearning reads chat data directly from this database for analytics.

## Prerequisites

- **Docker** ≥ 24 (Docker Desktop on macOS)
- **Git** (to clone the repo)
- 8+ GB RAM recommended (embedding models load into memory)
- Port `3001` available (or change in compose)
- Docker network `homelab_network` must exist
- PostgreSQL container `root-db-1` running on `homelab_network`
- MinIO container running on `homelab_network` (for S3 storage)

## Quick start

```sh
git clone <repo-url> mantle
cd mantle

# Create the network if it doesn't exist
docker network create homelab_network

# Choose your compose file:
docker compose up -d --build              # Linux server with homelab_network
docker compose -f docker-compose.mac.yaml up -d --build  # macOS standalone
```

Open `http://localhost:3001` in your browser.

## Compose Files

| File | Use case |
|---|---|
| `docker-compose.yaml` | Linux deployment with external `homelab_network` |
| `docker-compose.mac.yaml` | macOS standalone (built-in Docker networking) |
| `docker-compose.gpu.yaml` | CUDA GPU passthrough |
| `docker-compose.amdgpu.yaml` | AMD GPU passthrough |

## Environment Variables

### Required

| Variable | Default | Description |
|---|---|---|
| `WEBUI_NAME` | `MANTLE` | App name shown in sidebar, titles, auth page |
| `WEBUI_SECRET_KEY` | *(generate one)* | Signs session cookies and JWTs |

### Database (Centralized PostgreSQL)

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | SQLite | PostgreSQL connection string: `postgresql://user:pass@db:5432/openwebui` |

When using `homelab_network`, the PostgreSQL hostname is `db` (the `root-db-1` container).

### S3 Storage (MinIO)

| Variable | Default | Description |
|---|---|---|
| `STORAGE_PROVIDER` | — | Set to `s3` for external storage |
| `S3_ENDPOINT_URL` | — | MinIO endpoint: `http://minio:9000` |
| `S3_ACCESS_KEY_ID` | — | MinIO access key |
| `S3_SECRET_ACCESS_KEY` | — | MinIO secret key |
| `S3_BUCKET_NAME` | — | Bucket name: `open-webui-data` |
| `S3_REGION_NAME` | `us-east-1` | S3 region |
| `S3_SECURE` | `False` | Use HTTPS for S3 |
| `S3_UPLOAD_DIR` | `uploads` | Upload directory in bucket |
| `ENABLE_S3_STORAGE` | `False` | Enable S3 storage |
| `S3_SIGNATURE_VERSION` | `s3v4` | S3 signature version |
| `S3_FORCE_PATH_STYLE` | `False` | Use path-style URLs |

### Admin settings visibility

```sh
MANTLE_SHOW_ADVANCED_SETTINGS=Connections,Models,Evaluations,Documents,Web Search,Interface
```

Comma-separated list of admin settings tabs to show. Available values: `General` (always shown), `Connections`, `Models`, `Evaluations`, `Integrations`, `Documents`, `Web Search`, `Code Execution`, `Interface`, `Audio`, `Images`, `Pipelines`, `Database`. If unset or empty, only `General` is visible.

### Optional

| Variable | Description |
|---|---|
| `OLLAMA_BASE_URL` | Ollama server URL (default: `http://localhost:11434`) |
| `OPENAI_API_BASE_URL` | OpenAI-compatible API base URL |
| `OPENAI_API_KEY` | OpenAI API key |
| `WEBUI_URL` | Public-facing URL for auth callbacks |
| `HF_HUB_OFFLINE` | Set to `1` for air-gapped deployments |
| `ENABLE_SIGNUP` | `True` / `False` (default: `True`) |
| `DEFAULT_USER_ROLE` | `user`, `admin`, or `pending` |
| `LOG_LEVEL` | Logging verbosity (default: `INFO`) |
| `ENABLE_RAG_OCR` | `True` / `False` — Enable OCR for RAG document processing |
| `CONTENT_EXTRACTION_ENGINE` | `pypdfium2` or other — Engine for PDF extraction |

## Database Configuration

### Centralized PostgreSQL (Production)

MANTLE connects to a shared PostgreSQL instance (`root-db-1`) on the `homelab_network`:

```yaml
environment:
  - DATABASE_URL=postgresql://postgres:password@db:5432/openwebui
```

The `openwebui` database stores:
- Users, sessions, authentication
- Chat history and conversations
- Models, configurations, settings
- Vector embeddings for RAG

**OpenLearning Integration**: OpenLearning reads chat data directly from `openwebui.public.chat_message` for analytics. No sync needed — both apps share the same database.

### SQLite (Development/macOS)

For standalone development, MANTLE can use SQLite:

```yaml
volumes:
  - ./data:/app/backend/data
```

The `./data` directory contains:
- `webui.db` — SQLite database (users, chats, config, models)
- `cache/` — Whisper & embedding model downloads
- `uploads/` — User-uploaded files
- `vector_db/` — ChromaDB vector store for RAG

## S3 Storage Configuration

File uploads are stored in MinIO (S3-compatible) on `homelab_network`:

```yaml
environment:
  - STORAGE_PROVIDER=s3
  - S3_ENDPOINT_URL=http://minio:9000
  - S3_ACCESS_KEY_ID=admin
  - S3_SECRET_ACCESS_KEY=your-secret-key
  - S3_BUCKET_NAME=open-webui-data
  - S3_REGION_NAME=us-east-1
  - S3_SECURE=False
  - S3_UPLOAD_DIR=uploads
  - ENABLE_S3_STORAGE=True
  - S3_SIGNATURE_VERSION=s3v4
  - S3_FORCE_PATH_STYLE=True
```

Access MinIO console at `http://localhost:9001` (credentials: admin / your-secret-key).

## Migrating from SQLite to PostgreSQL

If you have an existing SQLite-based MANTLE instance and want to migrate to centralized PostgreSQL:

```sh
# 1. Export data from SQLite
docker exec mantle python -c "
import sqlite3, json
conn = sqlite3.connect('/app/backend/data/webui.db')
# Export tables as needed
"

# 2. Import to PostgreSQL
docker exec -i root-db-1 psql -U postgres -d openwebui < export.sql

# 3. Update MANTLE environment to use PostgreSQL
# Set DATABASE_URL in docker-compose.yaml
```

Alternatively, start fresh with PostgreSQL and re-create users/chats manually.

## Migrating from a previous Open WebUI instance

If you have an existing Open WebUI data directory (SQLite), you can migrate to MANTLE:

```sh
# Stop MANTLE
docker compose down

# For SQLite migration: Copy old data into MANTLE's data directory
cp -r /path/to/old/open-webui-data/* ./data/

# For PostgreSQL migration: Import the SQLite dump into the openwebui database
# Then point MANTLE to PostgreSQL via DATABASE_URL

# Start MANTLE
docker compose up -d --build
```

The schema is forward-compatible — MANTLE runs migrations automatically on startup.

## Updating

Pull the latest code changes and rebuild:

```sh
git pull
docker compose up -d --build
```

Docker layer caching speeds up subsequent builds (the frontend and backend only rebuild if source files changed).

## Apple Silicon (M1–M5)

The Dockerfile is multi-arch — no special flags needed. Docker automatically pulls `linux/arm64` base images:

```
node:22-alpine3.20 (arm64) ← frontend build
python:3.11-slim-bookworm (arm64) ← backend runtime
```

### Recommended Docker Desktop Settings

- **Memory**: 8 GB minimum, 12 GB recommended
- **CPU**: 4+ cores
- **Disk**: 20+ GB free (Docker images + cached models)

### Using Ollama on macOS

Install Ollama natively (Apple Silicon native, faster than Docker):

```sh
brew install ollama
ollama serve
```

Then set in your compose env:

```yaml
environment:
  - OLLAMA_BASE_URL=http://host.docker.internal:11434
```

`host.docker.internal` resolves to the macOS host from inside the container.

## First User / Admin Account

The first sign-up becomes the admin. Go to `http://localhost:3001`, sign up with any email/password. To create additional users as admin, use Settings → Users.

## OpenLearning Integration

OpenLearning reads chat data directly from the `openwebui` database for analytics:

- **Shared database**: Both MANTLE and OpenLearning connect to `root-db-1` on `homelab_network`
- **No sync needed**: OpenLearning queries `openwebui.public.chat_message` directly
- **User mapping**: OpenWebUI user UUIDs map to OpenLearning users via `public.users.openwebui_id`

This architecture eliminates data duplication and ensures analytics are always up-to-date.

## Backup & Restore

### Backup the openwebui database

```sh
# Using the manage.sh script from deployment directory
./manage.sh db backup openwebui

# Or manually
docker exec root-db-1 pg_dump -U postgres -d openwebui | gzip > openwebui_backup.sql.gz
```

### Restore

```sh
gunzip -c openwebui_backup.sql.gz | docker exec -i root-db-1 psql -U postgres -d openwebui
```

### Backup S3 storage (MinIO)

```sh
# Using mc (MinIO client)
mc alias set local http://localhost:9000 admin your-secret-key
mc mirror local/open-webui-data ./minio-backup/
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Page loads but stays on splash screen | Check `docker logs mantle \| grep -i error`, ensure Ollama URL is reachable |
| `Cannot connect to Ollama` | Verify `OLLAMA_BASE_URL` is correct; from macOS container use `host.docker.internal` |
| Health check fails | Wait 30–60s; embedding models load on first start |
| Build fails with npm errors | Ensure `npm install --force` is used (the Dockerfile already does this) |
| Out of memory | Increase Docker Desktop memory allocation to 8+ GB |
| Port already in use | Change the compose port mapping (e.g., `3002:8080`) |
| Background image not updating | Hard refresh browser (Cmd+Shift+R / Ctrl+Shift+R); the image path uses cache-busting in the CSS |
| `connection refused` to database | Ensure `root-db-1` is running and `homelab_network` exists |
| S3 upload errors | Verify MinIO is running on `homelab_network` and credentials are correct |
| OpenLearning shows no chat data | Verify both containers are on `homelab_network` and OpenLearning has correct `OPENWEBUI_PG_DATABASE=openwebui` |
