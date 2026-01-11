#!/bin/bash
# loop.sh - Autonomous AI agent loop using Gemini CLI
# Usage: ./loop.sh [options] [max_iterations]
#
# Options:
#   --sandbox, -s     Run in Docker/Podman sandbox (recommended)
#   --yolo            Auto-approve all actions (default for autonomous loop)
#   --no-sandbox      Run without sandbox (native, less secure)
#
# Examples:
#   ./loop.sh                    # Default: sandbox + yolo, 10 iterations
#   ./loop.sh --sandbox 20       # Sandbox mode, 20 iterations
#   ./loop.sh --no-sandbox 5     # No sandbox, 5 iterations

set -e

# Parse arguments
USE_SANDBOX=true
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
    case $1 in
        --sandbox|-s)
            USE_SANDBOX=true
            shift
            ;;
        --no-sandbox)
            USE_SANDBOX=false
            shift
            ;;
        --yolo)
            # Already default, just consume the flag
            shift
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                MAX_ITERATIONS=$1
            fi
            shift
            ;;
    esac
done
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_iteration() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Check prerequisites
check_prerequisites() {
    if ! command -v gemini &> /dev/null; then
        log_error "Gemini CLI not found. Install it first:"
        log_info "npm install -g @google/gemini-cli"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install it first (apt install jq / brew install jq)"
        exit 1
    fi
    
    if [ ! -f "$PRD_FILE" ]; then
        log_error "prd.json not found. Create one first."
        log_info "See prd.json.example for format"
        exit 1
    fi
    
    if [ ! -f "$PROMPT_FILE" ]; then
        log_error "prompt.md not found. Create one first."
        exit 1
    fi
    
    # Check sandbox availability if enabled
    if [ "$USE_SANDBOX" = true ]; then
        if command -v docker &> /dev/null; then
            log_info "Sandbox: Docker available"
        elif command -v podman &> /dev/null; then
            log_info "Sandbox: Podman available"
        else
            log_warn "Docker/Podman not found. Sandbox may use macOS Seatbelt or fail."
            log_info "Install Docker or use --no-sandbox flag"
        fi
    fi
}

# Archive previous run
archive_previous_run() {
    if [ -f "$PROGRESS_FILE" ]; then
        mkdir -p "$ARCHIVE_DIR"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        cp "$PROGRESS_FILE" "$ARCHIVE_DIR/progress_$TIMESTAMP.txt"
        log_info "Archived previous progress to archive/progress_$TIMESTAMP.txt"
    fi
}

# Save current branch
save_current_branch() {
    git branch --show-current > "$LAST_BRANCH_FILE" 2>/dev/null || echo "main" > "$LAST_BRANCH_FILE"
}

# Set up feature branch
setup_branch() {
    BRANCH_NAME=$(jq -r '.branchName // "feature/agent-work"' "$PRD_FILE")
    
    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
        log_info "Checking out existing branch: $BRANCH_NAME"
        git checkout "$BRANCH_NAME"
    else
        log_info "Creating new branch: $BRANCH_NAME"
        git checkout -b "$BRANCH_NAME"
    fi
}

# Get next incomplete story
get_next_story() {
    jq -r '.userStories | map(select(.passes != true)) | .[0] // "null"' "$PRD_FILE"
}

# Count completed stories
count_stories() {
    TOTAL=$(jq '.userStories | length' "$PRD_FILE")
    DONE=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
    echo "$DONE/$TOTAL"
}

# Check if all stories are complete
all_stories_complete() {
    REMAINING=$(jq '[.userStories[] | select(.passes != true)] | length' "$PRD_FILE")
    [ "$REMAINING" -eq 0 ]
}

