# ADR-0018: Canon TDD with a test list

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner is "a true believer in TDD": he writes unit tests, and often other kinds of test, before the code, sees them fail, then writes code until they pass (owner, 2026-10-26). His description may mean writing many tests at once. Kent Beck's Canon TDD names converting the whole test list into tests before coding as a common mistake, because early design choices then force rework of later tests. Martin Fowler warns most against skipping the refactor step.

## Options

### Option 1: A test list in the plan, then one test at a time: red, green, refactor

- **Trade-offs:** Test-first everywhere, with design feedback from each test; an outer acceptance test may stay red while inner tests are worked through one by one.
- **Reversibility:** Easy.
- **Risk:** Low.

### Option 2: Write all the planned tests first, then the code

- **Trade-offs:** Every behavior is pinned before coding; early tests lock in design choices that later tests show were wrong.
- **Reversibility:** Easy.
- **Risk:** Medium. Rework of the test suite.

## Recommendation

Option 1: it keeps the owner's test-first rule and adds the list that makes it work.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- Plans include a test list (behaviors to cover).
- Each item becomes one failing test, committed as red; the passing change is committed as green; refactoring happens on green.
- A red commit must fail on an assertion, not on a missing type or a crash in the test itself.
- The test matrix (brief §6.7) sets which kinds of test each part of an app gets.

## Pillars affected

Reliability: every behavior has a test that was seen to fail. Operational Excellence: TDD evidence is visible in history.

## Sources

- owner, 2026-10-26
- https://newsletter.kentbeck.com/p/canon-tdd, retrieved 2026-11-01
- https://martinfowler.com/bliki/TestDrivenDevelopment.html, retrieved 2026-11-01
