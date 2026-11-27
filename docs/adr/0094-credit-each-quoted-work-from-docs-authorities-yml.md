# ADR-0094: Credit each quoted work in THIRD-PARTY-NOTICES.md, generated from docs/authorities.yml

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

ADR-0082 made every authority rule store the exact words it rests on: each rule in `docs/standards/` has `quotes`, each with the page's URL, the date it was read and the text. Today 743 quotes come from 21 works. The kit is public with no license of its own (ADR-0031, the owner's choice), so the quotes rest on their publishers' licenses. Apps copy `docs/standards/` (`tools/Export-KitApp.ps1`), so the quotes, and whatever their licenses ask of a copy, reach every app too.

PR 116 gave the quotes one hand-written row in `THIRD-PARTY-NOTICES.md`, listing each publisher's license. That row was a second list of facts kept by hand beside `docs/authorities.yml`, which already classes every cited publisher (ADR-0073), so nothing checked it (CRF-003). It had already drifted: it called the Azure Kubernetes Service and Microsoft cloud security benchmark pages CC BY 4.0, but their source repos aren't public. It also didn't name each work's title and author.

What the licenses ask, read from each source on 2026-11-25:

| Works | Quotes | License, and where it's stated |
|---|---|---|
| Microsoft Learn: .NET, ASP.NET Core, EF Core, .NET MAUI, Windows apps and Azure SQL docs | 641 | CC BY 4.0, each docs repo's `LICENSE` (`dotnet/docs`, `dotnet/AspNetCore.Docs`, `dotnet/EntityFramework.Docs`, `dotnet/docs-maui`, `MicrosoftDocs/windows-dev-docs`, `MicrosoftDocs/sql-docs`) |
| Microsoft Learn: NuGet and Microsoft identity platform docs | 7 | MIT (`NuGet/docs.microsoft.com-nuget`, Copyright (c) .NET Foundation; `MicrosoftDocs/entra-docs`, Copyright (c) Microsoft Corporation) |
| Microsoft Learn: Azure Well-Architected Framework, Azure Architecture Center, AKS docs, Microsoft cloud security benchmark | 34 | No open license. Each page's `original_content_git_url` names a private `-pr` repo with no public mirror, and the pages name no license, so only Learn's terms of use apply |
| W3C: WCAG 2.2 and WCAG2ICT | 24 | The W3C Document License (2023), which asks each copy to keep the document's copyright notice and its status |
| OWASP: ASVS 5.0.0, API Security Top 10 2023, Cheat Sheet Series | 28 | CC BY-SA 4.0 (ASVS's frontispiece, the API Security 2023 header, the Cheat Sheet Series' `LICENSE.md`) |
| GitHub Docs | 2 | CC BY 4.0 (`github/docs`) |
| OpenSSF Scorecard Action's README | 4 | Apache 2.0 |
| Microsoft.VisualStudio.Threading analyzer docs, Aspire docs | 3 | MIT, Copyright (c) Microsoft Corporation |

Creative Commons' recommended practice for attribution is TASL: the title, author, source and license, with links. CC BY 4.0 also asks a copy to say whether the material was changed (section 3(a)(1)(B)), and accepts a link to a page that holds the attribution (section 3(a)(2)). Microsoft's own repos credit third-party material in a `THIRD-PARTY-NOTICES` file at the root, as the kit already does for files based on .NET projects' work, and apps get that file's text in a kit block (ADR-0032).

Nothing here is legal advice. It records what each source states and what the kit does about it.

## Options

### Option 1: List each quoted work and its license in docs/authorities.yml, and generate the notice in THIRD-PARTY-NOTICES.md

