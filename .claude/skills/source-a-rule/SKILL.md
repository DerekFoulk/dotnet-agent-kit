---
name: source-a-rule
description: Write or fix a rule in docs/standards so it says only what its quoted source says. Kit only.
---

# Source a rule

A rule labeled `basis: authority` states only what its page says (ADR-0082). The owner, 2026-11-17: "'Authority' must be properly sourced."

1. **Read the page as a reader sees it.** Open each cited page: Microsoft Learn with the Learn MCP server's `microsoft_docs_fetch`, others with a fetch. Cite a versioned page at the kit's version, such as `?view=aspnetcore-10.0`. The docs repo's Markdown is a fast draft, but the live page is the authority. Learn renders a cross-reference with its full name, so `Lock` becomes "System.Threading.Lock".

2. **Quote the sentence that says it.** Add to the rule:

   ```yaml
   quotes:
     - source: "https://learn.microsoft.com/ef/core/testing/choosing-a-testing-strategy"
       retrieved: "2026-11-17"
       text: "Avoid the in-memory provider for testing purposes - this is discouraged and only supported for legacy applications."
   ```

   - **Text:** verbatim, as rendered, plain text with link text kept. One contiguous passage, never an ellipsis for left-out words; another passage is another quote. Keep it to the shortest passage that supports the rule.
   - **Source:** `source` and `retrieved` equal one of the rule's `sources`, written `"<URL>, retrieved <date>"`. When you re-read a page, re-date both.
   - **Coverage:** an authority rule quotes every page it cites.

3. **Keep the page's strength.** No stronger, no weaker.

   | The page says | The rule says |
   |---|---|
   | DO, must, always | the imperative, or "must" |
   | DON'T, DO NOT, must not, never | "never" or "don't" |
   | we recommend, should, prefer | "prefer", "is recommended", "should" |
   | CONSIDER | "consider" |
   | AVOID | "avoid" |
   | allows, can, supports, an example | no rule |

   Check the `why` and the standard's Markdown body too. Any "Microsoft recommends" there must match a quote.

4. **Split what the page doesn't say.** A kit tightening or an owner decision is its own rule:
   - **The split-off rule:** `basis: preference` and `layer: owner`. It cites the owner's words and date (`owner, YYYY-MM-DD`) or the ADR, and takes the next free id in the file's prefix.
   - **Ids:** the original id stays with the half that existing references and gates mean. Grep the repo for the id.
   - **Enforcement:** the parts move with the wording they check.
   - **Status:** both halves keep the original's status. Never change proposed to accepted; that's the owner's call.
   - **Acceptance:** an authority rule cites pages only. The owner's acceptance of it goes in `ratified`, not `sources`.
   - **No page:** if no page supports the rule, make it a preference citing the owner or ADR that's already on it, or retire it. Never stretch a quote.

5. **Name the scope and the enforcement.**
   - **Scope:** `core` only if the rule fits a Web API, a Blazor app and a .NET MAUI app alike, and the libraries they hold. Otherwise list app types from `docs/standards/app-types.yml` (`web-api`, `blazor`, `maui`), never all of them. Web assumptions are not `core`: HTTP, middleware, Program.cs hosting, Problem Details, cookies, CORS, server databases. WPF, Windows Forms, WinUI 3, Blazor Hybrid, Razor Pages and MVC, and workers and console apps aren't supported types yet, so no rule is written for them alone. Say "WinUI 3", never "WinUI".
   - **Enforcement:** add a gate where an analyzer or check in this repo already enforces the rule (name it). Otherwise it's advisory: say what code review checks and why no tool does.
   - **Scorecard:** a new rule in force needs a scorecard area, in `docs/quality/scorecard.md`.

6. **Run the checks and regenerate.** Then commit the generated files with the rules.

   ```text
   ./tools/Test-RuleSources.ps1
   ./tools/Test-RuleQuotes.ps1
   ./tools/Build-AgentRules.ps1
   ./tools/Build-AuthoritiesPage.ps1
   ./tools/Test-Scorecard.ps1 -Update
   ```

   - `Build-AuthoritiesPage.ps1`: a new site needs an entry in `docs/authorities.yml`'s `sources` first, and a quote from a new work needs one in its `works`: the work's title, author, source and license, read from its repo's LICENSE or the site's terms (ADR-0094). A work with no open license gets the terms-of-use license entry and goes to the owner.
   - Then `./tools/Build-AgentRules.ps1 -Check`, and `./tools/Invoke-KitTests.ps1` in a fresh clone (ADR-0092).

7. **Have the reviewer compare.** The reviewer compares every new or changed rule with its quotes and refuses one worded more strongly (`docs/code-review.md`). Report the before and after of each changed rule in the PR.
