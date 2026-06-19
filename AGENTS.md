# AGENTS.md — MANTLE

## Project

MANTLE is a white-labelled fork of [Open WebUI](https://github.com/open-webui/open-webui).
SvelteKit 5 frontend (`src/`) + Python FastAPI backend (`backend/open_webui/`).
The backend serves the built frontend as static files in production.

## Dev commands

```sh
# Frontend (Vite dev server on :5173)
npm run dev

# Backend (uvicorn with --reload on :8080)
cd backend && source dev.sh

# Full lint (ESLint -> svelte-check -> pylint)
npm run lint

# Python formatting only
ruff format . --exclude .venv --exclude venv

# Type check only
npm run check

# Frontend tests
npm run test:frontend

# i18n string extraction
npm run i18n:parse
```

## Required command order

`npm run lint` runs all three in sequence: eslint → svelte-check → pylint.
CI enforces: `format` (prettier) → `i18n:parse` → `build` → `test:frontend`.

## Setup quirks

- `npm install --force` required (CI uses it; peer dep conflicts by design).
- Node >=18.13.0 <=22.x.x enforced via `.npmrc` `engine-strict=true`.
- Python >=3.11, <3.13. Dependencies managed via `uv` (see `uv.lock`).
- `npm run build` / `npm run dev` automatically runs `scripts/prepare-pyodide.js` (fetches Pyodide WASM).
- Pre-commit: `ruff --fix backend/` then `ruff-format backend/` (backend only; no frontend pre-commit).

## Code style

- Python: ruff with `line-length = 120`, single quotes, isort enforced.
- ESLint: recommended + TypeScript + Svelte + Prettier (no semicolons config).
- Prettier formats `*.{js,ts,svelte,css,md,html,json}`.
- SvelteKit static adapter; app version polls `git rev-parse HEAD` every 60s.

## Upstream sync

Cherry-pick selectively from upstream (avoid mass merge):

```sh
git remote add upstream https://github.com/open-webui/open-webui
git fetch upstream
git cherry-pick <commit-hash>
```

After cherry-picking, verify no upstream "Open WebUI" strings leaked back in:

```sh
npm run check:branding
```

This greps for hardcoded `Open WebUI` in branded source files. Passes only when zero matches are found.

## Docker

Images are built locally (no prebuilt ghcr images). Primary deployment at `/root/frontend/`:

```sh
# Build and start
cd /root/frontend && docker compose up -d --build

# Or from the repo root with the same compose:
cd /home/jamescklim/development/MANTLE
docker compose -f /root/frontend/docker-compose.yaml up -d --build
```

Admin settings visibility controlled by env var. Comma-separated list enables only matching tabs:
```sh
MANTLE_SHOW_ADVANCED_SETTINGS=Models,Documents,Connections
```
If unset or empty, only the General tab is shown.

Dockerfile build variants (`cuda`, `cuda126`, `ollama`, `slim`) via build-args:
```sh
docker build --build-arg USE_CUDA=true -t mantle:cuda .
```

## UI branding

Core files to change when white-labelling:

| What | File | Action |
|---|---|---|
| Browser `<title>` fallback | `src/app.html:118` | `Open WebUI` → `MANTLE` |
| Nav title & page titles | Set env var `WEBUI_NAME=MANTLE` at deploy | Overrides all UI text |
| Backend name fallback | `backend/open_webui/env.py:771` | Default `'Open WebUI'` — upstream appends ` (Open WebUI)` when customized; remove that append logic |
| PWA manifest name | `static/static/site.webmanifest:2-3` | Change `name` / `short_name` |
| Favicons (PNG, SVG, ICO) | `static/static/favicon.*` | Replace image files |
| Logo / splash images | `static/static/splash.png`, `splash-dark.png`, `logo.png` | Replace image files |
| App icon assets | `static/static/apple-touch-icon.png`, `web-app-manifest-*.png` | Replace image files |

`WEBUI_NAME` env var covers most UI strings at runtime. Static assets (`static/static/`) are the only files requiring source changes for basic rebranding.

## Theme (warm plum & gold)

Dark mode color values compiled into the CSS bundle via `src/tailwind.css`:

```css
/* gray scale — warm plum backgrounds */
--color-gray-50: #faf5f0;   --color-gray-100: #f0e8e0;
--color-gray-200: #e0d5c8;  --color-gray-300: #c8b8a8;
--color-gray-400: #a89888;  --color-gray-500: #887868;
--color-gray-600: #685848;  --color-gray-700: #4a3a5a;
--color-gray-800: #352645;  --color-gray-850: #281b35;
--color-gray-900: #1c1225;  --color-gray-950: #120a18;

/* emerald → gold accent */
--color-emerald-400: #f5c542;  --color-emerald-500: #e8b028;
--color-emerald-600: #d49a1a;  --color-emerald-700: #b88210;
```

Body gradient in `src/app.css`:
```css
.dark body {
  background:
    radial-gradient(rgba(245,197,66,0.04) 1px, transparent 1px),  /* dot pattern */
    radial-gradient(ellipse 80% 60% at 100% 0%, rgba(245,197,66,0.06) 0%, transparent 60%),
    radial-gradient(ellipse 60% 40% at 0% 100%, rgba(168,85,247,0.05) 0%, transparent 50%),
    linear-gradient(160deg, #1c1225 0%, #281b38 25%, #352645 50%, #2d1d3a 75%, #1c1225 100%);
  background-size: 24px 24px, 100% 100%, 100% 100%, 100% 100%;
  background-attachment: fixed;
}
```

Chat background image (`static/static/bg.png`) with dark overlay via inline style in `Chat.svelte`:
```html
<div id="chat-pane" style="background: linear-gradient(rgba(0,0,0,0.45), rgba(0,0,0,0.45)), url('/static/bg.png') center / cover no-repeat scroll">
```

The gradient layer on top creates a uniform dark overlay over the image across both messages and input areas.

## Fork migration checklist

When starting from a fresh fork of upstream `open-webui/open-webui`, re-apply these changes:

| # | File | Change |
|---|---|---|
| 1 | `src/tailwind.css` | Replace `@theme` colors with warm plum/gold palette (see Theme section above) |
| 2 | `src/app.css` | Replace `.dark body` with layered gradient (see Theme section above) |
| 3 | `src/app.html:118` | `<title>Open WebUI</title>` → `<title>MANTLE</title>` |
| 4 | `src/app.html:120-131` | Add inline `<script id="mantle-theme">` after `<title>` that injects sidebar logo gradient on load |
| 5 | `src/lib/constants.ts:4` | `APP_NAME = 'Open WebUI'` → `APP_NAME = 'MANTLE'` |
| 6 | `src/routes/+layout.svelte:501,632,740` | `'• Open WebUI'` → `` `• \${$WEBUI_NAME}` `` (notification titles) |
| 7 | `src/lib/components/channel/Channel.svelte:9-16,291,294` | Import `WEBUI_NAME`, use `{$WEBUI_NAME}` in page titles |
| 8 | `src/lib/components/chat/Chat.svelte:3089` | Add `style="..."` with gradient overlay + bg image on `#chat-pane` (see Theme section above) |
| 9 | `backend/open_webui/env.py:771-773` | Remove `WEBUI_NAME += ' (Open WebUI)'` append logic |
| 10 | `static/static/site.webmanifest:2-3` | Change `name` / `short_name` to `MANTLE` |
| 11 | `static/static/bg.png` | Place chat background image here |
| 12 | `static/static/custom.css` | Scrollbar, selection styling (see file content in this repo) |
| 13 | `package.json` | Add `"check:branding"` script |
| 14 | `backend/open_webui/config.py:2987` | Add `MANTLE_SHOW_ADVANCED_SETTINGS = os.getenv('MANTLE_SHOW_ADVANCED_SETTINGS', '')` |
| 15 | `backend/open_webui/main.py:290` | Add `MANTLE_SHOW_ADVANCED_SETTINGS` to imports from config |
| 16 | `backend/open_webui/main.py:2419` | Add `'mantle_show_advanced_settings': MANTLE_SHOW_ADVANCED_SETTINGS` in public features dict |
| 17 | `src/lib/components/admin/Settings.svelte:33-52` | Add `visibleSettings` reactive block with `nameToId` mapping to gate tabs based on `$config?.features?.mantle_show_advanced_settings` |
| 18 | `docker-compose.yaml` | Add `MANTLE_SHOW_ADVANCED_SETTINGS=Connections,Models,...` env var |

After all changes, run:
```sh
npm run check:branding   # verify no "Open WebUI" leaks
npm run build            # build frontend
docker compose up -d --build  # rebuild Docker image and deploy
```

## Testing

- Frontend: vitest via `npm run test:frontend`.
- Backend: no unit/integration test suite visible. Functional testing via Playwright in Docker (see `docker-compose.playwright.yaml`).

## Architecture notes

- Backend entrypoint: `open_webui.main:app` (FastAPI). Also invocable via `open-webui serve` when installed as pip package.
- Version pinned from `package.json` via hatched build hook.
- DB: SQLAlchemy async, SQLite default, optional PostgreSQL. Migrations with Alembic (`backend/open_webui/migrations/`).
- Config stored persistently in DB via `open_webui/internal/config.py`.
- Bundled Ollama and sentence-transformers models are pre-downloaded during Docker build.
- HF_HUB_OFFLINE=1 supported for offline deployments.
