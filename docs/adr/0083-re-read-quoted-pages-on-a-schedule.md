# ADR-0083: Re-read every quoted page on a schedule, and on a pull request that changes a rule

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

ADR-0082 has every authority rule store the sentence on its page that says what the rule says, about 800 quotes on about 300 pages. Microsoft Learn and the other sources change their pages without notice, so a quote that was true when stored can disappear. A page might soften "do" to "consider", or a recommendation might be withdrawn. The rule would then claim an authority that no longer says it. The owner asked for a scheduled workflow, like `.github/workflows/nuget-trust.yml`, that re-reads each cited page and opens an issue when a stored quote no longer appears on it.

The first run, on 2026-11-17, showed two more things a re-read must handle:

- **Rendered text differs from the source.** The stored text was read from each docs repo's Markdown. Learn renders a cross-reference with its full name ("System.Threading.Lock"), and the live page can lag or lead its repo. The Windows developer FAQ's repo said "Windows-only app ... WinUI", while the live page says "general-purpose Windows desktop app ... WinUI 3". 8 of 804 quotes differed. They were fixed to the live text, which is what a reader sees.
- **Pages time out.** One page answered 504, and a page that didn't load is not a removed quote.

## Options

### Option 1: A script that reads each page's HTML and looks for each quote, run weekly and on rule changes

`tools/Test-RuleQuotes.ps1` reads each quoted page once and turns its HTML into text: scripts, styles and tags removed, entities decoded. It then compares both sides as a reader sees the words: curly quotes and dashes made plain, emoji and whitespace dropped, case ignored. Each quote ends Found, Missing or Unreachable. A page that answers 404 or 410 is gone, so its quotes are Missing; any other failure to load is Unreachable.

- **Trade-offs:** about 300 requests a run, sequential; no dependency. The normalization can hide a change in punctuation or case, which doesn't change what a rule says. Page text never runs and never reaches a shell: the workflow passes only the script's exit code and the run's URL into the issue.
- **Reversibility:** easy.
- **Risk:** low. A page that blocks automated readers would show as Unreachable, not Missing.

### Option 2: Use the Microsoft Learn MCP server or Learn's API

- **Trade-offs:** returns Markdown, close to what helpers quoted. But it covers only Microsoft's pages, not OWASP, W3C or GitHub. It needs a connector in CI (adding one is the owner's call) and isn't what a reader sees.
- **Reversibility:** easy.
- **Risk:** medium.

## Recommendation

Option 1. One script covers every publisher, compares against what a reader sees, and needs nothing new.

## Decision

Option 1:

- `.github/workflows/rule-quotes.yml` runs `Test-RuleQuotes.ps1` weekly and by hand. A scheduled or hand-started run fails, and opens one issue unless one with the same title is already open (as `nuget-trust.yml` does), when a quote is missing ("A rule's quoted source changed"), when pages didn't load ("Pages a rule quotes didn't load"), so a site that keeps refusing the runner doesn't pass unseen, or when the check couldn't finish ("The rule quote check failed"). Only the result word and the run's URL reach the issue, never page text.
- It also runs on a pull request that changes `docs/standards/`, the script or the workflow, as a check the reviewer reads: the reviewer compares each new or changed quote with its page (ADR-0082) and is the gate before merge. The PR run isn't a required check, and it passes when pages only fail to load, since a site's outage shouldn't block a PR; a missing quote fails it.
- Exit codes: 0, every quote found; 1, a quote missing, including a page that answers 404 or 410; 2, none missing but a page didn't load.
- The fix is the `recheck-sources` skill: read the page, then update the quote and the rule to what the page says now, and re-date both. If the page no longer supports the rule at all, downgrade or retire it.

## Consequences

- A changed page reaches the kit within a week, as an issue.
- The kit's CI makes about 300 requests to the sources each week. That's polite at one request at a time; nothing is cached.
- A page that moves without a redirect shows as Missing or Unreachable, and is fixed by citing its new URL.

## Pillars affected

- **Operational excellence:** a stale source is found on a schedule, with an issue naming the rule and page.
- **Reliability:** an outage never reads as a removed quote.
- **Security:** read-only access; `issues: write` only in the job that opens the issue; page text is treated as data.
- **Cost:** free on a public repo's standard runners.
- **Performance:** n/a.

## Sources

- owner, 2026-11-17
- ADR-0066
- ADR-0082
