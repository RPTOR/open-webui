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

## Seeding default notes

Run after the first admin signs up and obtains a token:

```sh
# Get admin token
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3001/api/v1/auths/signin \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@mantle.local","password":"Admin123!"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")

# Seed groups
./scripts/seed-groups.sh "$ADMIN_TOKEN"

# Seed notes
./scripts/seed-notes.sh "$ADMIN_TOKEN"
```

Then open each seeded note and use **Access Control** to share with the appropriate group (Admins, Curators, etc.).

## User groups & permissions

Three roles: `admin` (full access), `user` (permission-evaluated), `pending` (locked). Default for new signups is `user` via `DEFAULT_USER_ROLE` env var.

### Two user personas

| Persona | Workspace access | Description |
|---|---|---|
| **Curator** | models, knowledge, prompts | Creates RAG knowledge bases, uploads docs, binds to models |
| **Consumer** | knowledge | Uses chat, manages own knowledge bases, queries RAG via file upload |

### Consumer defaults (env vars in docker-compose)

```yaml
- USER_PERMISSIONS_WORKSPACE_MODELS_ACCESS=false
- USER_PERMISSIONS_WORKSPACE_KNOWLEDGE_ACCESS=true
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

# 4. Admin creates "MANTLE Extensions" group (replica of Consumer permissions + api_keys=true)
#    For external API access — members can generate API keys

# 5. Admin creates curator accounts and assigns them to the group

# 6. Curators log in, create knowledge bases, upload docs,
#    create RAG models bound to knowledge

# 7. Consumers sign up → automatically get restrictive defaults
#    They can only chat and upload files for RAG

# 8. API users → add to MANTLE Extensions group to enable API key generation
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

# 4. First admin signs up → obtain token and seed notes
#    (see "Seeding default notes" above)

# 5. Verify
curl -s http://localhost:3001/health
```

## Data

Persistent at `/root/frontend/open-webui/` via bind mount:
- `uploads/` — user-uploaded files
- `vector_db/` — RAG embeddings  
- `cache/` — model cache

Active database is PostgreSQL (configured via `DATABASE_URL`).
