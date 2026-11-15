# ADR-0070: Class each cited source by its publisher, in a generated page

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The kit has been public since 2026-11-06 (ADR-0031), so people who don't know its owner read its rules. On 2026-11-15 the owner asked the public docs to say "exactly who all of the Authoritative Sources are", and to explain "the layers and responsibilities of each source".

Each rule in `docs/standards/` has a `basis` (ADR-0063): `authority`, cited by URL, or `preference`, cited by the owner or an ADR. ADR-0063 already decides who counts as an authority: "Microsoft, standards bodies (W3C, OWASP, OpenSSF, the IETF) and the vendors of the tools the kit uses", while a rule resting on a practitioner is a preference; `docs/code-review.md` gives the reviewer the same test. This ADR doesn't change that: it decides how a cited URL is mapped to its publisher, and so to one side of that line. Nothing lists who those publishers are, and no tool checks that an `authority` rule cites one (ADR-0063: "the policy itself isn't checked by a tool"). On 2026-11-15 the rules cited 109 URLs on 14 hosts: learn.microsoft.com 78 times, github.com 10, and 12 other hosts once to 3 times each.

A host doesn't say who published a page. github.com serves Microsoft's `dotnet/runtime`, OWASP's ASVS standard and Deque's axe-core alike. web.archive.org serves an archived copy of Robert C. Martin's page. A hand-written list would drift as soon as a rule cites a new page (CRF-003). `docs/sources.md` is a different list: the books and blogs read once when a standard was written, whether or not a rule cites them.

## Options

### Option 1: Class by publisher in a data file, and generate the page from the rules' sources

`docs/authorities.yml` names each publisher, its class (`authority`, `practitioner` or `project`), what it covers, and the URL prefixes its pages start with. `tools/Build-AuthoritiesPage.ps1` reads every URL source of the rules in force or proposed and gives each one to the entry with the longest matching prefix. An archived copy is matched by its original URL. The script fills the generated block of the hand-written `docs/authorities.md`, as `Build-AgentRules.ps1` fills AGENTS.md's rule blocks (ADR-0065). Its `-Check` fails when a URL matches no entry, an entry matches no URL, an entry is incomplete, or the block is stale.

- **Trade-offs:** The page can't drift from the rules, and a new kind of source fails CI until someone says who published it. One more file to edit when a rule cites a new publisher. With each URL classed, the check can also fail an `authority` rule none of whose URLs is an authority's, which ADR-0063 says is a preference; no rule does that today.
- **Reversibility:** Easy: one data file, one script, one CI step.
- **Risk:** Low. A prefix that's too broad could class a page wrongly; the longest prefix wins, so a narrower entry such as `https://github.com/OWASP/` overrides a broader one.

### Option 2: Class by host only

- **Trade-offs:** Simplest: one line per host. But github.com and web.archive.org can't be classed at all, and they carry 12 of the 109 citations, including a Microsoft authority and an OWASP standard.
- **Reversibility:** Easy.
- **Risk:** High that the page is wrong for exactly the sources a reader would ask about.

### Option 3: A class on each source in `docs/standards/`

Each source string gains its class, such as `"<URL>, retrieved <date>, authority: Microsoft"`.

- **Trade-offs:** The class sits next to the citation. But it repeats the same publisher on 78 Learn links (CRF-003), changes the source format `Test-RuleSources.ps1` and `Test-Scorecard.ps1` parse, and touches every standard while the rules cleanup is editing them.
- **Reversibility:** Hard: every source changes format.
- **Risk:** Medium: 109 edits, each a chance of a typo the check must then catch.

## Recommendation

Option 1: it names every publisher once, applies ADR-0063's test for an authority to every cited URL, and fails CI before the page can go stale.

## Decision

Option 1, decided in auto mode (ADR-0035) on 2026-11-15, for the owner's request of the same day.

## Consequences

- New: `docs/authorities.yml`, `docs/authorities.md` (prose by hand, the block between `<!-- sources from docs/standards` and `<!-- end sources -->` generated), `tools/Build-AuthoritiesPage.ps1` and its tests, a "Sources page is current" step in `kit-checks.reusable.yml`, and a row in AGENTS.md's Commands table.
- When a rule cites a page from a new publisher, CI fails until `docs/authorities.yml` classes it; then run the script and commit the page.
- Three classes, on ADR-0063's line: `authority` (Microsoft and other vendors documenting their own product, and standards bodies: W3C, IETF, OWASP); `project` (a tool's own repo or docs, from the vendor of a tool the kit uses: ADR-0063 counts it as an authority, for that tool only, so the page lists it apart); and `practitioner` (people, books, and reference works such as Wikipedia, whose pages the rules cite for a practitioner's principle).
- An entry is matched by URL prefix, so one host can hold several publishers (github.com: Microsoft's `dotnet/`, OWASP's `OWASP/`, Deque's `dequelabs/`). A Microsoft Learn URL's locale segment (`/en-us/`) and any `#fragment` are dropped before pages are compared, so one page cited two ways is listed once.
- A new gate: an `authority` rule must cite at least one URL classed `authority` or `project`. On 2026-11-15 every one does; the three that also cite practitioners (CRF-003, CRF-005, OPS-004) each cite Microsoft Learn as well.
- `docs/sources.md` stays a separate list: the books and blogs read when a standard was written, cited by a rule or not. `docs/authorities.yml` names only publishers the rules cite, so some practitioners appear in both, for different reasons.
- Every edit to `docs/standards/` that cites a new publisher now needs `docs/authorities.yml` too. The ruleset doesn't require a branch to be up to date with `main`, so two PRs can each pass while `main` fails after both merge; merge `main` into the branch and rerun the check before merging.
- Kit only: `Export-KitApp` copies a fixed list of tools, so apps don't get the script, the data or the page.
- Gets harder: a citation from a new publisher is two edits, the rule and the data file.

## Pillars affected

- **Reliability:** the check fails closed, so a source can't be left off the page.
- **Security:** none: the script reads files in the repo, with no network.
- **Cost Optimization:** none: a few seconds in the kit's existing CI job.
- **Operational Excellence:** a reader can see where every rule comes from, and which rules rest on a person's view rather than an authority.
- **Performance Efficiency:** none.

## Sources

- owner, 2026-11-15
- ADR-0063
- ADR-0065
