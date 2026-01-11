#!/bin/bash
# generate-prd.sh - Generate PRD from a project description
# Usage: ./generate-prd.sh "Build a REST API for managing todos with auth"
# Usage: ./generate-prd.sh < project-description.txt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Check prerequisites
if ! command -v gemini &> /dev/null; then
    echo "Gemini CLI not found. Install with: npm install -g @google/gemini-cli"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq not found. Install with: apt install jq / brew install jq"
    exit 1
fi

# Get project description
if [ -n "$1" ]; then
    PROJECT_DESC="$*"
elif [ ! -t 0 ]; then
    PROJECT_DESC=$(cat)
else
    echo "Usage: ./generate-prd.sh \"Your project description\""
    echo "   or: ./generate-prd.sh < description.txt"
    exit 1
fi

log_info "Generating PRD from description..."

# Generate PRD using Gemini CLI in headless mode
RESULT=$(gemini -p "You are a product requirements generator. Given a project description, create a prd.json file.

## Project Description:
$PROJECT_DESC

## Instructions:
1. Infer a good project name and branch name
2. Break the work into 4-8 small, focused user stories
3. Each story should be ~1-2 hours of work
4. Order stories by dependency (foundations first)
5. Write clear acceptance criteria for each

## Output:
Return ONLY valid JSON (no markdown, no explanation) in this exact format:

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
      \"acceptanceCriteria\": [\"...\"],
      \"technicalNotes\": \"...\"
    }
  ]
}

Generate the PRD now:" --output-format json 2>&1)

# Extract the response
RESPONSE=$(echo "$RESULT" | jq -r '.response // empty' 2>/dev/null || echo "$RESULT")

# Try to extract JSON from the response
# Handle case where response might have markdown code blocks
JSON_CONTENT=$(echo "$RESPONSE" | sed -n '/^{/,/^}/p' | head -1)

if [ -z "$JSON_CONTENT" ]; then
    # Try to extract from code block
    JSON_CONTENT=$(echo "$RESPONSE" | sed -n '/```json/,/```/p' | sed '1d;$d')
fi

if [ -z "$JSON_CONTENT" ]; then
    # Just try the whole response
    JSON_CONTENT="$RESPONSE"
fi

# Validate JSON
if echo "$JSON_CONTENT" | jq . > /dev/null 2>&1; then
    echo "$JSON_CONTENT" | jq . > "$PRD_FILE"
    log_success "Generated prd.json:"
    echo ""
    jq . "$PRD_FILE"
    echo ""
    log_info "Review and edit as needed, then run ./loop.sh"
else
    echo "Failed to generate valid JSON. Raw response:"
    echo "$RESPONSE"
    exit 1
fi
