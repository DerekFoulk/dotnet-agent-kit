# Spike: does the Copilot coding agent read `.claude/skills`? (D21, ADR-0021)

**Question:** the kit keeps one skills folder, `.claude/skills/`. Claude Code, Visual Studio and VS Code read it; does the GitHub Copilot coding agent too, or does the kit need a copy in `.github/skills/`?

**Date:** 2026-11-04.

## Docs

GitHub's docs say project skills are read from `.github/skills`, `.claude/skills` or `.agents/skills`: "create a `.github/skills`, `.claude/skills`, or `.agents/skills` directory in your repository". The December 2025 changelog adds that skills already set up for Claude Code in `.claude/skills` are picked up automatically. Copilot chooses a skill by matching the task against its description.

- [Adding agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills), retrieved 2026-11-04
- [GitHub Copilot now supports Agent Skills](https://github.blog/changelog/2025-12-18-github-copilot-now-supports-agent-skills/), retrieved 2026-11-04

## Live run

Issue #7 asked the coding agent, with no file changes, to list the repository skills it had (name and folder) and to use `write-adr` to say what an ADR's Options section must contain. It opened draft PR #8 (closed unmerged afterwards):

- It listed all six skills, each at `.claude/skills/<name>/SKILL.md`: `address-review`, `finish-work`, `plan-checklist`, `start-work`, `tdd-cycle`, `write-adr`.
- It quoted the `write-adr` skill word for word: "at least two `###` options, each with **Trade-offs**, **Reversibility** and **Risk**. Record the rejected ones too." (line 12 of `.claude/skills/write-adr/SKILL.md`).
- It also filled in the kit's PR template, from `.github/pull_request_template.md`.

**Caveat:** the agent can read any repo file, so the run shows the skills were visible and used, not which mechanism loaded them; the docs above cover that.

## Conclusion

Keep the one `.claude/skills/` folder (ADR-0021). No copy in `.github/skills/` is needed.
