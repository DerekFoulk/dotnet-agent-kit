## What and why

<!-- One or two sentences: what this changes and why. Link the plan, issue or ADR. -->

## Red → green evidence

<!-- One row per test-list item. Commits from `git log --format='%h %s | %(trailers:key=TDD,valueonly)' main..HEAD`. -->

| # | Red commit (failing on an assertion) | Green commit |
|---|---|---|
| 1 | `abc1234` what the test specifies: N failing | `def5678` N/N |

## Checks run

<!-- Paste the result of each. Write "not verified" for anything you didn't run. -->

<!-- Every command in AGENTS.md's Commands table, with this repo's paths: one line each. -->

- [ ] Build: zero warnings
- [ ] Every test suite: all pass (with the coverage gate, where the table has one)
- [ ] Every check in the table: exit 0 (generated files current, ADR sections, and the rest)
- [ ] Independent review by the `reviewer` agent: findings fixed or answered below

## For the owner

<!-- Decisions to make (each with a recommendation and a reason), `proposed` rules to ratify, dependencies or settings that need your OK. Write "None" if there's nothing. -->

## Not verified

<!-- Anything you couldn't check, and why. Write "Nothing" only if that's true. -->
