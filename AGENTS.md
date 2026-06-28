# AGENTS.md — MANTLE

## Project

MANTLE is a branded deployment of [Open Web UI](https://github.com/open-webui/open-webui) using the prebuilt image with env vars and static asset overlays. No source code modifications — only:
- `WEBUI_NAME` env var for runtime name
- `custom.css` for visual theming
- Static file replacements for assets
- Backend feature flag for admin settings gating

## Prerequisites

- Docker ≥ 24
- Docker network `homelab_network` (external bridge)
- PostgreSQL container reachable as `db` on `homelab_network`
- Port `3001` free (or adjust in compose)

## Quick start

```sh
docker compose up -d
```

## Env vars

| Variable | Value | Purpose |
|---|---|---|
| `WEBUI_NAME` | `MANTLE` | App name in ~95% of UI |
| `WEBUI_SECRET_KEY` | *(keep existing)* | Session/JWT signing |
| `DATABASE_URL` | `postgresql://postgres:pass@db:5432/openwebui` | PostgreSQL connection |
| `WEBUI_URL` | public URL | OAuth callback / CORS |
| `ENABLE_SIGNUP` | `True` | Allow new user registration |
| `DEFAULT_USER_ROLE` | `user` | Default role on signup |
| `MANTLE_SHOW_ADVANCED_SETTINGS` | `Connections,Models,...` | Comma-separated admin tabs to show |

## custom.css

The file at `./custom.css` provides visual theming. Copy it in after container start:

```sh
docker cp custom.css mantle:/app/backend/open_webui/static/custom.css
```

The theme includes:
- Warm plum background gradient
- Amber/gold accent colors
- Gold-tinted scrollbar and selection
- Input focus rings in accent color

## Chat background

Users set their own background via **Settings (gear icon) → Interface → Chat Background Image → Upload**. No default bg is set — users choose what they want.

## User groups & permissions

Three roles: `admin` (full access), `user` (permission-evaluated), `pending` (locked). Default for new signups is `user` via `DEFAULT_USER_ROLE` env var.

### Two user personas

| Persona | Workspace access | Description |
|---|---|---|
| **Curator** | models, knowledge, prompts | Creates RAG knowledge bases, uploads docs, binds to models |
| **Consumer** | None | Uses chat, queries RAG via file upload, no workspace access |

### Consumer defaults (env vars in docker-compose)

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

### Setup flow per customer

```sh
# 1. Deploy with env vars above
docker compose up -d && docker cp custom.css mantle:/app/...

# 2. First sign-up becomes admin

# 3. Admin creates "Curator" group:
#    Admin → Users → Groups → New Group
#    Enable: workspace.models, workspace.knowledge, workspace.prompts

# 4. Admin creates curator accounts and assigns them to the group

# 5. Curators log in, create knowledge bases, upload docs,
#    create RAG models bound to knowledge

# 6. Consumers sign up → automatically get restrictive defaults
#    They can only chat and upload files for RAG
```

### Complete permissions reference

All 49 flags at `backend/open_webui/config.py:2630-2810`.

## Multi-deployment checklist

For each new instance:

```sh
# 1. Start PostgreSQL (if not shared)
# 2. Deploy container
docker compose up -d

# 3. Place static overlays
#    custom.css → copy into container
docker cp custom.css mantle:/app/backend/open_webui/static/custom.css
#    favicon.*, logo.png, splash*.png → replace in static dir

# 4. Verify
curl -s http://localhost:3001/health
```

## Data

Persistent at `/root/frontend/open-webui/` via bind mount:
- `uploads/` — user-uploaded files
- `vector_db/` — RAG embeddings  
- `cache/` — model cache

Active database is PostgreSQL (configured via `DATABASE_URL`).
