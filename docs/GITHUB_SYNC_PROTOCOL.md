# GitHub synchronization protocol

## Roles

- **Implementation agent:** changes and tests the game, then writes `AGENT_STAGE_REPORT.md`.
- **User:** pastes the report's `CODEX_SYNC_BRIEF` into Codex and approves any publication.
- **Codex / GitHub maintainer:** inspects the actual worktree, updates portfolio-facing GitHub documentation, and commits or pushes only to the user's confirmed remote.

## One stage at a time

1. Finish a player-visible stage and validate it.
2. Replace `AGENT_STAGE_REPORT.md` using its template.
3. Update `PROJECT_STATUS.md` only when the public player-facing milestone or a major risk changed.
4. Return the `CODEX_SYNC_BRIEF` to the user.
5. The user sends that brief to Codex. Codex checks the report against the worktree before documenting or publishing it.

## Publishing guardrails

- A report is not a request to publish automatically.
- Never include GitHub tokens, SSH keys, passwords, or personal information in the report.
- Commit and push only after the destination is confirmed to be the user's GitHub remote and the user explicitly requests it.
- Keep commits small and descriptive; prefer one completed stage per commit when practical.
