# ADR-0042: A curated copy of Microsoft's dotnet/skills, pinned to one commit

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

Microsoft's .NET team publishes agent skills in [dotnet/skills](https://github.com/dotnet/skills): "the .NET team's curated set of portable skills" for coding agents. They follow the [Agent Skills](https://agentskills.io) format the kit's own skills use (a folder with a `SKILL.md`). At commit `96c3d68` (2026-11-06) the repo holds 108 skills in 17 plugins, under `plugins/<plugin>/skills/<skill>/`. Each skill has a `SKILL.md`, and some add `references/`, `scripts/` or `assets/` folders. The repo is MIT-licensed, "Copyright (c) .NET Foundation and Contributors", and its `.gitattributes` stores text with LF line endings. Upstream suggests installing whole plugins from its marketplace (`/plugin install <plugin>@dotnet-agent-skills`), which then update on demand.

The owner chose on 2026-11-05 to "adopt a curated, pinned copy of dotnet/skills". These limits apply:

- **One skills folder.** Claude Code, Visual Studio and VS Code read `.claude/skills/<name>/SKILL.md`, and so does the Copilot coding agent (ADR-0021). Claude Code documents that path, one folder deep. Whether the tools also find a skill in a deeper folder, such as `.claude/skills/dotnet/<name>/`, isn't documented, so the copies use the documented path.
- **Apps get the kit's skills.** `Export-KitApp` copies everything under `.claude/skills/` into an app, and the app's `.kit/manifest.json` hashes each file (ADR-0032).
- **The listing budget.** Claude Code loads every skill's name and description into each session. It drops descriptions once the listing is over 1% of the model's context window, the least-invoked skills' first (code.claude.com/docs/en/skills, "Skill descriptions are cut short"). The kit's own six skills take 1,463 characters. All 45 upstream skills that fit the kit's stack would take about 30,000.
- **Kit rules.** Kit scripts must start with `#Requires -Version 7.6` (ADR-0040), and a shared skill mustn't send an agent to a kit-only `tools/` path (`AgentFiles.Tests.ps1`). Installing software is the owner's call (SEC-003), and so is adding a connector (SEC-004). When a skill and a kit rule disagree, the kit rule wins (AGENTS.md, "Whose rules win": the owner's rules outrank outside authorities).

## Options

### Option 1: Copy the chosen skills into `.claude/skills/`, unchanged, with a lock file that pins them

`tools/dotnet-skills.json` records the upstream repo, one commit SHA, the date it was retrieved and, for each chosen skill, its upstream path and git's blob id for every file. A Pester check fails when a copy differs from its recorded blob id, a file is missing, or a curated skill's folder has a file that upstream doesn't. `tools/Update-DotnetSkills.ps1` fetches a newer commit and rewrites both the copies and the lock.

- **Trade-offs:** It works offline, in every tool that reads `.claude/skills/`, and in every app with no extra step. Anyone can check the pin: the blob ids are the ones `git ls-tree` prints for that commit upstream. The kit picks what reaches agents and keeps the description budget. It also has to keep up: an update is a PR whose diff someone reads.
- **Reversibility:** Easy. Deleting the folders and the lock removes the skills, and the sync job removes them from apps the same way.
- **Risk:** Low. A changed copy fails CI. An upstream change waits until someone moves the pin and reads the diff.

### Option 2: A git submodule of dotnet/skills

- **Trade-offs:** git pins the commit by itself. But the tools' documented path is `.claude/skills/<name>/SKILL.md`, and a submodule puts all 108 skills under one folder of the submodule's own layout (`plugins/<plugin>/skills/<name>/`), so agents wouldn't see any of them without links or copies. Every clone needs `git submodule update --init`, the app export would need submodule support, and the whole repo comes along, with its scripts and the skills that conflict with kit rules.
- **Reversibility:** Medium. Removing a submodule touches `.gitmodules`, git config and every clone.
- **Risk:** Medium. No curation: the listing budget and the conflicting skills would need a second mechanism anyway.

### Option 3: Reference only: tell people to install upstream's marketplace plugins

- **Trade-offs:** No copy to maintain, and updates arrive on their own. But a plugin is installed per person and per tool, outside the repo: an app's agents get different skills on different machines, Visual Studio and the Copilot coding agent don't install Claude Code plugins, and installing a plugin is software the owner must approve each time (SEC-003). Updates arrive unreviewed, so a changed skill can change what agents do with no PR. A plugin brings every skill it has, the conflicting ones too.
- **Reversibility:** Easy.
- **Risk:** Medium to high. Nothing pins the content, and nothing checks it.

## Recommendation

Option 1: the copy is pinned and checked, reaches every tool and app through the folder they already read, and lets the kit choose skills that fit its rules and the listing budget.

## Decision

Accepted (owner, 2026-11-05: "Adopt a curated, pinned copy of dotnet/skills"). Which skills are in, the description budget and the lock file's format were decided in auto mode (ADR-0035) and are recorded in `docs/dotnet-skills.md`. The owner can change any of them.

## Consequences

- **Where they live:** each curated skill is a folder in `.claude/skills/`, next to the kit's own, under its upstream name. None of the upstream names clashes with a kit skill. The copies are never edited: a kit rule that disagrees wins at the rule level, and `docs/dotnet-skills.md` lists the known conflicts.
- **The pin:** `tools/dotnet-skills.json` holds the commit, the retrieval date and each file's blob id. `tools/tests/DotnetSkills.Tests.ps1` fails on any drift, and also checks that the selection doc and THIRD-PARTY-NOTICES.md name the same skills and commit.
- **Selection rules:** a skill is in when it fits the kit's stack and rules, is instructions only (no `scripts/`, because the kit's script checks would fail on it and agents would run third-party code), needs no file from a skill that's left out, and fits the budget.
- **The budget:** all project skill descriptions together stay at or under 8,000 characters. That's 1% of a 200,000-token context window at about four characters per token; the exact character budget Claude Code computes isn't verified. A test checks it. Adding a skill, kit or curated, may mean taking one out. The first selection is 10 curated skills, 6,181 characters.
- **Updates:** `./tools/Update-DotnetSkills.ps1` with no arguments moves to upstream's current `main`; `-Commit <sha>` picks a commit. It fetches with `git` (no GitHub sign-in), copies the listed skills, removes files that are gone upstream, rewrites the lock and leaves the kit's own skills alone. It changes nothing when a listed skill isn't at that commit, when one holds a symbolic link or submodule (which could point outside its folder), or when a curated copy has an edit it would overwrite. The update is a PR: read the diff (upstream text becomes agent instructions), update the pin in `docs/dotnet-skills.md` and the notices row (the script tests fail until both name the new commit) and rerun the checks. Adding or removing a skill means editing the lock's list, then running the script.
- **Apps:** they get the curated skills with the rest of `.claude/skills/`, kit-managed in the manifest, and the notice through THIRD-PARTY-NOTICES.md's kit block. They don't get the lock or the update script: the kit updates the skills, and the sync job (PR D3) brings them to apps.
- **Later:** upstream's "repository overlays" (`.agents/skill-overlays/<plugin>/<skill>.md`, piloted in its `dotnet-test` plugin for `run-tests` and two others) let a repo add its own conventions to a skill without editing it. The kit could use one to point `run-tests` at AGENTS.md's Commands table.

## Pillars affected

Reliability: a changed copy fails CI, and every tool and app sees the same files. Security: upstream text reaches agents only at a pinned commit, through a reviewed PR, and no third-party script is copied. Cost Optimization: the budget keeps the listing small, which every session pays for in tokens. Operational Excellence: one script moves the pin, and the lock says exactly what came from where. Performance Efficiency: a smaller listing leaves context for the work.

## Sources

- owner, 2026-11-05
- https://github.com/dotnet/skills/tree/96c3d68dad2855e3ab5178aa1a262789d86a1466, retrieved 2026-11-10
- https://code.claude.com/docs/en/skills, retrieved 2026-11-10
- https://agentskills.io, retrieved 2026-11-10
