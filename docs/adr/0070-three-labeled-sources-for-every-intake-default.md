# ADR-0070: Three labeled sources for every intake default, and a preferences file each developer owns

- **Status:** Proposed
- **Date:** 2026-11-15

## Context

The kit is public, and anyone can use it (since 2026-11-06). Its rules already separate what an authority's page says (basis `authority`, with a URL) from preferences (basis `preference`). The new-app intake (ADR-0058) didn't: each card's first option was "the recommendation", and each test tool's `default: true` was the default, with no word on whose recommendation it was. Some came from Microsoft's guidance, some were the owner's own taste (xUnit, Moq and FluentAssertions, ADR-0003; Locust, ADR-0057; a $0 budget, ARC-012), and some were an agent's proposal. Another kit user would be handed the owner's taste as if it were guidance.

The owner decided on 2026-11-15 that every recommendation the intake gives carries three separate, labeled sources:

- **The authority's:** only what its page says, with the page and the date read. Where the page names no pick, it records that.
- **The developer's:** what that developer stated, with the date, in a preferences file that belongs to the developer, not the kit. A new kit user starts with none.
- **The agent's:** said when the intake asks, labeled as the agent's, with its reason. It's never stored as a preference and never shown as Microsoft's.

A default is picked from the developer's preference first, then the authority's recommendation, then the agent's. Prices and free-tier limits stay as they are: sourced facts, separate from all three.

Two questions were open: where the developer's file lives, and how an agent reads it in Claude Code, GitHub Copilot in VS Code and Visual Studio.

## Options

### Option 1: A user-level file outside every repo, read by a kit command

`~/.dotnet-agent-kit/preferences.json` in the developer's home folder. `Read-KitPreference` in `tools/KitIntake.psm1` reads and checks it, and `Get-KitIntakeDefault` combines it with the intake into one labeled default per question. The `new-app` skill runs that command in a terminal and shows its result. Every surface can do this: Claude Code with its PowerShell tool, and Copilot in VS Code and Visual Studio with their terminal tools. Claude Code can also read the file directly, after asking once, because it's outside the project.

- **Trade-offs:** One file per developer, the same for every app they start, and never in a repo, so a public kit or a public app never publishes anyone's taste. The command makes the read the same on every surface and testable. But it's a file on one machine: a developer with two machines copies it, and an agent outside the kit (in an app) can't run the intake's command. That case doesn't exist yet: only the kit runs the intake.
- **Reversibility:** Easy: the file is plain JSON, and moving it means changing one default path.
- **Risk:** Low. The file could hold something sensitive if a developer typed it there; the format has no field for secrets, and `docs/preferences.md` says never to put one in it.

### Option 2: A section of the app's `docs/app-profile.md`

- **Trade-offs:** The app records why it chose what it chose. But the app doesn't exist yet when the intake asks, a preference is the developer's across apps rather than one app's, apps are public by default (ADR-0033), and an app with several developers would have to pick whose taste it holds.
- **Reversibility:** Moderate: preferences spread across every app's profile.
- **Risk:** Medium: one developer's taste published in every app they start.

### Option 3: A file per developer in the kit (`preferences/<login>.json`)

- **Trade-offs:** Versioned and reviewed like the rest of the kit. But it's exactly what the owner wants to avoid: the kit is public, and every kit user's copy would carry everyone's taste.
- **Reversibility:** Easy.
- **Risk:** High: other users read it as the kit's guidance.

### Option 4: Each agent's own memory or custom instructions

Claude Code's memory, Copilot's personal instructions.

- **Trade-offs:** Nothing new to build. But each surface keeps its own, the intake's code can't read any of them, and the same developer gets different defaults in different tools.
- **Reversibility:** Easy.
- **Risk:** Medium: defaults that can't be checked or explained.

## Recommendation

Option 1: the preferences stay the developer's, out of every public repo, and one command reads them the same way on every surface.

## Decision

Proposed (auto mode, ADR-0035), like ADR-0053 and ADR-0058: it's in force, and the owner accepts or changes it. The three sources and the order of picking are the owner's (2026-11-15). These parts are the agent's, for him to review:

