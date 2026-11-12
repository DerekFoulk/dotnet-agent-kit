# ADR-0060: Dependabot updates the tools the shared .NET CI downloads

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

`dotnet-ci.reusable.yml` fetches two tools itself, outside any package manager:
- **PMD** (ADR-0051), downloaded with curl from its GitHub release. The step pinned it by version and by SHA-256, taken from GitHub's digest for the release asset.
- **gitleaks** (ADR-0024), run as `docker run ghcr.io/gitleaks/gitleaks:<tag>@sha256:<digest>` inside a `run:` step.

Dependabot reads manifests, not workflow scripts, so it saw neither. Nothing told the kit when either tool released a new version, and no Dependabot alert could name a PMD advisory (GAP-023). The owner asked for both to be updated like everything else (owner, 2026-11-11).

Constraints:
- **Integrity must not get weaker.** Today the PMD zip is checked against a SHA-256 committed in the repo, so a zip replaced on the download server after the pin fails CI. The gitleaks image is pinned by digest.
- **No cooldown gets shorter** (ADR-0041): 7 days for every update.
- **Apps run the kit's workflow at their kit pin** (ADR-0030). Through `$/.github/actions/kit-tools`, the runner has the whole kit at that commit, so the pins can live in the kit and be read from `$KIT`.

What Maven Central has, checked 2026-11-11: `net.sourceforge.pmd:pmd-dist:7.29.0` as a jar, pom and sources, but **no `bin` zip**. The runnable zip is published only on the GitHub release. So a pom can carry PMD's version, but the zip still comes from GitHub, and its hash can't come from Central.

## Options

### Option 1: Manifests Dependabot reads; a workflow pins PMD's new hash on Dependabot's PR

- **PMD:** `.config/pmd/pom.xml` names one dependency, `net.sourceforge.pmd:pmd-dist`, and Dependabot's `maven` updater moves its version. `.config/pmd/pmd-dist-bin.zip.sha256` beside it holds one line in `sha256sum`'s format: the zip's SHA-256, two spaces, `pmd-dist-<version>-bin.zip`.
  - CI reads both through `tools/KitPmd.psm1`'s `Get-PmdPin`, downloads the zip and runs `sha256sum --check --strict` against the pin file. `Get-PmdPin` refuses a pin for another version than the pom names, so a version bump without its hash stops CI with a message that says so.
  - On Dependabot's maven PRs, a new `pin-pmd` job in `dependabot-lockfiles.yml` asks GitHub for the release of the pom's version (`gh api`) and writes the asset's digest with `Set-PmdPin`. It refuses a release without the zip, a zip without a SHA-256 digest, and a zip uploaded or changed under 7 days ago. It runs with a read-only token and uploads only the pin. The existing `push` job, which holds the write token and runs none of the PR's code, checks the pin's shape, commits it and approves CI, as it does for lock files.
