---
name: recheck-sources
description: Re-read the pages rules quote and fix each rule whose quote changed or is gone. Kit only.
---

# Re-check sources

Pages change: a recommendation softens, moves or is withdrawn. A rule whose quote is gone claims an authority that no longer says it (ADR-0083). `.github/workflows/rule-quotes.yml` runs this check weekly and opens an issue when a quote is missing, or when pages didn't load.

1. **Run the check.** `./tools/Test-RuleQuotes.ps1` reads each quoted page once and looks for each quote in the page's visible text. It matches whole words with their case, and ignores markup, curly quotes, emoji and extra spaces. The exit code says what it found:
   - **0:** every quote was found.
   - **1:** a quote is missing. Each one is listed with its rule, page and text. A page that answers 404 or 410 is gone, so its quotes count as missing.
   - **2:** nothing is missing, but a page didn't load. Run it again later; a page that didn't load isn't a missing quote. A pull request's run passes on this; a scheduled run fails and opens an issue.

2. **For each missing quote, read the page.** Open it with the Learn MCP server's `microsoft_docs_fetch`, or a fetch for other sites. Search for the quote's key words. Then decide which case it is:
   - **Same words, new rendering:** for example, a cross-reference now shows its full name ("System.Text.StringBuilder"). Fix the quote's text.
   - **Same meaning, new wording:** store the new sentence, and reword the rule if its strength changed (`source-a-rule`, step 3).
   - **Weaker:** "do" became "consider", for example. Reword the rule to the new strength. If the kit wants the old strength, that part is a preference rule now, and it needs the owner (`source-a-rule`, step 4).
   - **Gone, moved elsewhere:** cite and quote the new page.
   - **Gone, no page says it now:** downgrade the rule to a preference citing the owner or ADR on it, or retire it. Ask the owner which, in the chat.

3. **Re-date what you re-read.** The quote's `retrieved` and its source's `, retrieved` move to today together.

4. **Run the checks and regenerate,** as `source-a-rule` step 6 says. Open one PR for the fixes, with each rule's before and after. Close the workflow's issue once a run passes.
