---
name: start-work
description: Start any task that will change files in this repo. Sets up the branch, reads the rules that apply, and writes the plan with its test list for the owner to approve. Use before editing code, scripts, standards or docs.
---

# Start work

1. **Understand the ask.** If the requirement is vague, ask questions first. Each question carries your recommended answer and a one-line reason. Don't invent requirements, features or UI.
2. **Sync and branch.** Run `git switch main` and `git pull --ff-only`, then create one short-lived branch for this task: `git switch -c <type>/<short-name>`.
3. **Read what applies.** Read `AGENTS.md`, the standards in `docs/standards/` for the paths you'll touch, and any ADR in `docs/adr/` that covers the area. For .NET or Azure work, check current Microsoft guidance with the Microsoft Learn MCP server.
4. **Write the plan.** Include:
   - the goal and the approach;
   - the files you'll touch;
   - a **test list**: the behaviors to cover, one line each, not yet written as tests;
   - the plan checklist (run the `plan-checklist` skill);
   - the ADRs needed (`write-adr`) and anything that needs the owner's OK (see "Ask before" in `AGENTS.md`).
5. **Get approval.** Show the owner the plan, unless the task is trivial (for example, a typo). Restate any answers he gives as a table.
6. **Start the first red test** with the `tdd-cycle` skill.