- **gitleaks:** `.config/gitleaks/Dockerfile` is one `FROM ghcr.io/gitleaks/gitleaks:<tag>@sha256:<digest>` line, and Dependabot's `docker` updater moves the tag and the digest together. Nothing builds the file. The secret scan reads the FROM line, fails unless it names the image by both tag and digest, and runs that image.
- **Trade-offs:** Dependabot handles both tools, with integrity unchanged, at the cost of a few more files and a job.
  - Both tools get Dependabot PRs. Dependabot alerts now cover advisories filed against `pmd-dist` (the dependency graph reads the pom; it sees only the direct dependency, not PMD's own dependencies).
  - The hash is the same one a person copied by hand: GitHub's digest for the asset, committed in the PR where it can be read. The 7-day check on the asset matches the cooldown Dependabot applies to the version on Maven Central, which is timed by Central, not by GitHub.
  - Two more files under `.config/`, a module, and one more job. The `push` job now serves both kinds of PR, so there is still one place with the write token.
- **Reversibility:** easy. Delete the manifests and the job, and put the pins back in the workflow.
- **Risk:** low.
  - If PMD's release ever lacks a digest, the job fails and someone pins it by hand from a verified download.
  - If Dependabot's maven or docker updater can't read these folders, nothing breaks; the tools just stay where they are. The first scheduled run shows it.

### Option 2: Manifests only; pin PMD's hash by hand on each Dependabot PR

- **Trade-offs:** no new job. But every PMD PR fails CI until someone pushes the hash, which is the manual step GAP-023 set out to remove.
- **Reversibility:** easy.
- **Risk:** low, but PMD bumps wait on a person.

### Option 3: A scheduled workflow that checks PMD's and gitleaks's releases and opens an issue

- **Trade-offs:** no manifests. But it rebuilds what Dependabot does, without its PRs, cooldown or alerts, and it's one more scheduled workflow to keep running (GitHub turns off scheduled workflows in quiet repos).
- **Reversibility:** easy.
- **Risk:** medium. No advisory alerts, and a notice instead of a PR.

### Option 4: Option 1, plus checking the zip's signature against PMD's release key

PMD publishes a `.asc` signature for each zip. Checking it against a pinned key fingerprint would detect a zip replaced before the pin was taken, which a hash taken from the same server can't.
- **Trade-offs:** stronger than today's guarantee, not just equal to it. But the kit would pin and rotate a third party's signing key, install gpg in CI, and handle a key change on a PMD release.
- **Reversibility:** easy.
- **Risk:** low, at the cost of a key to manage.

## Recommendation

Option 1: Dependabot proposes both tools on its usual schedule with its usual wait, and integrity stays exactly where it was. Option 4 is stronger, and can be added to Option 1 later without undoing it.

## Decision

Option 1, decided in auto mode (ADR-0035) on 2026-11-11, at the owner's request.

- Merging a PMD or gitleaks update stays the owner's: ADR-0041 lets agents merge only NuGet, .NET tool and SDK updates.
- Option 4 waits, as GAP-029: today's guarantee is kept, not lowered, and the signature check adds a third party's key to pin and rotate. Revisit it if a PMD release key is published somewhere the kit already trusts, or if a pin ever has to be taken from an unverified source.

## Consequences

- `.github/dependabot.yml` gains a `maven` entry for `/.config/pmd` (7 days, 14 for a major) and a `docker` entry for `/.config/gitleaks` (7 days; Docker takes no semver-specific wait). GAP-023 is closed.
- `dotnet-ci.reusable.yml` holds no tool version or hash of its own. The secret scan job gets the kit through `kit-tools`, as the .NET job does. Its name, which the ruleset requires, is unchanged.
- An app needs nothing. Its CI runs the kit's workflow at its kit pin, which reads the kit's pins, and the app gets newer ones with each kit release (ADR-0045). `Export-KitApp` doesn't copy `.config/`, so an app's Dependabot never sees these manifests.
- A Dependabot maven PR carries two commits: Dependabot's pom change and the workflow's pin. To check the pin, compare it with the digest on the release page. A PR whose `pin-pmd` job failed (for example, a zip under 7 days old) gets its pin by running that job again once the cause is gone.
- ADR-0051's "Download PMD" now reads the kit's pin; ADR-0024's image pin moves to the Dockerfile.

## Pillars affected

- **Security:** both tools get new versions and advisory alerts on Dependabot's schedule. Each download is still checked against a hash or digest committed in the repo.
- **Operational excellence:** no hand-kept pin in a workflow; a version bump without its hash stops CI with a message that says what to do.
- **Reliability, cost, performance:** no change. The pin job runs only on Dependabot's maven PRs, for a few seconds.

## Sources

- owner, 2026-11-11 (PMD and gitleaks are the only tools Dependabot doesn't update; fix it)
- https://repo1.maven.org/maven2/net/sourceforge/pmd/pmd-dist/7.29.0/, retrieved 2026-11-11 (jar, pom, sources; no bin zip)
- https://github.com/pmd/pmd/releases/tag/pmd_releases%2F7.29.0, retrieved 2026-11-11 (the zip, its digest and its signature)
- https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference, retrieved 2026-11-11 (cooldown: semver-*-days not supported for Docker)
- https://docs.github.com/en/rest/releases/releases#get-a-release-by-tag-name, retrieved 2026-11-11
- ADR-0024, ADR-0041, ADR-0045, ADR-0051
