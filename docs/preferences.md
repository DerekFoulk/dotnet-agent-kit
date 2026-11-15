# Your preferences file

The new-app intake recommends an answer to each question from three separate sources, each labeled (ADR-0070):

1. **Your preference:** what you have said you want, with the date you said it. It lives in your preferences file, which is yours, not the kit's.
2. **The authority's recommendation:** only what its page says, such as Microsoft Learn, with the page and the date it was read. It counts as a pick only where the page recommends the tool, says it should be used, or gives it a guideline level such as CONSIDER. A page that only says you can use a tool, uses one, or names one as an example names no pick, and the intake says so. These live in `templates/app-intake.json`.
3. **The agent's recommendation:** the agent's pick, labeled as the agent's, with its reason. It's never stored as your preference and never shown as Microsoft's.

The default is your preference if you have one. If you don't, it's the authority's pick, unless that's a paid option: ARC-012 starts every tool on its free option, so a paid pick is listed, never made the default. Failing both, it's the agent's pick. Prices and free amounts are facts with their own sources, kept apart from all three.

A new kit user has no preferences file, and the intake works without one.

## Where it lives

`~/.dotnet-agent-kit/preferences.json`: in your home folder (`C:\Users\<you>\.dotnet-agent-kit\preferences.json` on Windows), outside every repo, so neither the kit nor a public app ever publishes it. Copy it yourself if you work on more than one machine.

Never put a secret in it: no keys, tokens, passwords or connection strings (SEC-001).

## How an agent reads it

The same way on every surface: Claude Code, GitHub Copilot in VS Code and Visual Studio. The `new-app` skill runs this in a terminal, from the kit's folder:

```powershell
Import-Module ./tools/KitIntake.psm1
$intake = Get-KitIntake -Text (git show <kit ref>:templates/app-intake.json | Out-String)
Get-KitIntakeDefault -Intake $intake -Preference (Read-KitPreference) | ConvertTo-Json -Depth 8
```

`Read-KitPreference` reads the file at the path above, or the one you pass with `-Path`, and checks it. A missing file means no preferences. `Get-KitIntakeDefault` gives one row for each question and each test tool role: the default, which source it came from, and all three sources, so the agent shows them side by side.

## How a preference gets in

When you tell the agent a preference ("I always want PostgreSQL"), it writes it down in your words with today's date and asks you to confirm. An agent never adds a preference you didn't state, and never stores its own recommendation there. You can edit the file yourself at any time.

## The format

```json
{
  "schemaVersion": 1,
  "preferences": [
    { "choice": "database", "when": "relational", "pick": "postgresql", "stated": "PostgreSQL for every relational app", "date": "2026-11-20", "source": "said in chat" },
    { "choice": "load/load", "pick": "locust", "stated": "Locust for load tests", "date": "2026-11-20", "source": "said in chat" },
    { "stated": "EF Core with code-first migrations for data access", "date": "2026-11-20", "source": "said in chat" }
  ]
}
```

Each preference has:

- `stated`: what you said, in your words, or as close to them as the source records it.
- `date`: when you said it, as `yyyy-mm-dd`.
- `source`: where you said it, such as "said in chat" or an ADR.
- `choice` and `pick`, when it answers an intake question. `choice` is the card's id, or `<kind of test>/<role>` for a test tool, such as `unit/assertions`. `pick` is the option or tool id. `when` names the other card's answer for a card that depends on one, such as the database for `relational` data.

A preference without `choice` is still yours: agents read it when they plan, but the intake doesn't apply it. A pick that isn't an option any more is skipped, and so is a preference for a question the intake doesn't ask, or for the database with no `when`. Each time, the agent says so. Two preferences for the same question are refused: keep the one you mean.
