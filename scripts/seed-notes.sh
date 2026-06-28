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

create_note() {
  local title="$1"
  local content="$2"
  
  echo "Creating note: $title"
  
  # Encode content as JSON string via python to handle newlines properly
  local json_content
  json_content=$(python3 -c "
import sys, json
content = '''$content'''
print(json.dumps(content))
")

  curl -s -X POST "$BASE_URL/api/v1/notes/create" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\": $(printf '%s' "$title" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"), \"data\": {\"content\": {\"md\": $json_content}}}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('  Created:', d.get('id','FAILED')[:8])" 2>/dev/null || echo "  FAILED"
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
- **Admin Settings**: Admin Panel → Settings (tabs are gated by MANTLE_SHOW_ADVANCED_SETTINGS)
- **Usage analytics**: Available in Admin Panel → Analytics
- **Backups**: PostgreSQL data is persistent in the configured data volume"

# ── Curator notes ───────────────────────────────────────────────────────────

create_note \
  "Curator Guide — Creating RAG Models" \
"# Creating RAG Models

This guide walks through creating a RAG model and sharing it with users.

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
5. Save the model

## Step 3: Share with Users
1. Click the **lock icon** next to the model name
2. Click **Add Access** and select the Consumers group
3. All group members can now see and use the model"

create_note \
  "Curator Guide — Managing Prompts" \
"# Managing Prompts

Prompts are reusable instructions that help users get consistent results.

## Creating a Prompt
1. Go to **Workspace → Prompts**
2. Click **New Prompt**
3. Write your prompt template
4. Save and share with groups via Access Control

## Tips
- Use clear, specific instructions
- Include placeholders for user input
- Test prompts with different models before sharing"

# ── All-user notes ──────────────────────────────────────────────────────────

create_note \
  "About MANTLE" \
"Welcome to MANTLE — your AI-powered knowledge workspace.

## What You Can Do
- **Chat with AI models** using RAG-enhanced responses
- **Upload documents** in chat to query them on the fly
- **Create knowledge bases** to build persistent RAG collections
- **Use Channels** to collaborate with your team in shared conversations
- **Take notes** to record insights and share with your team

## Need Help?
Contact your system administrator for support."

echo ""
echo "=== Notes seeded successfully ==="
echo "IMPORTANT: Open each note and use Access Control to share with the appropriate group."
