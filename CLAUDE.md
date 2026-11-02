@AGENTS.md

## Claude Code notes

- **Rules:** `.claude/rules/` holds generated, path-scoped rule summaries. Each rule's full text, reason and sources are in `docs/standards/`.
- **Reviewer:** before opening a PR, run the `reviewer` subagent (`.claude/agents/reviewer.md`) on the branch. It hasn't seen your work, so it reviews with fresh eyes.
- **Permissions:** `.claude/settings.json` denies reading secret files and the common forms of force-pushing, pushing to `main` and skipping hooks. It asks before merging a PR, adding packages, installing tools, history-losing git commands, and changing CI or settings. These rules match command text, so they're best effort: other spellings of the same command can get through. GitHub rulesets on `main` (build step 4) are the real guard. Don't work around a block or a prompt; ask the owner.
- **Shell:** on Windows, run the kit's scripts with the PowerShell tool (`pwsh`).
- **Microsoft Learn MCP server:** `.mcp.json` configures it. Claude Code asks once per user before it connects a project server. Use it to check current Microsoft guidance before writing .NET code.
