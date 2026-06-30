# claude-code-critic

Critic-in-the-loop hook for Claude Code. A second AI reviews every response against your project rules **before it reaches you**. Violations get sent back for revision automatically.

Uses `claude -p` (Claude Code CLI) — no API key needed, runs on your existing subscription.

## How it works

```
Claude writes response
       ↓
  Stop hook fires
       ↓
  critic.mjs reads response + loads rules from rules/
       ↓
  Calls `claude -p --model opus` with critic prompt
       ↓
  Critic returns {"ok": true} or {"ok": false, "reason": "..."}
       ↓
  ok=true → response reaches you
  ok=false → Claude gets the reason and keeps working
```

## Install

```bash
git clone https://github.com/coolk8/claude-code-critic
cd claude-code-critic
chmod +x install.sh
./install.sh /path/to/your/project
```

This adds a `Stop` hook to your project's `.claude/settings.local.json`.

## Rules

Rules are markdown files in `rules/`. Each rule describes what to check and when it applies.

Included rule:

- **no-guessing** — when solving problems, every diagnosis must be backed by logs, docs, or code inspection. No speculating without evidence.

### Add your own rule

Create `rules/my-rule.md`:

```markdown
# My Rule

When [context], the assistant MUST [requirement].

Violations:
- [specific thing that counts as a violation]

Does NOT apply when:
- [context where this rule is irrelevant]
```

## Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `CRITIC_MODEL` | `opus` | Model for the critic (opus, sonnet, haiku) |

## Design decisions

- **Fail open** — if the critic errors out, the response goes through. Never blocks the user on infrastructure failures.
- **Loop protection** — yields after one block per turn (checks `stop_hook_active`). Claude Code also has a built-in cap of 8 consecutive blocks.
- **Skip trivial responses** — responses under 100 chars bypass the critic (confirmations, short answers).
- **No dependencies** — pure Node.js, no npm install needed.

## Requirements

- Claude Code CLI (`claude`) installed and authenticated
- Node.js >= 18
