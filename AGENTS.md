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

The file at `./custom.css` is mounted into the container and provides all visual theming:
- Warm plum background gradient
- Amber/gold accent colors
- Chat background image with dark overlay (`/static/bg.png`)
- Gold-tinted scrollbar and selection
- Input focus rings in accent color

Swap `bg.png` for a different background image at any time — no rebuild needed.

## Multi-deployment checklist

For each new instance:

```sh
# 1. Start PostgreSQL (if not shared)
# 2. Deploy container
docker compose up -d

# 3. Place static overlays
#    custom.css, bg.png → mount into container
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
