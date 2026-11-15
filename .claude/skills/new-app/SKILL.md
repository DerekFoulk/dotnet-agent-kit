---
name: new-app
description: Start a new app repo from the chat. Ask the intake cards (app type, data, database, sign-in, hosting, test tools) with sourced defaults and prices, then run New-KitApp with the answers. Use when the owner asks for a new app. Kit only.
---

# New app

The developer starts an app from the chat and never opens a terminal (ADR-0058). You ask the questions, write the answers to a file, and run `New-KitApp` yourself. Creating the repo is the owner's call (SEC-003): ask before the real run.

## 1. Read the cards and the defaults

- The app's name and repo name come first, as a plain question: the name must be a dotted .NET name such as `Contoso.Orders`, and the repo name may have hyphens (README, "Start a new app"). Recommend both.
- Pick the kit ref: the newest release tag, or, until a release has `templates/app-intake.json` at schemaVersion 2, the current `origin/main` commit. Every card and tool comes from that file; don't add options of your own.
- Read the defaults, with all three sources, in a terminal (the same on every surface: Claude Code, Copilot in VS Code, Visual Studio):

  ```powershell
  Import-Module ./tools/KitIntake.psm1
  $intake = Get-KitIntake -Text (git show <ref>:templates/app-intake.json | Out-String)
  Get-KitIntakeDefault -Intake $intake -Preference (Read-KitPreference) | ConvertTo-Json -Depth 8
  ```

  Each row is one card (one per data answer for the database card) or one test tool role (`unit/framework`, `load/load`...). `Pick` is the default and `From` says whose it is: `developer`, `authority`, `agent` or `only option`. `Developer`, `Authority` and `Agent` hold the three sources, and `Notes` says what was passed over: a preference that isn't an option any more, or an authority pick that's Paid (ARC-012). The developer's preferences file is theirs, outside every repo (`docs/preferences.md`, ADR-0070). A new kit user has none, and that's fine.
- Check the prices you'll show. Each priced entry has its source and the date it was checked. If a date is more than a month old, check the source again, and if a price changed, say so and fix the file in a PR. The database card's prices are in `docs/database-guide.md`.

## 2. Ask

Keep the three sources apart, each labeled, on every card:

- **The developer's preference:** "Your preference (2026-11-10, ADR-0053)", from their file.
- **The authority's recommendation:** only what the page says, with its link: "Microsoft: no recommendation" where it names no pick. Never present the agent's pick as Microsoft's.
- **The agent's recommendation:** "The agent's recommendation", with its reason, from the intake's `agent` entry. Never save it as the developer's preference.

Put each card's default first, labeled "(Recommended: your preference)", "(Recommended by Microsoft)" or "(Recommended by the agent)". In each option's description, put its cost label (Free, Free tier with the free amount, or Paid with the price), and on the default, the other sources. Say any note out loud. Prices are facts with their own sources, not a recommendation.

With AskUserQuestion (Claude Code), at most four cards per call:

1. **First call:** `appType`, `data`, `signIn` and `hosting`.
2. **Second call:** `database`, showing only the options whose `fits` lists the data answer, with the default of that answer's row. Then the **test tools** card. If only one database option fits, don't ask: say the choice and why. The test tools card has two options. "Defaults (Recommended)" has a `preview` table of every kind of test and role, with its default tool, its label and whose pick it is. The other is "Choose per kind of test".
   If the assertions default is FluentAssertions 8, ask in the same call whether the app will be sold or paid for: it's free only for a non-commercial app, and a commercial one uses AwesomeAssertions in its place (ADR-0004).
   Ask the `budget` card in the same call too. "Other" takes an exact monthly amount.
3. **Only if they chose per kind:** one card per role that has more than one tool, up to four per call, with the default first, then each alternative with its license, label and price.

"Other" is always on offer. Record an Other answer as `Other: <their words>`. The profile marks it as needing an ADR, except on a card with `otherIsAmount`, such as the budget, where it records the amount as given. For test tools there's no Other: a tool that isn't listed needs an ADR (TST-005), so say that, and add it to the kit's list first if they want it.

Without AskUserQuestion (VS Code, Visual Studio), ask the same cards as numbered questions in the chat. Give each option its label and cost, and the default first, labeled as above.

Then restate every question with the answer as a table (COM-003).

When the developer states a preference ("always PostgreSQL"), offer to save it in their preferences file, in their words, with today's date and "said in chat" as its source (`docs/preferences.md`). Save it only on their yes, and never save one they didn't state.

## 3. Write the answers

Write a JSON file in your scratchpad, never in the kit's folder:

```json
{
  "appType": "web-api-blazor",
  "data": "relational",
  "database": "azure-sql-free",
  "signIn": "entra-external-id",
  "hosting": "none",
  "budget": "budget-0",
  "testTools": { "unit": ["xunit", "moq", "awesomeassertions", "bogus", "fscheck", "faketimeprovider", "fakelogger"], "load": ["locust"] }
}
```

Each card's key holds an option `id` or `Other: <text>`. Write every card, the budget too: an unanswered budget is $0 (ARC-012), whatever the developer's preference. Write `testTools` for every kind, always. `Get-KitTestToolAnswer -Default <the rows from step 1>` gives it with the developer's picks; then apply any change made in step 2. `New-KitApp` doesn't read the developer's preferences file, so the same answers give the same app on any machine, and a kind left out would get the kit's own defaults instead of the developer's.

## 4. Run New-KitApp

1. Say in one line what it does, then run it with `-WhatIf`: `./tools/New-KitApp.ps1 -Name <Name> -RepoName <repo> -KitRef <ref> -Intake <answers.json> -WhatIf`. It checks the answers, the name and the sign-in, and lists the steps without changing anything. Fix any answer it refuses and ask again.
2. Show the steps and ask for the owner's yes to create the repo, public unless they asked for `-Private` (README, "Start a new app").
3. On the yes, run it without `-WhatIf`. The app's first commit has `docs/app-profile.md` with the answers. Report the repo's URL and the local folder.

The app's first plan starts from its `docs/app-profile.md`.
