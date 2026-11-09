# ADR-0041: Agents merge Dependabot's patch and minor updates; versions wait before they're proposed

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

Dependabot opens a pull request each time something the kit depends on has a new version:
- NuGet packages;
- .NET tools in `.config/dotnet-tools.json`;
- the GitHub Actions the workflows use;
- the .NET SDK pin in `global.json`.

It keeps them current (SUP-008, ADR-0025), checking weekly as `.github/dependabot.yml` schedules it. The first two, PRs 25 and 26 (2026-11-09), were reviewed by the `reviewer` agent and merged by an agent because the owner said so for those PRs.

Auto mode lets an agent merge only its own PR (ADR-0035, AGENTS.md "Working modes"), and a Dependabot PR isn't one. Without a rule, every bump waits for the owner. Dependabot also writes its own description, so DOD-004's template can't apply. DOD-006 answers that: the agent handling the PR posts the template's sections as a comment, tied to the head commit.

Two risks set the limits:
- **A version that changes behavior.** SemVer (major.minor.patch) promises that only a major version breaks things, but a minor or patch update can still change behavior. Tests, the coverage gate and mutation testing catch most of this.
- **A compromised release.** A hijacked package or Action that otherwise works normally passes every test. Waiting a few days before a version is even proposed gives others time to find and pull a bad release. Dependabot already waits 3 days before proposing a version update, even when `cooldown` isn't configured. Its `cooldown` option sets other waits, in general or for majors alone. Security updates never wait. An Action is the more sensitive case, because it runs inside CI with the repo's permissions.

The owner asked for more information, weighed four options, and chose Option C (2026-11-09).

## Options

### Option A: Keep it per PR

The owner says "merge it" for each Dependabot PR, as for PRs 25 and 26.

- **Trade-offs:** The owner sees every bump, at the cost of one or more interruptions a week. Against a compromised release, it has only Dependabot's default 3-day wait.
- **Reversibility:** Nothing to undo.
- **Risk:** Bumps wait, and security fixes in them wait too.

### Option B: Agents merge patch and minor updates

The agent merges any Dependabot patch or minor update on the same conditions as its own PR, plus DOD-006's comment; majors stay the owner's.

- **Trade-offs:** Hands-off, but Actions bumps merge without the owner, and only Dependabot's default 3-day wait guards against a compromised release.
- **Reversibility:** Easy: change "Working modes" and `finish-work` back.
- **Risk:** A compromised patch or minor release, Actions included, that nobody spots within 3 days is merged as soon as it's proposed.

### Option C: Option B for NuGet, .NET tools and the SDK; a cooldown; majors and Actions stay the owner's

As Option B, but only for NuGet packages, .NET tools and the SDK. Every major update and every GitHub Actions bump stays the owner's to merge. `.github/dependabot.yml` states the 3-day wait Dependabot applies anyway, so a test guards it, and makes NuGet and SDK majors wait 7. (The owner later lengthened both waits; see the Decision.)

- **Trade-offs:** Most bumps are hands-off, while the two riskiest kinds still reach the owner. Its real gain over Option B is keeping Actions bumps with the owner: the 3-day wait applies under every option, and only majors, which the owner merges, wait longer.
- **Reversibility:** Easy: the cooldown is a few lines in `.github/dependabot.yml`, and the merge rights are text in "Working modes" and `finish-work`.
- **Risk:** A compromised release that nobody spots within 3 days still reaches a PR. The agent's review and the checks are then the last guard, as they would be for the owner.

### Option D: Cooldown only

State the cooldown, with 7 days for majors, and keep merging per PR.

- **Trade-offs:** As Option A, with majors waiting longer; every bump still interrupts the owner.
- **Reversibility:** Easy.
- **Risk:** As Option A.

## Recommendation

Option C: it takes the routine bumps off the owner's plate while keeping majors and Actions, the riskiest kinds, his.

## Decision

The owner chose Option C on 2026-11-09 ("Option C it is"), after asking for more information. He also accepted DOD-006.

**Correction (2026-11-09):** the options as first shown to the owner said the cooldown added a wait. Review 1 of PR 33 found that Dependabot already waits 3 days by default, which the options above now say. The owner was told in the chat, with a recommendation to wait longer: security updates never wait, so a longer wait only delays routine updates, and it gives a bad release more time to be caught before an agent merges it. He chose 7 days for every version update, and 14 for NuGet and SDK majors ("Yes, 7 and 14", 2026-11-09).

## Consequences

- AGENTS.md "Working modes" lets an agent in auto mode merge a Dependabot PR for a patch or minor update of a NuGet package, a .NET tool or the .NET SDK. It does so on its own PR's conditions plus DOD-006's comment at the head commit. A major update, a GitHub Actions bump, or a PR mixing either with anything else stays the owner's. Review mode doesn't change: the owner merges every PR.
- The `finish-work` skill's step 5 says the same, and tells how to tell the update type from Dependabot's own PR: the title and the version change. A minor of a 0.x package counts as a major, since SemVer lets it break anything. For the SDK, a new feature band (10.0.403 → 10.0.500) is a minor. The PR must change only the manifests and lock files, in commits by Dependabot or the lock-file workflow. The agent reads the new version's release notes and checks its license and deprecation status; a license change, new telemetry or new build-time behavior makes the PR the owner's. The `reviewer` agent checks the same.
- Shortening the cooldown in `.github/dependabot.yml` joins the guardrails, so an agent can't loosen the wait and merge that change itself.
- `.github/dependabot.yml` gives every ecosystem `cooldown: default-days: 7`, and NuGet and the SDK `semver-major-days: 14`. The app template does the same for NuGet. `tools/tests/Dependabot.Tests.ps1` checks both.
- DOD-006 is accepted. DOD-004, AGENTS.md "Done means" (kit and app template), "Working modes" and `finish-work` steps 4 and 5 now point a bot's PR to it.
- This amends ADR-0035: auto mode's merge rights now include these Dependabot PRs, not only the agent's own.
- What gets harder: an agent must read the version change correctly. A grouped Dependabot PR, which bumps several packages, counts as major if any one bump is major. If the agent can't tell, the PR is the owner's.

## Pillars affected

- **Security:** the 7-day wait, more than twice Dependabot's default and tested, keeps most compromised releases out; an agent reads each new version's release notes and license before merging; and Actions bumps, which run with CI's permissions, stay with the owner.
- **Reliability:** majors, the updates allowed to break things, stay with the owner. The checks, the reviewer and mutation testing guard the rest.
- **Operational excellence:** routine updates no longer wait for the owner, so the kit stays current with less of his time. They arrive a week after release, and majors two; a security update doesn't wait.
- **Cost optimization, performance efficiency:** no change.

## Sources

- owner, 2026-11-09
- ADR-0035
- https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference, retrieved 2026-11-09
