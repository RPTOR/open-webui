#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# seed-notes.sh — Pre-seed MANTLE with welcome/guide notes
# Run AFTER the first admin user is created and a token is obtained.
#
# Usage:
#   1. Sign up/in as admin:
#      RESP=$(curl -s -X POST http://localhost:3001/api/v1/auths/signin \
#        -H "Content-Type: application/json" \
#        -d '{"email":"admin@mantle.local","password":"Admin123!"}')
#      TOKEN=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
#
#   2. Run this script:
#      ./scripts/seed-notes.sh $TOKEN
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BASE_URL="${MANTLE_URL:-http://localhost:3001}"
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <admin-token>"
  echo "Set MANTLE_URL env var to change base URL (default: http://localhost:3001)"
  exit 1
fi

create_note() {
  local title="$1"
  local md="$2"
  shift 2
  local html=""

  # Convert markdown to simple HTML (basic)
  html=$(echo "$md" | sed 's/^# \(.*\)/<h1>\1<\/h1>/; s/^## \(.*\)/<h2>\1<\/h2>/; s/^### \(.*\)/<h3>\1<\/h3>/; s/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g; s/^\- \(.*\)/<li>\1<\/li>/; s/^$/<br>/')

  echo "Creating note: $title"

  curl -s -X POST "$BASE_URL/api/v1/notes/create" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(cat <<EOF
{
  "title": "$title",
  "data": {
    "content": {
      "md": $(echo "$md" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))"),
      "html": $(echo "$html" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
    }
  }
}
EOF
)" | python3 -c "import sys,json; d=json.load(sys.stdin); print('  Created:', d.get('id','FAILED')[:8])" 2>/dev/null || echo "  FAILED"
}

echo "=== Seeding MANTLE notes ==="
echo ""

# ── Admin notes ─────────────────────────────────────────────────────────────

create_note \
  "Admin Guide — Getting Started" \
  "# Admin Guide\n\n\
Welcome to MANTLE. This guide covers the initial setup.\n\n\
## First Steps\n\
- **Create Curator accounts**: Admin Panel → Users → Add User\n\
- **Assign to Curator group**: Admin Panel → Users → Groups → Curator → Users → Add\n\
- **Review permissions**: Admin Panel → Users → Groups → Default Permissions\n\n\
## Managing the System\n\
- **Admin Settings**: Admin Panel → Settings (tabs are gated by MANTLE_SHOW_ADVANCED_SETTINGS)\n\
- **Usage analytics**: Available in Admin Panel → Analytics\n\
- **Backups**: PostgreSQL data is persistent in /root/frontend/open-webui"

# ── Curator notes ───────────────────────────────────────────────────────────

create_note \
  "Curator Guide — Creating RAG Models" \
  "# Creating RAG Models\n\n\
This guide walks through creating a RAG model and sharing it with users.\n\n\
## Step 1: Create a Knowledge Base\n\
1. Go to **Workspace → Knowledge**\n\
2. Click **New Knowledge**\n\
3. Upload documents (PDF, DOCX, TXT)\n\
4. Wait for processing to complete\n\n\
## Step 2: Create a Model\n\
1. Go to **Workspace → Models**\n\
2. Click **New Model**\n\
3. Select a base model (e.g., Qwen)\n\
4. In the **Knowledge** section, select your knowledge base\n\
5. Save the model\n\n\
## Step 3: Share with Users\n\
1. Click the **lock icon** next to the model name\n\
2. Click **Add Access** and select the Consumers group\n\
3. All group members can now see and use the model"

create_note \
  "Curator Guide — Managing Prompts" \
  "# Managing Prompts\n\n\
Prompts are reusable instructions that help users get consistent results.\n\n\
## Creating a Prompt\n\
1. Go to **Workspace → Prompts**\n\
2. Click **New Prompt**\n\
3. Write your prompt template\n\
4. Save and share with groups via Access Control\n\n\
## Tips\n\
- Use clear, specific instructions\n\
- Include placeholders for user input\n\
- Test prompts with different models before sharing"

# ── All-user notes ──────────────────────────────────────────────────────────

create_note \
  "About MANTLE" \
  "# About MANTLE\n\n\
Welcome to MANTLE — your AI-powered knowledge workspace.\n\n\
## What You Can Do\n\
- **Chat with AI models** using RAG-enhanced responses\n\
- **Upload documents** in chat to query them on the fly\n\
- **Create knowledge bases** to build persistent RAG collections\n\
- **Take notes** to record insights and share with your team\n\n\
## Need Help?\n\
Contact your system administrator for support."

echo ""
echo "=== Notes seeded successfully ==="
echo "IMPORTANT: Open each note and use Access Control to share with the appropriate group."
