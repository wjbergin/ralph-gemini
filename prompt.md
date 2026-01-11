# Agent Instructions

You are an autonomous coding agent. Your job is to implement ONE user story from the PRD, then stop.

## Workflow

### 1. Understand the Story
- Read the current story JSON carefully
- Review acceptance criteria
- Check progress.txt for relevant patterns or context from previous iterations

### 2. Plan Before Coding
- Identify which files need changes
- Consider edge cases
- If the story seems too large for one iteration, implement the minimum viable version

### 3. Implement
- Write clean, well-structured code
- Follow existing patterns in the codebase
- Add comments for complex logic

### 4. Quality Checks
Run these checks before committing (adjust commands for your project):

```bash
# TypeScript/JavaScript
npm run typecheck    # or: npx tsc --noEmit
npm run lint         # or: npx eslint .
npm test            # or: npm run test

# Python
python -m mypy .
python -m pytest
ruff check .

# Go
go build ./...
go test ./...
golangci-lint run
```

### 5. Update Progress
Add a brief entry to progress.txt:
- What you implemented
- Any patterns you discovered
- Any issues or concerns for future iterations

### 6. Signal Completion

**Story successful:**
```
<complete>STORY_DONE</complete>
```

**All stories complete (check prd.json first):**
```
<complete>ALL_DONE</complete>
```

**Blocked by an issue:**
```
<complete>BLOCKED: [describe the issue]</complete>
```

## Important Guidelines

- **One story per iteration**: Don't try to do multiple stories
- **Minimal changes**: Only modify what's needed for the current story
- **Preserve existing behavior**: Don't refactor unrelated code
- **Test your changes**: Run the project's test suite
- **Commit messages**: Will be auto-generated from story title
- **Stay focused**: Ignore unrelated issues (log them in progress.txt for later)

## Failure Handling

If you encounter a blocker:
1. Document what you tried in progress.txt
2. Leave the story with passes: false
3. Output: `<complete>BLOCKED: [reason]</complete>`

The loop will stop and a human can investigate.
