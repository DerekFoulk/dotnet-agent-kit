# ADR-0070: Class each cited source by its publisher, in a generated page

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The kit has been public since 2026-11-06 (ADR-0031), so people who don't know its owner read its rules. On 2026-11-15 the owner asked the public docs to say "exactly who all of the Authoritative Sources are", and to explain "the layers and responsibilities of each source".

Each rule in `docs/standards/` has a `basis` (ADR-0063): `authority`, cited by URL, or `preference`, cited by the owner or an ADR. `docs/code-review.md` tells the reviewer how to tell them apart: "Microsoft, standards bodies and tool vendors are authorities. Practitioners such as Kent Beck, Martin Fowler, Robert C. Martin and William Durand are not, so a rule resting on them is a preference." Nothing lists who those sources are. On 2026-11-15 the rules cited 109 URLs on 14 hosts: learn.microsoft.com 78 times, github.com 10, and 12 other hosts once to 3 times each.

A host doesn't say who published a page. github.com serves Microsoft's `dotnet/runtime`, OWASP's ASVS standard and Deque's axe-core alike. web.archive.org serves an archived copy of Robert C. Martin's page. A hand-written list would drift as soon as a rule cites a new page (CRF-003). `docs/sources.md` is a different list: the books and blogs read once when a standard was written, whether or not a rule cites them.

## Options

### Option 1: Class by publisher in a data file, and generate the page from the rules' sources

`docs/authorities.yml` names each publisher, its class (`authority`, `practitioner` or `project`), what it covers, and the URL prefixes its pages start with. `tools/Build-AuthoritiesPage.ps1` reads every URL source of the rules in force or proposed and gives each one to the entry with the longest matching prefix. An archived copy is matched by its original URL. The script fills the generated block of the hand-written `docs/authorities.md`, as `Build-AgentRules.ps1` fills AGENTS.md's rule blocks (ADR-0065). Its `-Check` fails when a URL matches no entry, an entry matches no URL, an entry is incomplete, or the block is stale.

- **Trade-offs:** The page can't drift from the rules, and a new kind of source fails CI until someone says who published it. One more file to edit when a rule cites a new publisher. The page can also list each rule whose `basis` is `authority` but whose URLs are all practitioners' pages, which `docs/code-review.md` says is a preference.
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

Option 1: it names every publisher once, matches `docs/code-review.md`'s test for an authority, and fails CI before the page can go stale.

## Decision

Option 1, decided in auto mode (ADR-0035) on 2026-11-15, for the owner's request of the same day.

## Consequences

- New: `docs/authorities.yml`, `docs/authorities.md` (prose by hand, the block between `<!-- sources from docs/standards` and `<!-- end sources -->` generated), `tools/Build-AuthoritiesPage.ps1` and its tests, a "Sources page is current" step in `kit-checks.reusable.yml`, and a row in AGENTS.md's Commands table.
- When a rule cites a page from a new publisher, CI fails until `docs/authorities.yml` classes it; then run the script and commit the page.
- The classes follow `docs/code-review.md`: Microsoft and other vendors documenting their own product, and standards bodies (W3C, IETF, OWASP), are authorities; people, books and reference works such as Wikipedia are practitioners; a tool's own repo is a project page, an authority only for that tool.
- The rules whose `basis` is `authority` with only practitioners' URLs are listed on the page for review, not failed: `docs/standards/` is being edited by the rules cleanup, and each needs the owner's call (a preference, or an authority to cite). Making that list a gate is a follow-up once it's empty.
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
