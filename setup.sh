#!/bin/bash
# setup.sh - Interactive PRD generator using Gemini CLI
# Usage: ./setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check prerequisites
if ! command -v gemini &>/dev/null; then
  echo "Gemini CLI not found. Install with: npm install -g @google/gemini-cli"
  exit 1
fi

if [ -f "$PRD_FILE" ]; then
  log_warn "prd.json already exists!"
  read -p "Overwrite? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

log_info "Starting interactive PRD generator..."
log_info "Gemini will help you create a prd.json file."
echo ""

# Backup existing GEMINI.md if present
GEMINI_MD="$SCRIPT_DIR/GEMINI.md"
BACKUP_MD=""
if [ -f "$GEMINI_MD" ]; then
  BACKUP_MD="$SCRIPT_DIR/.GEMINI.md.backup.$$"
  cp "$GEMINI_MD" "$BACKUP_MD"
fi

# Create temporary GEMINI.md with interview instructions
cat >"$GEMINI_MD" <<'INSTRUCTIONS'
# PRD Generator Mode

You are helping create a prd.json file for the Ralph autonomous agent loop.

## Your task:

Interview the user about their project, then write a prd.json file.

### Questions to ask (one at a time):

1. What's the project name?
2. What does it do? (1-2 sentences)
3. What git branch should we use? (suggest: feature/project-name)
4. What are the main tasks? (aim for 3-8 small pieces of work)

For each task, clarify:
- How will we know it's done? (acceptance criteria)
- Any technical hints?

### When ready, write prd.json:

```json
{
  "projectName": "...",
  "branchName": "feature/...",
  "description": "...",
  "userStories": [
    {
      "id": "US-001",
      "title": "Short title",
      "priority": 1,
      "passes": false,
      "acceptanceCriteria": ["...", "..."],
      "technicalNotes": "..."
    }
  ]
}
```

Rules:
- Keep stories small (~1-2 hours each)
- Number IDs: US-001, US-002, etc.
- Priority = dependency order (do US-001 before US-002)
- All stories start with "passes": false

Start by greeting the user and asking for the project name.
INSTRUCTIONS

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "When done, tell Gemini to 'write the prd.json file'"
echo "Type /quit or Ctrl+D to exit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run Gemini interactively
cd "$SCRIPT_DIR"
gemini -i @"$GEMINI_MD"

# Restore original GEMINI.md
if [ -n "$BACKUP_MD" ] && [ -f "$BACKUP_MD" ]; then
  mv "$BACKUP_MD" "$GEMINI_MD"
else
  rm -f "$GEMINI_MD"
fi

# Check if prd.json was created
echo ""
if [ -f "$PRD_FILE" ]; then
  log_success "prd.json created!"
  echo ""
  log_info "Run ./loop.sh to start the autonomous agent"
else
  log_warn "prd.json was not created."
  log_info "Run setup.sh again and ask Gemini to 'write the prd.json file'"
fi
