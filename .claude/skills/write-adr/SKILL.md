---
name: write-adr
description: Record a significant technical decision as an Architecture Decision Record in docs/adr. Use when choosing between technologies, patterns or approaches, when adding a dependency or preview package, when deviating from a kit default, or when reversing an earlier decision.
---

# Write an ADR

1. **Copy the template.** Copy `docs/adr/0000-template.md` to `docs/adr/NNNN-short-title.md`, using the next free number. An app numbers its own ADRs from 0001; in the kit, decisions after the brief's D1–D25 continue from 0026.
2. **Fill every section.** The ADR sections check (`Test-AdrSections.ps1`, in AGENTS.md's Commands table) checks all of them:
   - **Status** (`Proposed` until the owner decides) and **Date** (YYYY-MM-DD).
   - **Context:** the problem and its constraints.
   - **Options:** at least two `###` options, each with **Trade-offs**, **Reversibility** and **Risk**. Record the rejected ones too.
   - **Recommendation:** your pick and a one-line reason. It's required even when the choice is the owner's.
   - **Decision:** left for the owner to fill in; set it only after he decides.
   - **Consequences:** new rules, checks, files, follow-up work, and what gets harder.
   - **Pillars affected:** Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency.
   - **Sources:** `owner, YYYY-MM-DD` or a URL with `retrieved YYYY-MM-DD`. Fetch every URL and check it says what you cite it for before you write "retrieved".
3. **Check it.** Run the ADR sections check, with the command from AGENTS.md's Commands table.
4. **Ask.** Put the decision to the owner with your recommendation. Explain any term he hasn't used.
5. **Record his answer.** Fill Decision, and set Status to `Accepted` or `Rejected`. If it supersedes an older ADR, set that ADR's Status to `Superseded by ADR-NNNN`.
