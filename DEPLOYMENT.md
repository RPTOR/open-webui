# MANTLE — Deployment Guide

## Overview

MANTLE is a branded deployment of [Open Web UI](https://github.com/open-webui/open-webui). No source code is modified — all customizations are applied via:
- **Environment variables** (`WEBUI_NAME`, `MANTLE_SHOW_ADVANCED_SETTINGS`, etc.)
- **Static asset overlays** (`custom.css`, `bg.png`, favicon, logo)
- **Backend feature flag** (`MANTLE_SHOW_ADVANCED_SETTINGS` env var)

## Architecture

```
Browser ──► :3001 ──► MANTLE container (ghcr.io/open-webui/open-webui)
                         │
                         ├── PostgreSQL (shared `root-db-1`)
                         ├── uploads/     (bind mount)
                         ├── vector_db/   (bind mount)
                         └── cache/       (bind mount)
```

## Prerequisites

- Docker ≥ 24
- Docker network `homelab_network` (external bridge)
- PostgreSQL container `root-db-1` running on `homelab_network`
- Port `3001` free

## Quick Start

### 1. Compose file

Place a `docker-compose.yml` on the target host:

```yaml
services:
  mantle:
    image: ghcr.io/open-webui/open-webui:latest
    container_name: mantle
    restart: unless-stopped
    ports:
      - "3001:8080"
    volumes:
      - /root/frontend/open-webui:/app/backend/data
      - ./bg.png:/app/backend/open_webui/static/bg.png
    networks:
      - homelab_network
    environment:
      - WEBUI_NAME=MANTLE
      - WEBUI_SECRET_KEY=change-this-to-random-string
      - DATABASE_URL=postgresql://postgres:password@db:5432/openwebui
      - WEBUI_URL=https://your-domain.com
      - ENABLE_SIGNUP=True
      - DEFAULT_USER_ROLE=user
      - MANTLE_SHOW_ADVANCED_SETTINGS=Connections,Models,Evaluations,Documents,Web Search,Interface

networks:
  homelab_network:
    external: true
```

### 2. Place overlays

Alongside the compose file, place:
- `custom.css` — Visual theme — copy into container after start
- `favicon.png`, `logo.png`, `splash.png` — Branding assets

### 3. Start

```sh
docker compose up -d
```

### 4. Copy custom.css into container

custom.css can't be bind-mounted (file already exists in the image), so copy it in:

```sh
docker cp custom.css mantle:/app/backend/open_webui/static/custom.css
```

### 5. Verify

```sh
curl -s http://localhost:3001/health
```

## Environment Variables Reference

### Required

| Variable | Description |
|---|---|
| `WEBUI_NAME` | App name shown in sidebar, titles, auth page (~95% of UI text) |
| `WEBUI_SECRET_KEY` | Signs session cookies and JWTs. Reuse on restart to keep sessions valid. |

### Authentication

| Variable | Default | Description |
|---|---|---|
| `ENABLE_SIGNUP` | `True` | Allow new user registration |
| `DEFAULT_USER_ROLE` | `pending` | Default role: `user`, `admin`, or `pending` |
| `ENABLE_LOGIN_FORM` | `True` | Show username/password login |
| `ENABLE_LDAP` | `False` | LDAP/AD authentication |
| `WEBUI_URL` | — | Public URL for OAuth callbacks |

### Database

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | *(SQLite)* | PostgreSQL connection string |
| `ENABLE_DB_MIGRATIONS` | `True` | Auto-run Alembic migrations on startup |

Example:
```yaml
- DATABASE_URL=postgresql://postgres:password@db:5432/openwebui
```

### Admin Settings Visibility

Control which admin settings tabs are visible. Comma-separated list:

```yaml
- MANTLE_SHOW_ADVANCED_SETTINGS=Connections,Models,Evaluations,Documents,Web Search,Interface
```

Available values: `General` (always shown), `Connections`, `Models`, `Evaluations`, `Integrations`, `Documents`, `Web Search`, `Code Execution`, `Interface`, `Audio`, `Images`, `Pipelines`, `Database`.

If unset or empty, only `General` is visible.

### Ollama / OpenAI

| Variable | Description |
|---|---|
| `OLLAMA_BASE_URL` | Ollama server URL |
| `OPENAI_API_BASE_URL` | OpenAI-compatible API base URL |
| `OPENAI_API_KEY` | OpenAI API key |

## User Management

### Roles

Three roles: `admin` (full access), `user` (permission-evaluated), `pending` (locked). Default for new signups is set via `DEFAULT_USER_ROLE` env var.

### Two personas

| Persona | Workspace access | Description |
|---|---|---|
| **Curator** | models, knowledge, prompts | Creates RAG knowledge bases, uploads docs, binds to models |
| **Consumer** | None | Uses chat, queries RAG via file upload, no workspace access |

### Consumer permission defaults

Set these in the compose environment to restrict consumer users:

```yaml
- USER_PERMISSIONS_WORKSPACE_MODELS_ACCESS=false
- USER_PERMISSIONS_WORKSPACE_KNOWLEDGE_ACCESS=false
- USER_PERMISSIONS_WORKSPACE_PROMPTS_ACCESS=false
- USER_PERMISSIONS_WORKSPACE_TOOLS_ACCESS=false
- USER_PERMISSIONS_WORKSPACE_SKILLS_ACCESS=false
- USER_PERMISSIONS_FEATURES_IMAGE_GENERATION=false
- USER_PERMISSIONS_FEATURES_CHANNELS=false
- USER_PERMISSIONS_FEATURES_CODE_INTERPRETER=false
- USER_PERMISSIONS_FEATURES_AUTOMATIONS=false
- USER_PERMISSIONS_FEATURES_CALENDAR=false
- USER_PERMISSIONS_FEATURES_API_KEYS=false
- USER_PERMISSIONS_FEATURES_DIRECT_TOOL_SERVERS=false
- USER_PERMISSIONS_CHAT_TEMPORARY=false
- USER_PERMISSIONS_ACCESS_GRANTS_ALLOW_USERS=false
```

### Per-customer setup

```sh
# 1. First sign-up becomes admin

# 2. Admin creates "Curator" group:
#    Admin Panel → Users → Groups → New Group
#    Enable: workspace.models, workspace.knowledge, workspace.prompts

# 3. Admin creates curator accounts → assigns to Curator group

# 4. Curators log in, create knowledge bases, upload docs,
#    create RAG models bound to knowledge

# 5. Consumers sign up → automatically get restrictive defaults
#    They can only chat and upload files for RAG queries
```

### Complete permissions reference

All 49 permission flags are defined in `backend/open_webui/config.py:2630-2810`.

## Data Persistence

All persistent data lives at `/root/frontend/open-webui/` via bind mount:

| Path | Contents |
|---|---|
| `webui.db` | SQLite (fallback — PostgreSQL is primary) |
| `uploads/` | User-uploaded files |
| `vector_db/` | ChromaDB vector store for RAG knowledge bases |
| `cache/` | Whisper, embedding models, tiktoken cache |

The active database is PostgreSQL, configured via `DATABASE_URL`.

## Visual Theming

### custom.css

The file mounted at `./custom.css` overrides the upstream CSS at runtime. It controls:

| Aspect | CSS Approach |
|---|---|
| Body background | `.dark body { background: linear-gradient(...) }` |
| Accent colors | CSS variable overrides (`--color-emerald-*`, `--color-blue-*`, etc.) |
| Scrollbar | `::-webkit-scrollbar-thumb { background: ... }` |
| Selection | `::selection { background: ... }` |
| Links | `a { color: ... }` |
| Sidebar logo | `#sidebar-webui-name { background: gradient; -webkit-background-clip: text }` |
| Checkboxes/Switches | `input[checked], [role="switch"][aria-checked="true"] { background: ... }` |

### Chat Background

Users set their own background via **Settings (gear icon) → Interface → Chat Background Image → Upload**. The uploaded image is stored as a data URL in user settings — no server-side configuration needed.

### Static Assets

Replace files in the container's `/app/backend/open_webui/static/` directory:

| File | Replace with |
|---|---|
| `favicon.png` | Brand favicon |
| `favicon-dark.png` | Brand dark-mode favicon |
| `favicon.ico` | Legacy favicon |
| `favicon.svg` | SVG favicon |
| `logo.png` | Brand logo |
| `splash.png` | Light splash screen image |
| `splash-dark.png` | Dark splash screen image |

Mount files via compose volumes or copy them into the data directory.

## Multi-Deployment Checklist

For each new MANTLE instance:

```sh
# 1. Environment
docker network create homelab_network  # if not existing
# Ensure PostgreSQL is running and accessible as `db`

# 2. Deploy
docker compose up -d

# 3. Place overlays
cp favicon.png ./favicon.png
# ... repeat for all static assets

# 4. Copy custom.css into container
docker cp custom.css mantle:/app/backend/open_webui/static/custom.css

# 5. Verify
curl -s http://localhost:3001/health
```

## Updating

```sh
docker compose pull
docker compose up -d
```

The prebuilt image updates automatically to the latest upstream version. Data persists in the bind mount and PostgreSQL.

## Troubleshooting

| Symptom | Check |
|---|---|
| Background image not showing | Hard refresh (Cmd+Shift+R / Ctrl+Shift+R). Browser may cache the old CSS. |
| custom.css not taking effect | Verify the mount path: `docker exec mantle cat /app/backend/open_webui/static/custom.css` should show your content. |
| Database connection error | Confirm PostgreSQL is running: `docker ps \| grep root-db-1`. Check `DATABASE_URL` value. |
| Port conflict | Change the host port: `"3002:8080"` and update Caddy config. |
| Health check stuck | Wait 30-60s — embedding models download on first start. |
