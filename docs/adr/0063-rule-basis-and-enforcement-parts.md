# ADR-0063: Each rule records its basis, and its enforcement as gate or advisory parts

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

In the rules audit of 2026-11-12, the owner asked how to tell a hard rule from a preference, and how each is enforced. His policy: enforce the practices of authoritative sources, such as Microsoft, as hard rules; handle his personal preferences differently, unless he asks for one to be hard.

The rules couldn't say which was which:

- `layer` (floor, owner, outside) records whose call settles a conflict, not where a rule's substance comes from. At least 13 of the 68 owner-layer rules cite Microsoft or another authority.
- `enforcement` was one free-text string. 68 of the 94 rules mentioned "advisory" somewhere in it, and about 20 mixed a part a tool checks with a part only the reviewer checks.
- 12 rules were gated only by the kit's sample app, and advisory in an app until it copies the sample's tests. Nothing in the string said so in a form a tool could read.
- The scorecard counted any string that didn't start with "advisory" as checked by a tool, an upper bound nobody could narrow.

## Options

### Option 1: A `basis` field and enforcement as a list of parts

Every rule gets `basis: authority` (an outside source sets its substance, cited by URL) or `basis: preference` (the owner's own choice, cited by his words or an ADR). `enforcement` becomes a list of parts, each with `kind` (gate or advisory), `in` (kit, app or both) and `how`.

- **Trade-offs:** Each rule says plainly what stands behind it and where. `Test-RuleSources.ps1` can check the form and that a basis matches its sources. The scorecard counts gates from the parts. The YAML gets longer, and all 94 rules move at once.
- **Reversibility:** Easy. The parts' text is the old string split up, so they can be joined back.
- **Risk:** Low. A wrong `in` or `kind` is a review finding, and the source check catches the form.

### Option 2: Split each mixed rule into a gated rule and an advisory rule

- **Trade-offs:** Each rule has one strength. But about 20 rules would become 40 that state one idea twice, against CRF-003, and their ids would change in every reference.
- **Reversibility:** Hard. Every reference to a split rule moves.
- **Risk:** Medium. Two rules for one idea drift apart, which is what the audit was cleaning up.

### Option 3: Keep the string and add conventions

For example, "advisory in an app until" as a fixed phrase that a regular expression reads.

- **Trade-offs:** No migration. But the check would parse prose, which is the fragility that made the scorecard an upper bound.
- **Reversibility:** Easy.
- **Risk:** Medium. A new wording slips past the expression.

## Recommendation

Option 1: one rule per idea, with each part's strength and place stated in a form a tool reads.

## Decision

Accepted as recommended (owner, 2026-11-12: "Yes, start PR 1", after agreeing the scheme in the rules audit).

## Consequences

- `docs/standards/*.md`: every rule has `basis`, and its `enforcement` is a list of parts. Most parts keep the old string's text, split up. It adds the URL sources the audit found missing for rules whose basis is an authority (ARC-003, ARC-005, STY-001, STY-005, SUP-001, SUP-003, SUP-004, SUP-007, SEC-001), and replaces CRF-010's source, which said nothing about non-public members. CRF-010 becomes a preference: Microsoft's guidance covers .NET's own internals and still allows UnsafeAccessor, so the kit's wider ban is the owner's choice.
- Where the split changed what a rule claims, the change is deliberate and checked against the workflows:
  - ARC-005, GIT-004, GIT-005 and TST-001 gain gate parts in apps, because `app-checks.reusable.yml` runs the same checks there.
  - ARC-001, ARC-003, CRF-006, TST-003 and UI-001 gain advisory app parts: their gates run only on the kit's sample or fixture.
  - SUP-001's lock-file refresh is a helper, not a gate, and runs only in the kit; its macOS lock-file check is the gate in apps too.
  - SUP-005's gate covers the SDK pin only; its rollForward and prerelease settings are advisory, since nothing reads them.
  - TST-005 has no gate: the intake check belongs to TST-007.
  - DOD-001 names the checks an app's ruleset requires.
  - The commit-msg hook is early feedback, not a gate, because a commit can skip it; CI is the gate (GIT-004).
- Who counts as an authority: Microsoft, standards bodies (W3C, OWASP, OpenSSF, the IETF) and the vendors of the tools the kit uses. The practitioner sources in `docs/sources.md` (Beck, Fowler, Martin, Durand and others) inform rules the owner ratifies, so a rule resting on them is a preference.
- A floor rule (layer `floor`) is never overridden, whatever its basis: a broken floor rule is always Blocking, even when its basis is a preference.
- `tools/Test-RuleSources.ps1` requires `basis`. An authority rule needs a URL source, and a preference needs an owner or ADR source. Each enforcement part needs a known `kind`, at least one known place in `in`, and a `how`.
- `tools/Test-Scorecard.ps1` counts a rule as checked by a tool when any part is a gate, and as advisory when every part is.
- A gate that runs only in the kit (`in: [kit]`), beside an advisory part for apps, is how the 17 rules gated only by the sample or fixture now read. GAP-037 records closing that.
- The policy itself isn't checked by a tool: authorities gated where a tool can, preferences advisory unless the owner asks for a gate, and a broken advisory preference ranked Consider. The `reviewer` agent's step 4 checks it whenever a rule is added or changed.

## Pillars affected

Operational Excellence: each rule shows what enforces it and where, so a gap is visible instead of hidden in prose. Reliability: a gate a tool reads can be counted and checked.

## Sources

- owner, 2026-11-12