- **Trade-offs:** `docs/authorities.yml` gains `licenses` (an SPDX id, or a `LicenseRef-` id where SPDX has none, with a name, a link and an optional note on what it asks) and `works` (each quoted work's title, author, optional copyright line, source, license, where the license is stated and the date read, any notice its license asks to keep, and the URL prefixes of its pages). `tools/Build-AuthoritiesPage.ps1` gives each quote's page to the work with the longest matching prefix, the way it classes cited URLs, and fills a generated block in `THIRD-PARTY-NOTICES.md` with one TASL row per work, the number of quotes and the standards that hold them, then each license's note and each work's notice. Its `-Check`, already in CI, fails when a quote matches no work, a work matches no quote, a work or license is incomplete, a work names a license the list doesn't have, or the block is stale. A hand-written paragraph above the block says the quotes are copied word for word, with formatting left out, that each rule's statement restates them, leaving open whether a close restatement of OWASP text is adapted material, and that the kit having no license adds no restriction to them. Apps get it all through their kit block. The cost is one more list to fill in when a rule first quotes a new work, which the check enforces.
- **Reversibility:** Easy: the lists and the block can go back to a hand-written row.
- **Risk:** Low. A work's license is entered by hand once, with the page where it's stated and the date read, so it can be re-checked.

### Option 2: Keep the hand-written row in THIRD-PARTY-NOTICES.md

- **Trade-offs:** No new code. It names licenses but not each work's title and author, and nothing checks it against the quotes, so a new work or a wrong license goes unnoticed, as the AKS and security benchmark entries did.
- **Reversibility:** Easy.
- **Risk:** Medium: attribution drifts silently, and the notice travels to every app.

### Option 3: A license field on every quote

- **Trade-offs:** Each of the 743 quotes would carry its license, author and title beside its URL. Attribution would sit next to the words, but the same facts would repeat hundreds of times (CRF-003), and a license change would mean editing every quote of that work. A reader would still need one page to see every license.
- **Reversibility:** Medium: a large edit across every standard.
- **Risk:** Medium: repeated facts drift.

### Option 4: Paraphrase every quote and keep only links

- **Trade-offs:** Nothing would be copied, so no license would apply. But ADR-0082 stores the words so that a reviewer and `Test-RuleQuotes.ps1` can check each rule against its page; without them that check goes.
- **Reversibility:** Hard: the words would have to be found again.
- **Risk:** High for the rules' accuracy, which is what ADR-0082 protects.

## Recommendation

Option 1: it gives every quoted work the attribution its license asks for, in the conventional place, generated from the one list that already classes the kit's sources, and CI keeps it complete.

## Decision

Accepted as recommended. The owner asked for the attribution to be done "conventionally and in whatever way is considered best practice", and said "Let's get it in then" (owner, 2026-11-23).

Two questions stay open for the owner. Nothing is paraphrased or removed until he answers:

1. **The 34 quotes under Learn's terms of use only** (Well-Architected Framework 17, Architecture Center 15, AKS 1, cloud security benchmark 1). The terms say "Unless otherwise specified, the Services are for your personal and non-commercial use", and that copying needs Microsoft's consent except for that use. These quotes are a sentence or two each, credited and linked, to show what a rule rests on, which may fall under fair use or a quotation right; that's a legal judgment this ADR can't make. **Recommendation:** replace these 34 quotes with close-reading notes and links, keeping only quotes from openly licensed works. Copying only licensed text is the cautious convention for a public repo. Before that, `Test-RuleSources` must accept an authority rule whose page has no open license and so has no quote, so the change needs its own PR and an update to ADR-0082. Until then the notice marks these works "no open license", and the table above names each one.
2. **OWASP's ShareAlike** (28 quotes). CC BY-SA 4.0 adds its ShareAlike conditions only "if You Share Adapted Material You produce". The quotes are copied unchanged, so on the license's own words they're shared under its attribution terms only, and the notice says so. Whether a rule statement that restates an OWASP quote counts as Adapted Material is the open part. **Recommendation:** treat the quotes as unchanged material, keep each statement in the kit's own words, and never restate OWASP text closely. Some statements do track their OWASP quotes closely today (SEC-022 and SEC-023 at least), so rewording those is a follow-up for after your answer. Ask a lawyer before the kit takes a license, since that's when a ShareAlike claim would matter.

The Apache 2.0 work (four sentences of a README) is credited with its copyright line, and the license's full text is in the file, since section 4(a) asks a redistribution to give recipients "a copy of this License". The MIT works are credited with their copyright lines, and the MIT text was already in the file. The quotes' match prefixes stay within the folders each source repo serves (and a folder prefix also matches the folder's own page cited without its trailing slash, as `https://github.com/ossf/scorecard-action` is), because Learn serves other repos' pages under the same top folder (`/dotnet/api/` comes from `dotnet/dotnet-api-docs`, not `dotnet/docs`).

## Consequences

- `docs/authorities.yml` lists 6 licenses and 21 works. `THIRD-PARTY-NOTICES.md` has a "Quoted passages in `docs/standards/`" section, whose table `Build-AuthoritiesPage.ps1` generates, and the Apache License 2.0's text. `docs/standards/ui.md` points to the W3C notices beside its quotes, since the W3C license asks for them on every copy of a portion. The hand-written quotes row is gone, and the two MIT texts' headings no longer name quoted works by hand.
- A rule that quotes a new work fails `Build-AuthoritiesPage.ps1 -Check` until the work's entry is added; the `source-a-rule` skill says so.
- Apps get the section in their `THIRD-PARTY-NOTICES.md` kit block, so the attribution travels with the quotes they copy; the sync job updates it.
- `ConvertTo-DateText` moves to `KitFrontMatter.psm1`, shared by `Test-RuleSources.ps1` and `Build-AuthoritiesPage.ps1`.
- Amends ADR-0082 (where the quotes' licenses are recorded) and ADR-0073 (the script also fills the notices block).

## Pillars affected

- **Reliability:** none at run time; the notice can't fall behind the quotes, because CI checks it.
- **Security:** none.
- **Operational Excellence:** one list to update when a new work is quoted, and the check names what's missing.
- **Performance Efficiency:** none.
- **Cost Optimization:** none.

## Sources

- owner, 2026-11-23
- ADR-0031, ADR-0032, ADR-0073, ADR-0082
- https://wiki.creativecommons.org/wiki/Recommended_practices_for_attribution, retrieved 2026-11-25 ("To remember these attribution elements, it's helpful to think of the acronym: TASL.")
- https://creativecommons.org/licenses/by/4.0/legalcode.en, retrieved 2026-11-25 (section 3(a)(1)(B), "indicate if You modified the Licensed Material"; section 3(a)(2), "You may satisfy the conditions in Section 3(a)(1) in any reasonable manner based on the medium, means, and context in which You Share the Licensed Material.")
- https://creativecommons.org/licenses/by-sa/4.0/legalcode.en, retrieved 2026-11-25 (section 3(b), "In addition to the conditions in Section 3(a), if You Share Adapted Material You produce, the following conditions also apply.")
- https://www.w3.org/copyright/document-license-2023/, retrieved 2026-11-25 (a copy must include a link to the document, its copyright notice and its status)
- https://learn.microsoft.com/legal/termsofuse, retrieved 2026-11-25 ("Unless otherwise specified, the Services are for your personal and non-commercial use.")
- https://www.apache.org/licenses/LICENSE-2.0, retrieved 2026-11-25 (section 4(a))
- Each work's license, at the `stated` URL in `docs/authorities.yml`, read 2026-11-25 through `gh api repos/<repo>/license` and the pages themselves
