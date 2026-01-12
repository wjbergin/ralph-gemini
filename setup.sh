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
if ! command -v gemini &> /dev/null; then
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
log_info "Gemini will ask you questions about your project."
echo ""

# Run Gemini CLI interactively with the PRD generation prompt
gemini -p "You are a product requirements assistant. Your job is to interview the user about their project and generate a prd.json file.

## Interview Process

Ask these questions ONE AT A TIME (wait for answers):

1. **Project name**: What do you want to call this feature/project?
2. **Description**: In 1-2 sentences, what does it do?
3. **Branch name**: What git branch should we use? (suggest: feature/[project-name-kebab-case])
4. **User stories**: What are the main tasks? Ask them to list 3-8 discrete pieces of work.

For each user story they mention, ask:
- What are the acceptance criteria? (How do we know it's done?)
- Any technical notes or hints?

## Output Format

After gathering all info, generate the prd.json file with this EXACT structure:

\`\`\`json
{
  \"projectName\": \"...\",
  \"branchName\": \"feature/...\",
  \"description\": \"...\",
  \"userStories\": [
    {
      \"id\": \"US-001\",
      \"title\": \"Short title\",
      \"priority\": 1,
      \"passes\": false,
      \"acceptanceCriteria\": [\"...\", \"...\"],
      \"technicalNotes\": \"...\"
    }
  ]
}
\`\`\`

## Rules

- Keep stories small and focused (1-2 hours of work each)
- Number IDs sequentially: US-001, US-002, etc.
- Priority should reflect dependency order (do US-001 before US-002)
- All stories start with \"passes\": false
- Be conversational and helpful

Start by greeting the user and asking for the project name."

# Check if prd.json was created
if [ -f "$PRD_FILE" ]; then
    log_success "prd.json created!"
    echo ""
    echo "Contents:"
    cat "$PRD_FILE"
    echo ""
    log_info "Run ./loop.sh to start the autonomous agent"
else
    log_warn "prd.json was not created."
    log_info "You can copy the JSON from the conversation above and save it manually."
fi
