# claude-code-critic

Critic-in-the-loop hook for Claude Code. A second AI reviews every response against your project rules **before it reaches you**. Violations get sent back for revision automatically.

Installed once globally. Rules are per-project. No rules in a project = no check.

Uses `claude -p` (Claude Code CLI) — no API key needed, runs on your existing subscription.

## How it works

```
Claude writes response
       ↓
  Stop hook fires (global)
       ↓
  critic.mjs checks {project}/.claude/critic-rules/
       ↓
  No rules? → skip, response goes through
  Rules found? → call `claude -p --model opus` with critic prompt
       ↓
  Critic returns {"ok": true} or {"ok": false, "reason": "..."}
       ↓
  ok=true  → response reaches you
  ok=false → Claude gets the reason and keeps working
```

## Install

```bash
git clone https://github.com/coolk8/claude-code-critic
cd claude-code-critic
chmod +x install.sh
./install.sh
```

This adds a `Stop` hook to your global `~/.claude/settings.json`.

## Add rules to a project

```bash
mkdir -p /path/to/project/.claude/critic-rules
cp example-rules/no-guessing.md /path/to/project/.claude/critic-rules/
```

Each `.md` file in `.claude/critic-rules/` is a rule. Add as many as you need per project.

## Example rule: no-guessing

> When solving a problem, every diagnosis must be backed by logs, docs, or code inspection. No speculating without evidence.

See `example-rules/no-guessing.md` for the full rule.

## Write your own rule

Create `.claude/critic-rules/my-rule.md` in your project:

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

- **Global hook, per-project rules** — install once, configure per project
- **Fail open** — if the critic errors, the response goes through
- **Loop protection** — yields if `stop_hook_active` is true (already blocked once this turn)
- **Skip trivial responses** — responses under 100 chars bypass the critic
- **No dependencies** — pure Node.js 18+, no npm install

## Requirements

- Claude Code CLI (`claude`) installed and authenticated
- Node.js >= 18
