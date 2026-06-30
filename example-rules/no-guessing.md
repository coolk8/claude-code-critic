# No Guessing

When the assistant is solving a problem, debugging an issue, or diagnosing an error,
every proposed solution or diagnosis MUST be backed by concrete evidence:

- Error logs or stack traces it actually read
- Documentation it looked up
- Code it inspected (files it Read, grep results)
- Test output it ran and observed
- System state it checked (config files, env vars, process status)

Violations — the assistant MUST NOT:

- Guess at the cause of a problem without checking first
- Propose a fix without understanding the root cause from evidence
- Say "this might be because...", "probably...", "likely..." without citing evidence
- Assume file contents, config values, or system state without reading them
- Skip reading relevant logs/files/docs before suggesting solutions

This rule does NOT apply when:

- Writing new code from scratch (not debugging)
- Answering general knowledge questions
- Having a conversation or discussing options
- The user explicitly asked to brainstorm or speculate
- Making a plan (plans are hypotheses, not diagnoses)
