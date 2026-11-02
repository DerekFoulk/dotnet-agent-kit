# ADR-0017: Connectors (MCP servers) policy

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

MCP servers (connectors) give agents tools such as documentation lookup, GitHub access or a browser. They can help agents use current guidance when they write code, but each one adds an outside dependency, and anything it returns could carry instructions. Tools read repo-level MCP config from different files: Claude Code and Visual Studio read `.mcp.json`; VS Code reads `.vscode/mcp.json`; the Copilot coding agent is configured in the repo's GitHub settings.

## Options

### Option 1: A small vetted set, checked into each repo, added only with the owner's approval

- **Trade-offs:** Every session and tool gets the same connectors; the Microsoft Learn server (Microsoft-hosted, free, no sign-in) is in every repo; others are optional or per profile. Adding one is an "ask first" change.
- **Reversibility:** Easy. Remove an entry.
- **Risk:** Low, given first-party servers, no tokens in the repo, and connector output treated as data.

### Option 2: No connectors

- **Trade-offs:** No outside dependencies; agents work from training data, which drifts from current Microsoft guidance.
- **Reversibility:** Easy.
- **Risk:** Medium. Outdated guidance reaches code.

### Option 3: Each user adds whatever connectors they like

- **Trade-offs:** Flexible; sessions differ, and unvetted servers get access to the repo.
- **Reversibility:** Easy.
- **Risk:** High.

## Recommendation

Option 1: current guidance at the moment code is written, with a short, reasoned allowlist.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- Core: the Microsoft Learn MCP server in `.mcp.json` and `.vscode/mcp.json` (build step 3). GitHub and Playwright servers are optional; Bicep and Azure servers only in the hosting profile, with Azure read-only by default.
- Product connectors (for example Microsoft Clarity, Adobe) are per project only.
- A connector catalog and a start-up step that recommends connectors for approval come after v0.1.

## Pillars affected

Security: an allowlist and no secrets in the repo. Operational Excellence: the same tools in every session.

## Sources

- owner, 2026-11-01
- https://learn.microsoft.com/visualstudio/ide/mcp-servers, retrieved 2026-11-01
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/extend-coding-agent-with-mcp, retrieved 2026-11-01
