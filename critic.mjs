#!/usr/bin/env node

// Claude Code Stop hook: critic-in-the-loop
// Installed globally. Reads rules from each project's .claude/critic-rules/.
// No rules in a project = no check. Uses `claude -p` — no API key needed.

import { readFileSync, readdirSync, appendFileSync } from 'fs';
import { join, basename } from 'path';
import { execSync } from 'child_process';
import { homedir } from 'os';

const LOG_FILE = join(homedir(), '.claude', 'critic.log');

async function main() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  const input = JSON.parse(Buffer.concat(chunks).toString());

  // Guard against infinite loops — yield if we already blocked once
  if (input.stop_hook_active) {
    process.exit(0);
  }

  const { assistant_message, tool_uses } = input;

  // Skip trivial responses (short answers, greetings, confirmations)
  if (!assistant_message || assistant_message.trim().length < 100) {
    process.exit(0);
  }

  // Load rules from the project's .claude/critic-rules/ directory
  const rulesDir = join(input.cwd, '.claude', 'critic-rules');
  let ruleFiles;
  try {
    ruleFiles = readdirSync(rulesDir).filter(f => f.endsWith('.md'));
  } catch {
    process.exit(0); // No critic-rules in this project — skip
  }

  if (ruleFiles.length === 0) {
    process.exit(0);
  }

  const rules = ruleFiles.map(f => ({
    name: f.replace('.md', ''),
    content: readFileSync(join(rulesDir, f), 'utf-8').trim()
  }));

  // Summarize tool usage for context
  const toolsSummary = tool_uses?.length
    ? tool_uses.map(t => `- ${t.tool_name}(${Object.keys(t.tool_input || {}).join(', ')})`).join('\n')
    : 'No tools used';

  // Build critic prompt
  const rulesBlock = rules.map((r, i) => `### Rule ${i + 1}: ${r.name}\n${r.content}`).join('\n\n');

  const criticPrompt = `You are a strict critic. Check if the assistant's response violates any rules.

## Rules
${rulesBlock}

## Assistant's Response
${assistant_message}

## Tools the Assistant Used
${toolsSummary}

## Your Task
1. For each rule, decide if it applies to this response. Many rules only apply in specific contexts (e.g., debugging) — skip rules that don't apply.
2. If a rule applies AND is clearly violated, explain the specific violation.
3. Be strict but fair — only flag clear violations, not edge cases.

Respond with ONLY valid JSON, nothing else:
- Approved: {"ok": true}
- Violated: {"ok": false, "reason": "Rule [name]: [what was violated and what the assistant should do instead]"}`;

  const model = process.env.CRITIC_MODEL || 'opus';

  try {
    const result = execSync(
      `claude -p --model ${model} --no-session-persistence`,
      {
        input: criticPrompt,
        encoding: 'utf-8',
        timeout: 120_000, // 2 minutes max
        stdio: ['pipe', 'pipe', 'pipe']
      }
    ).trim();

    // Extract JSON from response
    const jsonMatch = result.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      process.exit(0);
    }

    const verdict = JSON.parse(jsonMatch[0]);

    if (verdict.ok === false && verdict.reason) {
      const reason = `[CRITIC] ${verdict.reason}`;
      const project = basename(input.cwd);
      const preview = assistant_message.slice(0, 200).replace(/\n/g, ' ');
      const logLine = `[${new Date().toISOString()}] BLOCKED | ${project} | ${reason}\n  Response preview: ${preview}...\n\n`;
      try { appendFileSync(LOG_FILE, logLine); } catch {}
      process.stderr.write('\x07');
      process.stdout.write(JSON.stringify({ decision: 'block', reason }));
    }

    process.exit(0);
  } catch (err) {
    const logLine = `[${new Date().toISOString()}] ERROR | ${err.message}\n\n`;
    try { appendFileSync(LOG_FILE, logLine); } catch {}
    process.exit(0);
  }
}

main();
