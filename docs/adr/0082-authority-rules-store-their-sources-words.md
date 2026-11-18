# ADR-0082: An authority rule says only what its page says, and stores the page's words

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

On 2026-11-17 the owner found that rules labeled `basis: authority` claimed more than their sources said: "I don't want made-up rules to be cited as 'authority'. 'Authority' must be properly sourced." He also asked for rulesets per project type (ADR-0084): "Source everything and make different rulesets to cover all of the supported project types. Have one that holds rules for all project types." And: "Is this not 90% of what this 'kit' is supposed to be? We have to get this right and not mess it up in the future."

Three things let it happen:

- `Test-RuleSources.ps1` and `Build-AuthoritiesPage.ps1` checked that an authority rule cites a URL, and that the URL is an authority's page. Nothing compared the rule's words with the page's.
- `basis` covered a whole rule. A rule that mixed Microsoft's advice with a kit tightening or an owner decision was labeled authority in full. 60 of the 61 authority rules also cited `owner, ...` or an ADR.
- The kit's sample is a web API, so web assumptions reached general rules. DAT-002 required EF Core for every relational database, but .NET MAUI's local-database docs use sqlite-net-pcl. DAT-005 banned SQLite in tests outright, while EF Core allows a SQLite in-memory fake and ASP.NET Core recommends one for integration tests. Every rule had `scope: core`, which nothing read.

## Options

### Option 1: Each authority rule stores the supporting sentence, and the checks hold it to the page

Each rule in `docs/standards/` gains `quotes`: for each cited page, the page's own words (`text`), with the page (`source`) and the day read (`retrieved`).

- **Shape:** the source and date must equal one of the rule's URL sources, so they live once in `sources` and the quote is checked against them (CRF-003). An authority rule cites pages only, and quotes every page it cites.
- **Splits:** an owner's decision or a kit tightening is a preference rule of its own, with `layer: owner`. The owner's acceptance of an authority rule is recorded in `ratified`, not in its sources.
- **Project types:** every rule names its `projectTypes` (ADR-0084), replacing `scope`.
- **Checks:** `Test-RuleSources.ps1` checks all of this offline, in CI. `Test-RuleQuotes.ps1` re-reads the pages (ADR-0083). The reviewer compares every new or changed rule with its quotes (`docs/code-review.md`).
- **Trade-offs:** about 800 quotes to keep current, and a quote copied wrong is caught only by the re-read. In return, a reader sees the evidence beside the rule, and a rule worded beyond its quote stands out.
- **Reversibility:** easy. The fields can be dropped and the checks relaxed.
- **Risk:** low. Pages change, so quotes go stale; ADR-0083 finds them.

### Option 2: Keep the URL citation and have the reviewer read each page

No new fields. The reviewer opens each cited page when a rule changes.

- **Trade-offs:** nothing stored and nothing to keep current. But nothing records what the page said when the rule was written, a rule that never changes is never re-read, and a mixed rule still looks authoritative.
- **Reversibility:** easy.
- **Risk:** high. This is how the mislabels happened.

### Option 3: Drop basis, and label every rule the kit's own

- **Trade-offs:** simple and honest about ownership, but the owner's order is "the floor, the owner, then outside authorities" (AGENTS.md). He wants to know which rules are Microsoft's, and a kit user's preferences override the kit's preferences, not the floor.
- **Reversibility:** hard. The source of each rule would be lost.
- **Risk:** medium.

## Recommendation

Option 1. It's the only option that keeps a rule and its evidence together and lets a machine hold them to each other, and it keeps the three layers the owner set.

## Decision

Option 1. The schema, as `Test-RuleSources.ps1` enforces it:

- **`basis: authority`** has `layer: outside` or `floor`, cites URLs only, and has at least one quote from each page it cites. An accepted one names who accepted it in `ratified` (`owner, YYYY-MM-DD` or `ADR-NNNN`).
- **`basis: preference`** has `layer: owner` or `floor` and cites the owner or an ADR. It may cite pages and quote them too.
- **A quote** is `{ source, retrieved, text }`. `source` and `retrieved` match a URL source of the rule, written without `, retrieved`. `text` is one contiguous passage, as the page renders it: plain text, link text kept, no markdown. It has no ellipsis standing for left-out words, so another passage is another quote; dots in the page's own code, as in `Task.Run(...)`, stay. It is the shortest passage that supports the rule, usually one sentence.
- **Strength:** the rule says what the quote says, no stronger and no weaker. DO and must are the imperative; DON'T and never stay "never"; we recommend and should become "prefer", "is recommended" or "should"; CONSIDER becomes "consider"; AVOID becomes "avoid". A page that only allows, supports or shows an example gives no rule.
- **Versions:** a versioned page is cited at the version the kit uses (`?view=aspnetcore-10.0`), and its .NET 10 text is quoted.
- **`projectTypes`** is required on every rule in force: `[all]`, or ids from `docs/standards/project-types.yml`, never every id (a type added later would be left out). `scope` is retired.
- **Splits:** when a mixed rule splits, the original id stays with the half that existing references and gates mean, which is usually the kit's stricter half. Enforcement parts move with the wording they check. Both halves keep the original's status, so nothing becomes accepted that the owner hadn't accepted.
- **Retired rules** need neither quotes nor project types.

**Quoted text and its licenses.** Most quotes come from Microsoft Learn. Its docs repos are CC BY 4.0, checked on GitHub on 2026-11-17 for dotnet/docs, dotnet/AspNetCore.Docs, dotnet/EntityFramework.Docs and MicrosoftDocs/windows-dev-docs. Others come from OWASP's Cheat Sheet Series (CC BY-SA 4.0, checked the same day), the W3C, IETF RFCs, GitHub Docs and a few tool vendors. Each is a short, verbatim, attributed passage: the rule names the page and the date read, and nothing is changed. `THIRD-PARTY-NOTICES.md` records this. Whether every cited publisher's terms allow such quotation was not verified page by page.

## Consequences

- The re-sourcing pass that came with this ADR applied it to all 120 rules: some matched their page as written, some were reworded to the page's strength, some split into an authority rule and a kit preference, and some were downgraded to preference. It also added proposed rules from Microsoft Learn's guidance pages for each project type (ADR-0085 to ADR-0095, `docs/inventory/`). The PR that made the pass gives the counts and each rule's before and after.
- About 800 quotes now need to stay current: ADR-0083.
- A rule proposed by an agent still needs the owner's acceptance; nothing in this pass changed a proposed rule to accepted.
- **Later:** a kit user's own preferences override the kit's preference rules, never the floor. That's the next step, planned separately (the owner's example: his rule of ten, CRF-012, over CRF-011's limits).

## Pillars affected

- **Operational excellence:** the rules an agent follows are traceable to their exact source; a stale one is found by a scheduled job.
- **Security:** the floor and the security authorities are quoted, so a weakened security rule shows.
- **Reliability, cost, performance:** n/a; offline checks only.

## Sources

- owner, 2026-11-17
- ADR-0063
- ADR-0073
- https://github.com/dotnet/docs/blob/main/LICENSE, retrieved 2026-11-17
- https://github.com/OWASP/CheatSheetSeries/blob/master/LICENSE.md, retrieved 2026-11-17
