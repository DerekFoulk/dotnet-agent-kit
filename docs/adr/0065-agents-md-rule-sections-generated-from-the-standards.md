# ADR-0065: AGENTS.md's rule sections are generated from the standards

- **Status:** Accepted
- **Date:** 2026-11-13

## Context

AGENTS.md is the file every agent reads first, and `.github/copilot-instructions.md` is a generated copy of it (ADR-0064). Three of its sections restated rules by hand, and nothing checked them (rules audit, 2026-11-12):

- **Git** copied GIT-001 to GIT-005. It had drifted: it named six Conventional Commit types, while GIT-004 allows eleven.
- **Done means** copied DOD-001 to DOD-006, in AGENTS.md and in the app template. It had drifted: it left out DOD-002 (evidence, "not verified").
- **Also ask in review mode** copied SEC-003's review-mode part.

CRF-003 asks that each fact have one source, and that every other place that states it be generated from it, checked against it, or point to it. `Build-AgentRules.ps1` already generates `.claude/rules` and `.github/instructions` from the standards.

## Options

### Option 1: Generate the copies from the standards

A marked block in AGENTS.md names a standard; `Build-AgentRules.ps1` fills it with that standard's rules in force, one line each (ID and statement), as it writes `.claude/rules`. `-Check` fails CI when a block is stale.

- **Trade-offs:** The copies can't drift, and a new rule appears in AGENTS.md as soon as it's accepted. The sections read as rule statements rather than conversational bullets; how-to text that isn't a rule (the commit-trailer example, checking a PR is still open) stays hand-written beside the block.
- **Reversibility:** Easy: delete the markers and write the text by hand again.
- **Risk:** Low. The generator refuses an unknown standard or an unclosed block before writing anything.

### Option 2: Check the hand-written copies

Keep the prose, and add drift tests (like `RuleDrift.Tests.ps1`) requiring each item.

- **Trade-offs:** The prose stays. Each test names items by hand, so a new rule needs a new test line, and wording can still say something subtly different.
- **Reversibility:** Easy.
- **Risk:** Medium: the tests guard the items someone thought to list.

### Option 3: Point to the standards

Replace the sections with "see `docs/standards/git.md`".

- **Trade-offs:** No copy at all. But AGENTS.md is what every agent loads; Claude Code loads `.claude/rules` by path, and Copilot reads AGENTS.md's copy, so a pointer leaves the rules out of the always-loaded context.
- **Reversibility:** Easy.
- **Risk:** Medium: agents follow what's in front of them.

## Recommendation

Option 1 for Git and Done means: they're lists of whole rules, so the rules themselves are the best text. Option 2 for "Also ask in review mode": SEC-003 is one sentence, which a generated list wouldn't read well from, so a drift test checks each item against it.

## Decision

Accepted as recommended (owner, 2026-11-13: "Yes, build it").

## Consequences

- `Build-AgentRules.ps1` fills each `<!-- rules from docs/standards/<file>.md ... -->` block, up to `<!-- end rules -->`, in AGENTS.md and `templates/app/AGENTS.md`, with that standard's accepted rules; `copilot-instructions.md` copies the filled AGENTS.md. Apps get `docs/standards/`, so an app's own run fills its blocks the same way.
- AGENTS.md's Git section now shows all five GIT rules, GIT-004's full list of types among them; Done means shows all six DOD rules, DOD-002 among them.
- `RuleDrift.Tests.ps1` checks the review-mode ask list against SEC-003's review part; `AgentConfig.Tests.ps1` keeps the blocks in place.
- AGENTS.md's "Generated files" note names the blocks.

## Pillars affected

Operational Excellence: the instructions agents read can't drift from the rules CI enforces. The other pillars aren't affected.

## Sources

- owner, 2026-11-12 (the rules audit's decisions)
- owner, 2026-11-13
- ADR-0064
