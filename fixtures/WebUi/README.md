# Web UI fixture

A small Blazor app whose only job is to be tested in a real browser by the kit's CI (ADR-0061, GAP-004). It isn't a feature, and apps don't get it: it shows an app with a web UI how to set up its browser and accessibility tests, and it proves in the kit's own required CI job that the shared workflow installs Playwright's browser and runs them.

| Project | What it holds |
|---|---|
| `src/Kit.WebUi` | A Blazor Web App with static server rendering and enhanced navigation: two pages linked to each other, a stylesheet with a visible focus outline, and `FocusOnNavigate`, which moves focus to each new page's `h1` (UI-001) |
| `tests/Kit.WebUi.E2E.Tests` | Playwright and axe tests (TST-003's E2E kind, UI-002): every page passes axe's WCAG 2.2 level A and AA rules; axe really finds a 2.0 level A and a 2.2 level AA failure; a link moves focus to the next page's heading; the first Tab shows the app's own focus outline; the app is hosted on a port the system picks, and still starts when the factory's content-root lookup goes wrong (as under Stryker) |

It has no bUnit project: no component here has logic of its own (ARC-009). It has no HTTPS redirection or HSTS, since it's never deployed; a real app keeps the template's. Interactive render modes aren't covered yet (GAP-034).

## Run it

From the repo root, after a build, with the Chromium build Playwright pins installed (the owner's step; see `docs/standards/testing.md`, "Browser and accessibility tests"):

```powershell
dotnet test --project fixtures/WebUi/tests/Kit.WebUi.E2E.Tests
dotnet run --project fixtures/WebUi/src/Kit.WebUi
```
