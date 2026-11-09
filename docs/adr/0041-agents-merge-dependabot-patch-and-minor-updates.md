# ADR-0041: Agents merge Dependabot's patch and minor updates; versions wait before they're proposed

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

Dependabot opens a pull request each time something the kit depends on has a new version:
- NuGet packages;
- .NET tools in `.config/dotnet-tools.json`;
- the GitHub Actions the workflows use;
- the .NET SDK pin in `global.json`.

It checks weekly (SUP-008, ADR-0025). The first two, PRs 25 and 26 (2026-11-09), were reviewed by the `reviewer` agent and merged by an agent because the owner said so for those PRs.

Auto mode lets an agent merge only its own PR (ADR-0035, AGENTS.md "Working modes"), and a Dependabot PR isn't one. Without a rule, every bump waits for the owner. Dependabot also writes its own description, so DOD-004's template can't apply. DOD-006 answers that: the agent handling the PR posts the template's sections as a comment, tied to the head commit.

Two risks set the limits:
- **A version that changes behavior.** SemVer (major.minor.patch) promises that only a major version breaks things, but a minor or patch update can still change behavior. Tests, the coverage gate and mutation testing catch most of this.
- **A compromised release.** A hijacked package or Action that otherwise works normally passes every test. Waiting a few days before a version is even proposed gives others time to find and pull a bad release. Dependabot's `cooldown` option does that for version updates; security updates don't wait. An Action is the more sensitive case, because it runs inside CI with the repo's permissions.

The owner asked for more information, weighed four options, and chose Option C (2026-11-09).

## Options

### Option A: Keep it per PR

The owner says "merge it" for each Dependabot PR, as for PRs 25 and 26.

- **Trade-offs:** The owner sees every bump, at the cost of one or more interruptions a week. It does nothing about a compromised release.
- **Reversibility:** Nothing to undo.
- **Risk:** Bumps wait, and security fixes in them wait too.

### Option B: Agents merge patch and minor updates

The agent merges any Dependabot patch or minor update on the same conditions as its own PR, plus DOD-006's comment; majors stay the owner's.

- **Trade-offs:** Hands-off, but Actions bumps merge without the owner, and nothing guards against a compromised release.
- **Reversibility:** Easy: change "Working modes" and `finish-work` back.
- **Risk:** A compromised patch or minor release, Actions included, is merged as fast as it's proposed.

### Option C: Option B for NuGet, .NET tools and the SDK; a cooldown; majors and Actions stay the owner's

As Option B, but only for NuGet packages, .NET tools and the SDK. Every version update waits 3 days before Dependabot proposes it, and NuGet and SDK majors wait 7. Every major update and every GitHub Actions bump stays the owner's to merge.

- **Trade-offs:** Most bumps are hands-off, while the two riskiest kinds still reach the owner, and the wait covers what tests can't see. Fixes arrive a few days later.
- **Reversibility:** Easy: the cooldown is a few lines in `.github/dependabot.yml`, and the merge rights are text in "Working modes" and `finish-work`.
- **Risk:** A compromised release that nobody spots within 3 days still reaches a PR. The agent's review and the checks are then the last guard, as they would be for the owner.

### Option D: Cooldown only

Add the cooldown, and keep merging per PR.

- **Trade-offs:** Every version has had time to be caught, but every bump still interrupts the owner.
- **Reversibility:** Easy.
- **Risk:** As Option A, minus most compromised releases.

## Recommendation

Option C: it takes the routine bumps off the owner's plate while keeping majors and Actions, the riskiest kinds, his, and the cooldown covers what tests can't see.

## Decision

The owner chose Option C on 2026-11-09 ("Option C it is"), after asking for more information. He also accepted DOD-006.

## Consequences

- AGENTS.md "Working modes" lets an agent in auto mode merge a Dependabot PR for a patch or minor update of a NuGet package, a .NET tool or the .NET SDK. It does so on its own PR's conditions plus DOD-006's comment at the head commit. A major update, a GitHub Actions bump, or a PR mixing either with anything else stays the owner's. Review mode doesn't change: the owner merges every PR.
- The `finish-work` skill's step 5 says the same, and tells how to tell the update type from Dependabot's own PR: the title and the version change.
- `.github/dependabot.yml` gives every ecosystem `cooldown: default-days: 3`, and NuGet and the SDK `semver-major-days: 7`. The app template does the same for NuGet. `tools/tests/Dependabot.Tests.ps1` checks both.
- DOD-006 is accepted. DOD-004, AGENTS.md "Done means" (kit and app template), "Working modes" and `finish-work` steps 4 and 5 now point a bot's PR to it.
- This amends ADR-0035: auto mode's merge rights now include these Dependabot PRs, not only the agent's own.
- What gets harder: an agent must read the version change correctly. A grouped Dependabot PR, which bumps several packages, counts as major if any one bump is major. If the agent can't tell, the PR is the owner's.

## Pillars affected

- **Security:** the cooldown keeps most compromised releases out, and Actions bumps, which run with CI's permissions, stay with the owner.
- **Reliability:** majors, the updates allowed to break things, stay with the owner. The checks, the reviewer and mutation testing guard the rest.
- **Operational excellence:** routine updates no longer wait for the owner, so the kit stays current with less of his time.
- **Cost optimization, performance efficiency:** no change.

## Sources

- owner, 2026-11-09
- ADR-0035
- https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference, retrieved 2026-11-09