# Build the prompt for this iteration
build_prompt() {
    local STORY_JSON="$1"
    local ITERATION="$2"
    
    # Read the prompt template
    PROMPT_TEMPLATE=$(cat "$PROMPT_FILE")
    
    # Get project context
    PROJECT_NAME=$(jq -r '.projectName // "Project"' "$PRD_FILE")
    PROJECT_DESC=$(jq -r '.description // ""' "$PRD_FILE")
    
    # Read progress file content
    PROGRESS_CONTENT=""
    if [ -f "$PROGRESS_FILE" ]; then
        PROGRESS_CONTENT=$(cat "$PROGRESS_FILE")
    fi
    
    # Build the full prompt
    cat << EOF
# Context

Project: $PROJECT_NAME
$PROJECT_DESC

## Iteration $ITERATION

## Current Story
\`\`\`json
$STORY_JSON
\`\`\`

## Progress File
\`\`\`
$PROGRESS_CONTENT
\`\`\`

---

$PROMPT_TEMPLATE
EOF
}

# Run a single iteration
run_iteration() {
    local ITERATION=$1
    local STORY_JSON="$2"
    
    STORY_ID=$(echo "$STORY_JSON" | jq -r '.id')
    STORY_TITLE=$(echo "$STORY_JSON" | jq -r '.title')
    
    log_iteration
    log_info "ITERATION $ITERATION: $STORY_ID - $STORY_TITLE"
    log_info "Progress: $(count_stories) complete"
    log_iteration
    
    # Build the prompt
    FULL_PROMPT=$(build_prompt "$STORY_JSON" "$ITERATION")
    
    # Run Gemini CLI in headless mode
    # --yolo: auto-approve tool actions (file writes, shell commands)
    # -s/--sandbox: run in Docker/Podman container for isolation
    # --output-format json: structured output for parsing
    log_info "Running Gemini CLI..."
    
    GEMINI_FLAGS="--yolo --output-format json"
    if [ "$USE_SANDBOX" = true ]; then
        GEMINI_FLAGS="-s $GEMINI_FLAGS"
        log_info "(sandbox mode enabled)"
    fi
    
    RESULT=$(echo "$FULL_PROMPT" | gemini -p - $GEMINI_FLAGS 2>&1) || true
    GEMINI_EXIT=$?
    
    # Extract the response text
    RESPONSE=$(echo "$RESULT" | jq -r '.response // empty' 2>/dev/null || echo "$RESULT")
    
    # Check for completion signals
    if echo "$RESPONSE" | grep -q "<complete>ALL_DONE</complete>"; then
        log_success "Agent signaled ALL_DONE"
        return 0
    elif echo "$RESPONSE" | grep -q "<complete>STORY_DONE</complete>"; then
        log_success "Story $STORY_ID completed"
        # Mark story as complete in PRD
        mark_story_complete "$STORY_ID"
        git add -A
        git commit -m "Complete $STORY_ID: $STORY_TITLE" --allow-empty || true
        return 0
    elif echo "$RESPONSE" | grep -q "<complete>BLOCKED:"; then
        REASON=$(echo "$RESPONSE" | grep -oP '(?<=<complete>BLOCKED:).*(?=</complete>)')
        log_error "Story blocked: $REASON"
        return 1
    fi
    
    # If no explicit signal, check if there were changes
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        log_info "Changes detected, committing..."
        git add -A
        git commit -m "WIP: $STORY_ID - iteration $ITERATION" --allow-empty || true
    fi
    
    if [ $GEMINI_EXIT -ne 0 ]; then
        log_error "Gemini CLI exited with error code $GEMINI_EXIT"
        return 1
    fi
    
    return 0
}

# Mark a story as complete
mark_story_complete() {
    local STORY_ID="$1"
    
    # Update the PRD file
    jq --arg id "$STORY_ID" '
        .userStories |= map(
            if .id == $id then .passes = true else . end
        )
    ' "$PRD_FILE" > "${PRD_FILE}.tmp" && mv "${PRD_FILE}.tmp" "$PRD_FILE"
    
    log_success "Marked $STORY_ID as complete in prd.json"
}

# Main loop
main() {
    log_info "Starting autonomous agent loop with Gemini CLI"
    log_info "Max iterations: $MAX_ITERATIONS"
    if [ "$USE_SANDBOX" = true ]; then
        log_info "Sandbox: ENABLED (Docker/Podman isolation)"
    else
        log_warn "Sandbox: DISABLED (running with full system access)"
    fi
    
    check_prerequisites
    archive_previous_run
    save_current_branch
    setup_branch
    
    # Initialize progress file if it doesn't exist
    if [ ! -f "$PROGRESS_FILE" ]; then
        cat > "$PROGRESS_FILE" << 'EOF'
# Progress Log

## Codebase Patterns
(The agent will document patterns discovered here)

## Session Log
(The agent will log progress here)
EOF
    fi
    
    for ((i=1; i<=MAX_ITERATIONS; i++)); do
        # Check if all done
        if all_stories_complete; then
            log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_success "ALL STORIES COMPLETE!"
            log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            exit 0
        fi
        
        # Get next story
        STORY_JSON=$(get_next_story)
        
        if [ "$STORY_JSON" == "null" ] || [ -z "$STORY_JSON" ]; then
            log_success "No more stories to process"
            exit 0
        fi
        
        # Run iteration
        if ! run_iteration "$i" "$STORY_JSON"; then
            log_error "Iteration $i failed"
            log_info "Check the output above for details"
            exit 1
        fi
        
        # Brief pause between iterations
        sleep 2
    done
    
    log_warn "Reached max iterations ($MAX_ITERATIONS)"
    log_info "Progress: $(count_stories) stories complete"
    log_info "Run again to continue"
}

main "$@"
