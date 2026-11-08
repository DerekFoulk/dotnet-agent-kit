# ADR-0034: Define a "perfect" app as a quality scorecard checked against the rules

- **Status:** Accepted
- **Date:** 2026-11-07

## Context

On 2026-11-06 the owner set the kit's goal: an app built with the kit should end up as close to a "perfect" .NET app as possible, measured against architecture, patterns, practices and conventions. The kit's rules are strong on hygiene, process and the supply chain, and weaker on design: proportion, API design, observability, mutation and accessibility tests, code scanning and delivery. That gap was described in chat only.

Each rule in `docs/standards/` already names its source and what enforces it (`tools/Test-RuleSources.ps1`). Nothing says which quality area a rule serves, which areas have no rules at all, or how much of each area a tool checks rather than an agent's instructions. Without that, the gaps stay a hope rather than a roadmap, and a new rule can be added without anyone seeing which area it fills.

## Options

### Option 1: A scorecard as data, checked against the rules

`docs/quality/scorecard.md` holds the areas in YAML front matter. Each area has what "perfect" means there, its sources, the rule IDs that cover it, and its gaps with a status. `tools/Test-Scorecard.ps1` fails when:
- an area names a rule that doesn't exist, or one that's retired;
- a rule in force has no area;
- an area has no source, or no rules and no gaps;
- a gap is malformed;
- the table of counts in the file no longer matches the rules.

`-Update` rewrites the table.

- **Trade-offs:** The scores come from the rules' own `enforcement` fields, so they can't drift. A new rule must say which area it serves. Each gap has an ID that a later PR can close. It costs a script and its tests, and one CI step. The counts measure rule coverage, not the quality of any one app.
- **Reversibility:** Easy. Removing it means deleting a file, the script and the CI step.
- **Risk:** Low. The script only reads, except with `-Update`.

### Option 2: A prose page only

- **Trade-offs:** Quick to write and easy to read. But nothing ties it to the rules: a new rule or a retired one leaves it silently wrong, which is the drift the kit's checks exist to prevent.
- **Reversibility:** Easy.
- **Risk:** Medium: it goes stale.

### Option 3: Adopt an outside scorecard, such as OpenSSF Scorecard

[OpenSSF Scorecard](https://github.com/ossf/scorecard) scores a repo's security practices: pinned dependencies, branch protection, code review, signed releases and similar.

- **Trade-offs:** It's maintained by others and well known. But it covers one area, the supply chain, and says nothing about architecture, tests, API design or proportion. Running it is a new GitHub Action, which needs the owner's OK.
- **Reversibility:** Easy.
- **Risk:** Low, but it measures the wrong thing for most of the goal.

## Recommendation

Option 1. The scorecard becomes reviewed, checked data, like the rules themselves. OpenSSF Scorecard is listed as a gap under "Supply chain and build", as a possible outside check for that one area.

## Decision

Accepted (owner, 2026-11-07: approved the scorecard plan, including the CI step).

## Consequences

- **The 14 areas:**
  - Architecture
  - Proportion
  - Code
  - Tests
  - Security
  - Reliability
  - Observability
  - API design
  - Performance
  - Supply chain and build
  - Delivery
  - Docs and decisions
  - UI and accessibility
  - Process, so that the git, communication and done rules have an area too
- **How a rule is counted:** a rule counts as "checked by a tool" when its `enforcement` starts with anything other than `advisory`. That holds even when the text adds that part of the rule is advisory, so the counts are an upper bound on what tools check.
- **The first score:** 40 rules in force; 21 checked by a tool and 19 advisory; 9 proposed; 18 open gaps. The table is in `docs/quality/scorecard.md`.
- **Areas with no rules:** Proportion and API design have none yet, only gaps.
- **Closing a gap:** each gap is closed by its own PR. That PR adds or changes rules and marks the gap `closed`. A gap that needs a package, a CI change or cost waits for the owner's OK. This PR closes none.
- **Keeping it current:** a rule in force fails CI until an area names it; a proposed one can wait. After changing a rule or the scorecard, run `./tools/Test-Scorecard.ps1 -Update` and commit the table.
- **Where it applies:** the scorecard stays in the kit and isn't exported to apps (ADR-0032). It measures the kit's rules, which apps already get.
- **Shared code:** `Get-SourceProblem` and `Test-Present` moved from `Test-RuleSources.ps1` into `KitFrontMatter.psm1`, so both checks validate sources the same way.
- **What it can't measure:** checks catch mechanical mistakes, not design. Design judgment stays with the reviewer agent and the owner, and the practice run will show how far that gets.

## Pillars affected

- **Operational Excellence:** the definition of quality is versioned and checked in CI, and each gap is a trackable item.
- **Reliability, Security and Performance Efficiency:** these are areas on the scorecard; this ADR changes no app behaviour, but it lists their gaps.
- **Cost Optimization:** one short CI step, and no new service.

## Sources

- owner, 2026-11-06
- owner, 2026-11-07
- https://github.com/ossf/scorecard, retrieved 2026-11-07
- https://learn.microsoft.com/en-us/azure/well-architected/, retrieved 2026-11-07
