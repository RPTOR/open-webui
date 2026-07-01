#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# seed-groups.sh — Create default MANTLE user groups
# Run AFTER the first admin signs up and obtains a token.
#
# Usage:
#   1. Get admin token:
#      ADMIN_TOKEN=$(curl -s -X POST http://localhost:3001/api/v1/auths/signin \
#        -H "Content-Type: application/json" \
#        -d '{"email":"admin@mantle.local","password":"Admin123!"}' | \
#        python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
#
#   2. Run this script:
#      ./scripts/seed-groups.sh "$ADMIN_TOKEN"
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BASE_URL="${MANTLE_URL:-http://localhost:3001}"
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <admin-token>"
  echo "Set MANTLE_URL env var to change base URL (default: http://localhost:3001)"
  exit 1
fi

create_group() {
  local name="$1"
  local description="$2"
  shift 2
  local perms="$1"

  echo "Creating group: $name"
  
  curl -s -X POST "$BASE_URL/api/v1/groups/create" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$name\", \"description\": \"$description\", \"permissions\": $perms}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('  Created:', d.get('name','FAILED'), '(' + d.get('id','')[:8] + '...)')" 2>/dev/null || echo "  FAILED"
}

echo "=== Seeding MANTLE groups ==="
echo ""

# ── Curator group ──
create_group \
  "Curator" \
  "Content creators with workspace access (models, knowledge, prompts)" \
  '{
    "workspace": {
      "models": true, "knowledge": true, "prompts": true,
      "tools": false, "skills": false
    }
  }'

# ── MANTLE Extensions group ──
create_group \
  "MANTLE Extensions" \
  "External API/system access with API key generation" \
  '{
    "workspace": {
      "models": false, "knowledge": false, "prompts": false,
      "tools": false, "skills": false,
      "models_import": false, "models_export": false,
      "prompts_import": false, "prompts_export": false,
      "tools_import": false, "tools_export": false
    },
    "sharing": {
      "models": false, "public_models": false,
      "knowledge": false, "public_knowledge": false,
      "prompts": false, "public_prompts": false,
      "tools": false, "public_tools": false,
      "skills": false, "public_skills": false,
      "notes": false, "public_notes": false,
      "public_chats": false, "public_calendars": false
    },
    "access_grants": { "allow_users": true },
    "chat": {
      "controls": true, "valves": true, "system_prompt": true,
      "params": true, "file_upload": true, "web_upload": false,
      "delete": true, "delete_message": true,
      "continue_response": true, "regenerate_response": true,
      "rate_response": true, "edit": true, "share": true,
      "export": true, "stt": true, "tts": true, "call": true,
      "multiple_models": true, "temporary": true, "temporary_enforced": false
    },
    "features": {
      "api_keys": true, "notes": true, "channels": true,
      "folders": true, "direct_tool_servers": false,
      "web_search": true, "image_generation": false,
      "code_interpreter": false, "memories": true,
      "automations": false, "calendar": false
    },
    "settings": { "interface": true }
  }'

# ── Consumer defaults ──
echo ""
echo "=== Default consumer permissions are set via env vars in docker-compose.yaml ==="
echo "Groups, Notes, and Knowledge enabled by default."
echo "Models, Tools, Skills, Image Gen, Channels, Code Interpreter disabled."

echo ""
echo "=== Groups seeded successfully ==="
echo "Next step: Create users and assign them to the appropriate groups."
