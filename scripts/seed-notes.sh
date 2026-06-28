#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# seed-notes.sh — Pre-seed MANTLE with welcome/guide notes
# Run AFTER the first admin user is created and a token is obtained.
#
# Usage:
#   1. Get admin token:
#      ADMIN_TOKEN=$(curl -s -X POST http://localhost:3001/api/v1/auths/signin \
#        -H "Content-Type: application/json" \
#        -d '{"email":"admin@mantle.local","password":"Admin123!"}' | \
#        python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
#
#   2. Run this script:
#      ./scripts/seed-notes.sh "$ADMIN_TOKEN"
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BASE_URL="${MANTLE_URL:-http://localhost:3001}"
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <admin-token>"
  echo "Set MANTLE_URL env var to change base URL (default: http://localhost:3001)"
  exit 1
fi

# ── Helpers ─────────────────────────────────────────────────────────────────

get_group_id() {
  local name="$1"
  curl -s -G "$BASE_URL/api/v1/groups/" \
    -H "Authorization: Bearer $TOKEN" \
    --data-urlencode "name=$name" 2>/dev/null | python3 -c "
import sys, json
try:
    groups = json.load(sys.stdin)
    for g in groups if isinstance(groups, list) else []:
        if g.get('name','').lower() == '$name'.lower():
            print(g['id'])
except: pass
"
}

create_note() {
  local title="$1"
  local content="$2"
  shift 2
  local share_groups=("$@")
  
  echo "Creating note: $title"
  
  local json_content
  json_content=$(python3 -c "
import sys, json
content = '''$content'''
print(json.dumps(content))
")

  local response
  response=$(curl -s -X POST "$BASE_URL/api/v1/notes/create" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\": $(printf '%s' "$title" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"), \"data\": {\"content\": {\"md\": $json_content}}}")
  
  local note_id
  note_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
  
  if [ -z "$note_id" ]; then
    echo "  FAILED to create note"
    return
  fi
  
  echo "  Created: ${note_id:0:8}"
  
  # Share with specified groups
  for group_name in "${share_groups[@]}"; do
    local group_id
    group_id=$(get_group_id "$group_name")
    if [ -n "$group_id" ]; then
      curl -s -X POST "$BASE_URL/api/v1/notes/$note_id/access/update" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"access_grants\": [{\"principal_type\": \"group\", \"principal_id\": \"$group_id\", \"permission\": \"read\"}]}" \
        > /dev/null
      echo "    Shared with group: $group_name"
    else
      echo "    Group not found: $group_name (skipping)"
    fi
  done
}

echo "=== Seeding MANTLE notes ==="
echo ""

# ── Admin notes ─────────────────────────────────────────────────────────────

create_note \
  "Admin Guide — Getting Started" \
"# Admin Guide

Welcome to MANTLE. This guide covers the initial setup.

## First Steps
- **Create Curator accounts**: Admin Panel → Users → Add User
- **Assign to Curator group**: Admin Panel → Users → Groups → Curator → Users → Add
- **Review permissions**: Admin Panel → Users → Groups → Default Permissions

## Managing the System
- **Admin Settings**: Admin Panel → Settings
- **Usage analytics**: Available in Admin Panel → Analytics
- **Backups**: PostgreSQL data is persistent in the configured data volume" \
  "Admin"

# ── Curator notes ───────────────────────────────────────────────────────────

create_note \
  "Curator Guide — Creating RAG Models" \
"This guide walks through creating a RAG model and sharing it with users.

## Step 1: Create a Knowledge Base
1. Go to **Workspace → Knowledge**
2. Click **New Knowledge**
3. Upload documents (PDF, DOCX, TXT)
4. Wait for processing to complete

## Step 2: Create a Model
1. Go to **Workspace → Models**
2. Click **New Model**
3. Select a base model (e.g., Qwen)
4. In the **Knowledge** section, select your knowledge base
5. Use the **System Prompt** field to set instructions for how the model should respond based on your knowledge
6. Add **Tags** (e.g., \"finance\", \"hr\", \"academic\") — tags appear as filter options in the chat model dropdown, making it easy for users to find models by category
7. Save the model

## Step 3: Share with Users
1. Click the **lock icon** next to the model name
2. Click **Add Access** and select the Consumers group
3. All group members can now see and use the model" \
  "Curator"

create_note \
  "Curator Guide — Managing Prompts" \
"Prompts are reusable instructions that help users get consistent results.

## Creating a Prompt
1. Go to **Workspace → Prompts**
2. Click **New Prompt**
3. Write your prompt template
4. Save and share with groups via Access Control

## Tips
- Use clear, specific instructions
- Include placeholders for user input
- Test prompts with different models before sharing" \
  "Curator"

create_note \
  "System Prompt Samples" \
"Example system prompts you can use when creating RAG models.

## Q&A Assistant
You are a helpful assistant answering questions based on the provided knowledge base. Answer clearly and concisely. If the answer is not in the knowledge base, say so \u2014 do not make up information.

## Summarizer
You are a summarization assistant. Given a document or conversation, provide a concise summary covering the key points. Use bullet points for clarity.

## Tutor
You are an educational tutor. Explain concepts in simple terms suitable for students. Use examples and analogies. If the user asks a question, guide them to the answer rather than giving it directly.

## Analyst
You are a data analyst. Review the provided documents and extract key insights, trends, and patterns. Present findings in a structured format with headings and bullet points.

## Tips
- Keep system prompts clear and specific
- Set the expected tone (formal, casual, technical)
- Define what the model should do when it cannot find an answer
- Test with sample questions before sharing with users" \
  "Curator"

# ── All-user notes ──────────────────────────────────────────────────────────

create_note \
  "About MANTLE" \
"Welcome to MANTLE \u2014 your AI-powered knowledge workspace.

## What You Can Do
- **Chat with AI models** using RAG-enhanced responses
- **Upload documents** in chat to query them on the fly
- **Create knowledge bases** to build persistent RAG collections
- **Use Channels** to collaborate with your team in shared conversations
- **Take notes** to record insights and share with your team

## Need Help?
Contact your system administrator for support." \
  "Curator" "Students"

echo ""
echo "=== Notes seeded successfully ==="
