# ADR-0058: The new-app intake asks its questions from one data file

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

`New-KitApp` creates an app repo (ADR-0033), but nothing records what the app is: its type, data, database, sign-in, hosting and test tools. Each new app's first plan had to ask again, and an earlier project's intake questionnaire was one of the three kits ADR-0001 replaced. The owner wants to start a new app from the chat and never open a terminal: the agent asks with question cards, each with a recommended answer (COM-001), and `New-KitApp` takes the answers.

The owner also asked that every tool the kit offers be labelled Free, Free tier or Paid, with its price, and that the defaults always be free (owner, 2026-11-11). Two testing questions were still open: where the list of test tools lives, since TST-005 and ADR-0003 each name tools (CRF-003 wants one source), and whether a check enforces TST-003's test matrix.

## Options

### Option 1: One data file for the cards and the test tools, checked by tests

`templates/app-intake.json` holds each card (its question, header and options, the recommended one first) and each kind of test with its tools, licenses and cost labels. `tools/KitIntake.psm1` checks a set of answers against it, and `New-KitApp -Intake <answers.json>` writes them to the app's `docs/app-profile.md` in the first commit. The `new-app` skill builds the cards from the file. Tests check the file fits AskUserQuestion's limits, that every default is Free, that every non-Free entry has a price, a source and a date, and that every tool TST-005 and ADR-0003 name is in it.

- **Trade-offs:** One source for the questions, the tools and their prices, which the skill, `New-KitApp` and the tests all read. The cards follow the file, so a new option needs no code. Prices still go stale: each carries its date, and the skill re-checks the ones it shows.
- **Reversibility:** Easy: the file and the profile are data; an app's profile is its own and can change through its own ADR.
- **Risk:** Low. The skill's cards rely on AskUserQuestion, a Claude Code tool; on other surfaces the skill asks the same questions in plain chat.

### Option 2: The questions in the skill's text, the tools in the testing standard

- **Trade-offs:** No new file, but `New-KitApp` can't check answers against prose, the tools would be named in three places (TST-005, ADR-0003, the skill), and prices would sit in a rule's statement.
- **Reversibility:** Easy.
- **Risk:** Medium: the lists drift, which CRF-003 forbids.

### Option 3: Parameters on New-KitApp for each answer

`-AppType`, `-Database` and so on, each with a fixed set of values.

- **Trade-offs:** Checked by PowerShell itself, but the values would be written in the script and again in the skill, and the test tools don't fit parameters.
- **Reversibility:** Moderate: each change is a script change.
- **Risk:** Medium.

The second open question, whether a check enforces the test matrix, has two options of its own.

### Option 4: Build the test matrix check now

A script in app CI that fails when a production project lacks a test project of each kind TST-003 requires.

- **Trade-offs:** TST-003 stops being advisory for apps at once. But which projects an app has is what GAP-002 (how much structure an app gets) is settling, so the check would encode a structure that may change, and no app has projects yet to check.
- **Reversibility:** Moderate: a required check is a guardrail, and changing it needs the owner's yes.
- **Risk:** Medium: a check built on the wrong structure blocks correct apps.

### Option 5: Propose the check now, build it after GAP-002

TST-008 (proposed) says a check enforces the matrix; scorecard GAP-027 tracks building it once GAP-002 decides an app's projects.

- **Trade-offs:** No check until then, so the reviewer agent carries TST-003 for the first app. The check, when built, fits the structure apps actually get.
- **Reversibility:** Easy.
- **Risk:** Low: the practice run's first app has few projects to miss.

## Recommendation

Option 1: one file feeds the cards, the answer check and the tests, so nothing is stated twice. For the matrix, option 5: checking now would fix a structure that GAP-002 may change, so the better check waits for it, named (CRF-002).

## Decision

Proposed (auto mode, ADR-0035), with TST-007 and TST-008; the owner accepts or changes it. The load-testing tools are the owner's decision (ADR-0057).

## Consequences

- New `templates/app-intake.json`, `tools/KitIntake.psm1`, the `new-app` skill (kit only: `Export-KitApp` leaves it out of apps, which can't run `New-KitApp`), and `-Intake` on `New-KitApp`, which is now required. Every new app starts with `docs/app-profile.md`, which the app owns: it isn't in the manifest, and the kit sync never changes it.
- `New-KitApp` reads `templates/app-intake.json` from the kit at `-KitRef`, as it reads `templates/github`, and refuses a file whose `schemaVersion` it doesn't know. No release has the file yet, so until one does, the skill passes a `-KitRef` at or after the commit that added it.
- The database card's prices live in `docs/database-guide.md` (ADR-0052); the card names the guide rather than repeating them. Its options must stay in step with the guide's; a test checks each option's name appears in the guide. The guide comes from another branch, so that test is skipped until the guide is on `main`.
- TST-007 (proposed): the tools list lives only in `templates/app-intake.json`. TST-008 (proposed): a check enforces the test matrix; GAP-027 tracks it.
- What gets harder: a kit change to the cards changes what every later new app is asked, so a card's options are reviewed like code.

## Pillars affected

- **Cost Optimization:** every option shows what it costs, and the defaults are free.
- **Operational Excellence:** every app records what it is in one place, from its first commit.
- **Reliability:** answers are checked before `New-KitApp` changes anything.

## Sources

- owner, 2026-11-11
- ADR-0001
- ADR-0033
- ADR-0052
- ADR-0057
