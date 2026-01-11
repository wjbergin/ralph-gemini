# Ralph for Gemini CLI

An autonomous AI agent loop that runs Gemini CLI repeatedly until all PRD items are complete. Each iteration is a fresh Gemini CLI instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                     loop.sh                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Read prd.json│───▶│ Get next    │───▶│ Build prompt│     │
│  │             │    │ incomplete  │    │             │     │
│  └─────────────┘    │ story       │    └──────┬──────┘     │
│                     └─────────────┘           │            │
│                                               ▼            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Update      │◀───│ Check       │◀───│ Run Gemini  │     │
│  │ prd.json    │    │ completion  │    │ CLI --yolo  │     │
│  │ & commit    │    │ signals     │    └─────────────┘     │
│  └─────────────┘    └─────────────┘                        │
│        │                                                    │
│        └──────────────── Loop until all done ──────────────┘
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Gemini CLI** - Google's AI coding CLI
   ```bash
   npm install -g @google/gemini-cli
   gemini  # First run will prompt for auth
   ```

2. **jq** - JSON processor
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt install jq
   ```

3. **Git repository** - The loop commits after each story

## Quick Start

1. Copy files to your project:
   ```bash
   cp loop.sh prompt.md prd.json.example /path/to/your/project/
   cd /path/to/your/project
   chmod +x loop.sh
   ```

2. Create your PRD:
   ```bash
   cp prd.json.example prd.json
   # Edit prd.json with your stories
   ```

3. Run:
   ```bash
   ./loop.sh
   ```

## Files

| File | Purpose |
|------|---------|
| `loop.sh` | Main script - orchestrates the agent loop |
| `prompt.md` | Instructions sent to Gemini each iteration |
| `prd.json` | Your user stories (auto-updated as stories complete) |
| `progress.txt` | Persistent memory between iterations (auto-created) |
| `archive/` | Archived progress files from previous runs |

## PRD Format

```json
{
  "projectName": "My Feature",
  "branchName": "feature/my-feature",
  "description": "What this feature does",
  "userStories": [
    {
      "id": "US-001",
      "title": "Short description",
      "priority": 1,
      "passes": false,
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2"
      ],
      "technicalNotes": "Optional hints for the agent"
    }
  ]
}
```

## Completion Signals

The agent signals completion by outputting specific markers:

| Signal | Meaning |
|--------|---------|
| `<complete>STORY_DONE</complete>` | Current story is complete |
| `<complete>ALL_DONE</complete>` | All stories are complete |
| `<complete>BLOCKED: reason</complete>` | Hit a blocker, human intervention needed |

## Options

```bash
# Run with default 10 iterations
./loop.sh

# Run with custom max iterations
./loop.sh 20
```

## Gemini CLI vs Claude Code

This is a port of the [Claude Code version](https://github.com/...) to Gemini CLI. Key differences:

| Feature | Claude Code | Gemini CLI |
|---------|-------------|------------|
| Headless flag | `-p "prompt"` | `-p "prompt"` or `-p -` (stdin) |
| Auto-approve | `--dangerously-skip-permissions` | `--yolo` |
| JSON output | `--output-format json` | `--output-format json` |
| Context file | `CLAUDE.md` | `GEMINI.md` |
| Free tier | API key required | 60 req/min, 1000 req/day |

## Context Files

Gemini CLI reads `GEMINI.md` from your project root for persistent context. Use it for:
- Project conventions
- File structure overview
- Common commands
- Tech stack details

Example:
```markdown
# Project Context

## Tech Stack
- Node.js 22 + TypeScript
- PostgreSQL with Prisma
- React + Tailwind

## Commands
- `npm run dev` - Start development server
- `npm test` - Run tests
- `npm run lint` - Run linter
```

## Tips

1. **Small stories**: Break work into small, testable chunks
2. **Clear acceptance criteria**: The agent uses these to verify completion
3. **Technical notes**: Provide hints about existing patterns
4. **Check progress.txt**: See what the agent learned between iterations
5. **Review commits**: The agent commits after each story

## Troubleshooting

**Gemini CLI not authenticated:**
```bash
gemini  # Interactive mode prompts for auth
```

**Story keeps failing:**
- Check `progress.txt` for error details
- Make acceptance criteria more specific
- Add technical notes with more context

**Rate limited:**
- Free tier: 60 req/min, 1000 req/day
- Add delays between iterations (already 2s by default)
- Consider API key for higher limits

## License

MIT
