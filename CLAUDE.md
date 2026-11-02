@AGENTS.md

## Claude Code notes

- **Rules:** `.claude/rules/` holds generated, path-scoped rule summaries. Each rule's full text, reason and sources are in `docs/standards/`.
- **Reviewer:** before opening a PR, run the `reviewer` subagent (`.claude/agents/reviewer.md`) on the branch. It hasn't seen your work, so it reviews with fresh eyes.
- **Permissions:** `.claude/settings.json` keeps only precise rules (ADR-0026). It denies reading secret files. It asks before merging a PR, editing repo settings, adding packages, installing tools, `git reset --hard`, `git clean`, and editing build, CI or agent config. Pushes aren't matched by text: GitHub's "main protection" ruleset guards `main`. If a rule blocks something legitimate, stop and ask the owner; don't rephrase around it.
- **Shell:** on Windows, run the kit's scripts with the PowerShell tool (`pwsh`).
- **Microsoft Learn MCP server:** `.mcp.json` configures it. Claude Code asks once per user before it connects a project server. Use it to check current Microsoft guidance before writing .NET code.
