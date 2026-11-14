---
name: new-app
description: Start a new app repo from the chat. Ask the intake cards (app type, data, database, sign-in, hosting, test tools) with recommended defaults and prices, then run New-KitApp with the answers. Use when the owner asks for a new app. Kit only.
---

# New app

The owner starts an app from the chat and never opens a terminal (ADR-0058). You ask the questions, write the answers to a file, and run `New-KitApp` yourself. Creating the repo is the owner's call (SEC-003): ask before the real run.

## 1. Read the cards

- The app's name and repo name come first, as a plain question: the name must be a dotted .NET name such as `Contoso.Orders`, and the repo name may have hyphens (README, "Start a new app"). Recommend both.
- Pick the kit ref: the newest release tag, or, until a release has `templates/app-intake.json`, the current `origin/main` commit. Read the file at that ref: `git show <ref>:templates/app-intake.json`. Every card and tool comes from it; don't add options of your own.
- Check the prices you'll show. Each priced entry has its source and the date it was checked; if a date is more than a month old, check the source again, and if a price changed, say so and fix the file in a PR. The database card's prices are in `docs/database-guide.md`.

## 2. Ask

With AskUserQuestion (Claude Code), at most four cards per call. Each card's first option is its recommendation: label it "(Recommended)", and put its cost label (Free, Free tier with the free amount, or Paid with the price) in each option's description.

1. **First call:** `appType`, `data`, `signIn` and `hosting`.
2. **Second call:** `database`, showing only the options whose `fits` lists the data answer, and the **test tools** card. If only one database option fits, don't ask: tell the owner the choice and why. The test tools card has two options: "Kit defaults, free (Recommended)", whose `preview` is a table of every kind of test with its default tools and their labels, and "Choose per kind of test".
   Ask in the same call whether the app will be sold or paid for, if he hasn't said: FluentAssertions 8 is free only for a non-commercial app. For a commercial one, recommend AwesomeAssertions in its place (ADR-0004).
   Ask the `budget` card in the same call too: $0 first, as the recommendation. "Other" takes an exact monthly amount. If he skips it, leave it out of the answers: it's $0 by default (ARC-012).
3. **Only if he chose per kind:** one card per kind that has a tool besides its defaults (`default: false`), up to four per call, with `multiSelect` on. List the defaults first, then each alternative with its license, label and price.

"Other" is always on offer. Record an Other answer as `Other: <his words>`; the profile marks it as needing an ADR, except on a card with `otherIsAmount`, such as the budget, where it records the amount as he gave it. For test tools there's no Other: a tool that isn't listed needs an ADR (TST-005), so say that and add it to the kit's list first if he wants it.

Without AskUserQuestion (VS Code, Visual Studio), ask the same cards as numbered questions in the chat, each option with its label and cost, and the recommendation first with its reason.

Then restate every question with his answer as a table (COM-003).

## 3. Write the answers

Write a JSON file in your scratchpad, never in the kit's folder:

```json
{
  "appType": "web-api-blazor",
  "data": "relational",
  "database": "azure-sql-free",
  "signIn": "entra-external-id",
  "hosting": "none",
  "testTools": { "load": ["jmeter"] }
}
```

Each card's key holds an option `id` or `Other: <text>`. `testTools` is optional: a kind listed there uses exactly the tool ids given, and every other kind uses its defaults.

## 4. Run New-KitApp

1. Say in one line what it does, then run it with `-WhatIf`: `./tools/New-KitApp.ps1 -Name <Name> -RepoName <repo> -KitRef <ref> -Intake <answers.json> -WhatIf`. It checks the answers, the name and the sign-in, and lists the steps without changing anything. Fix any answer it refuses and ask again.
2. Show him the steps and ask for his yes to create the repo, public unless he asked for `-Private` (README, "Start a new app").
3. On his yes, run it without `-WhatIf`. The app's first commit has `docs/app-profile.md` with his answers. Report the repo's URL and the local folder.

The app's first plan starts from its `docs/app-profile.md`.
