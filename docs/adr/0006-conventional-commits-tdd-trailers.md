# ADR-0006: Conventional Commits with TDD trailers

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner never stated a commit-message format; his most mature repo uses plain sentences with "(red)"/"(green)" markers. Automatic versioning (ADR-0019) needs commit messages that say whether a change is a fix, a feature or a breaking change, and the red→green order check needs to find the red and green commits.

## Options

### Option 1: Conventional Commits, with red/green as a `TDD:` trailer

- **Trade-offs:** `fix:`/`feat:`/`!` drive the version; the subject stays clean for release-please; git reads trailers directly (`git log --format='%(trailers:key=TDD,valueonly)'`). The marker isn't visible in a one-line log.
- **Reversibility:** Easy for future commits; existing history keeps its format.
- **Risk:** Low.

### Option 2: Conventional Commits, with "(red)"/"(green)" at the end of the subject

- **Trade-offs:** Visible in one-line logs, and matches the owner's earlier history; release-please copies the marker into the changelog, and a parser must strip it from free text.
- **Reversibility:** Easy.
- **Risk:** Low to medium. Parsing markers out of free text is less reliable.

### Option 3: Plain sentences, no format

- **Trade-offs:** No rules to learn; but nothing can derive versions or check red→green order.
- **Reversibility:** Easy.
- **Risk:** High for ADR-0019, which depends on typed commits.

## Recommendation

Option 1: one checkable format feeds versioning, and trailers make the red→green check exact.

## Decision

Conventional Commits accepted (owner, 2026-11-01). Trailer format chosen by the owner on 2026-11-01, when step 2 needed it.

## Consequences

- Commit subjects follow Conventional Commits (`feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`; `!` or `BREAKING CHANGE` for a major change).
- A test-first commit ends with `TDD: red`; the commit that makes it pass ends with `TDD: green`. The line goes in the message's final paragraph, together with any other trailers such as `Co-Authored-By:`, because git only reads the last paragraph as trailers.
- The red→green check accepts a `TDD: red|green` line anywhere in the message body, so commits made before this was noticed (build steps 1 and 2, where the marker sat in its own paragraph) still count.
- PR titles are Conventional Commits too, because the merge commit message is the PR title (ADR-0022).
- CI checks the format and the red→green order (build step 4).

## Pillars affected

Operational Excellence: history is machine-readable, so versions and TDD evidence come from tools, not memory.

## Sources

- owner, 2026-11-01
- https://www.conventionalcommits.org/en/v1.0.0/, retrieved 2026-11-01
- https://git-scm.com/docs/git-interpret-trailers, retrieved 2026-11-01
