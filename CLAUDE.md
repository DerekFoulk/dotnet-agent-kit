@AGENTS.md

## Claude Code notes

- **Rules:** `.claude/rules/` holds generated, path-scoped rule summaries. Each rule's full text, reason and sources are in `docs/standards/`.
- **Reviewer:** before opening a PR, run the `reviewer` subagent (`.claude/agents/reviewer.md`) on the branch. It hasn't seen your work, so it reviews with fresh eyes.
- **Permissions:** `.claude/settings.json` blocks reading secret files, force-pushing and pushing to `main`. It asks before merging a PR, adding packages, and changing CI or settings. Don't work around a block or a prompt; ask the owner.
- **Shell:** on Windows, run the kit's scripts with the PowerShell tool (`pwsh`).
- **Microsoft Learn MCP server:** `.mcp.json` configures it. Claude Code asks once per user before it connects a project server. Use it to check current Microsoft guidance before writing .NET code.