- where the file lives (option 1);
- the exception for a Paid authority pick (below);
- the bar for an authority's pick;
- the agent's recommendation of AwesomeAssertions for assertions.

## Consequences

- `templates/app-intake.json` is at schemaVersion 2.
  - Each card has a `recommendation` with an `authority` part (`by`, `pick` or null, `says`, the `source` page or the `searched` query that found none, and the date `read`) and an `agent` part (`pick` and `reason`).
  - A card with `dependsOn` has one recommendation for each answer that leaves more than one option.
  - Each kind of test lists its `roles` (test framework, mocking and so on), each with its own recommendation, and each tool names its role. The tools' `default` flags are gone.
  - The budget card keeps its `default` for an unanswered card, now with `defaultRule: ARC-012`.
- `Test-KitIntakeSource` fails when a card or role has no recommendation, or when a part of one is missing or picks something that isn't an option. `Get-KitIntake` refuses such a file, so `New-KitApp`, the skill and the tests all enforce it.
- How a default is picked: the developer's preference, then the authority's pick, then the agent's. One exception, the agent's: an authority's pick that's Paid is listed but not made the default, because ARC-012 starts every tool on its free option. The exception looks only at the Paid label: it doesn't weigh a Free tier that's free for non-commercial use only, or a budget above $0, which stay the plan's to weigh. A developer's preference for a Paid option is still theirs to state, and spending still needs the owner's OK (SEC-003).
- The bar for an authority's pick: the page recommends the tool, says it should be used, or gives it a guideline level (DO, CONSIDER). "You can use", "consider" as one way among several, a tool a page only uses, or a tool named as an example is no pick, and `says` reports what the page does say. `Test-KitIntakeSource` holds each pick's `says` to that wording, and refuses a pick whose words say there's none. Two picks meet the bar today: Package Validation ("CONSIDER enabling") and BenchmarkDotNet ("strongly recommended", on EF Core's benchmarking page).
- An agent's reason is its own: a license, a cost, what the kit's sample or CI already runs. It never cites an ADR that records the owner's preference (ADR-0003, ADR-0057); a test checks that.
- No preference is dropped in silence. One for a question the intake doesn't ask, or for the database with no data answer, comes back as an unused preference with a note.
- An unanswered kind of test gets the kit's defaults, authority then agent, with no developer file, so `New-KitApp` gives the same result on every machine. The skill writes every kind's tools into the answers with `Get-KitTestToolAnswer`, which carries the developer's picks.
- The agent's recommendation for assertions is AwesomeAssertions, free for any app. FluentAssertions stays on the list, and stays the owner's own pick through his preferences file (ADR-0003, ADR-0004).
- New `docs/preferences.md` describes the file. `docs/database-guide.md` labels its recommendations the same way, and a test checks that it agrees with the intake.
- The owner's file is seeded with the preferences he has stated, each with its date and source: the ADRs and ARC-012.
- Later work, already planned: moving the owner's preferences out of the kit's rules (`docs/standards/`, including `testing.md`'s note that load tests run Locust by default, and ARC-012's $0 budget), and letting an app's agents read the file while they plan.
- Also later, and not yet planned: the tool lists themselves are still the ones the owner chose (ADR-0003). The test framework role offers only xUnit, though Microsoft names MSTest, NUnit and TUnit too. Mocking offers only Moq, though Microsoft names NSubstitute. Adding them needs an ADR each (TST-005), so a new kit user can't pick them yet.

## Pillars affected

- **Operational Excellence:** every default says where it comes from, and a check keeps it so.
- **Security:** preferences stay out of every public repo, and the file has no place for secrets.
- **Cost Optimization:** a Paid authority pick never becomes a default unasked; prices stay sourced facts.

## Sources

- owner, 2026-11-15
- ADR-0003
- ADR-0033
- ADR-0058
- ARC-012
- https://learn.microsoft.com/aspnet/core/tutorials/choose-web-ui, retrieved 2026-11-15
- https://learn.microsoft.com/azure/architecture/guide/technology-choices/data-stores-getting-started, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/core/testing/, retrieved 2026-11-15
