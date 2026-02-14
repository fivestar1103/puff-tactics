# Puff Tactics — Ralph Loop Prompt

You are building **Puff Tactics**, a tactical feed game for iOS in Godot 4 with GDScript.

## Your Task

1. Read `ralph/prd.json` and find the highest-priority story where `passes` is `false` and all `dependsOn` stories have `passes: true`.
2. Read `AGENTS.md` for patterns and gotchas discovered in previous iterations.
3. Read `progress.txt` to understand what has been completed so far.
4. Read `CLAUDE.md` for project conventions and architecture.
5. Implement that single story. Make it work. Follow the acceptance criteria exactly.
6. After implementing, verify all acceptance criteria are met.
7. Stage and commit your changes with message: `feat(US-XXX): <story title>`
8. Update `ralph/prd.json`: set the story's `passes` to `true` and add any notes.
9. Append a summary of what you did to `progress.txt`.
10. If you discovered any patterns, gotchas, or conventions, update `AGENTS.md`.
11. If ALL stories in prd.json have `passes: true`, output exactly: `<promise>COMPLETE</promise>`

## Rules

- ONE story per iteration. Do not work on multiple stories.
- Do NOT skip stories. Respect the `dependsOn` chain.
- Follow GDScript conventions in CLAUDE.md (snake_case, type hints, signals).
- Keep changes atomic. Only touch files relevant to your story.
- If a story is blocked or impossible, set its `notes` field explaining why, leave `passes` as `false`, and move to the next eligible story.
- Do NOT modify stories you are not working on (except reading their pass status for dependency checks).
