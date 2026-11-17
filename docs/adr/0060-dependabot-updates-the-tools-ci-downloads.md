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
- **Update (2026-11-16): Option 4 added, closing GAP-029** (in auto mode; owner, 2026-11-16: "Finish the free gaps"). The details follow.
  - **The key.** PMD's documentation publishes its release key: "PMD Release Signing Key <releases@pmd-code.org>", primary fingerprint `2EFA55D0785C31F956F2F87EA0B5CA1A4E086838`, signing subkey `1E046C19ED2873D8C08AF7B8A0632691B78E3422`. That page is on docs.pmd-code.org, not on GitHub, where the zip and its `.asc` are.
    - The public key came from keys.openpgp.org and keyserver.ubuntu.com, which gave the same key with that fingerprint. It is committed, in a minimal export, as `.config/pmd/pmd-release-key.asc`, and the fingerprint is pinned beside it in `pmd-release-key.fingerprint`. Its self-signature runs to 2028-01-04.
    - The 7.29.0 zip pinned today verified against it: a good signature by the subkey, with that primary key, and the zip's SHA-256 equal to the committed pin.
  - **The check.** The pin job downloads the zip and its `.asc`. `Set-PmdPin` then verifies them with the runner's gpg, in a keyring of its own that holds only the committed key.
    - It accepts exactly one signature result, a good one (not bad, expired or revoked), whose primary key is the pinned fingerprint. Then it requires the zip's own SHA-256 to equal GitHub's digest, and pins it.
    - The 7-day wait stays. CI's downloads still check the committed SHA-256, which now comes from a zip whose signature verified, so the Windows leg needs no gpg.
  - **A key change.** When PMD extends its key's expiry or replaces its key, the pin job fails, saying the zip isn't signed by the pinned key. A person then makes a pull request:
    1. Read PMD's signed-releases page for the new fingerprint, and the GitHub advisory if the change follows a compromise, as the earlier key's revocation did (GHSA-88m4-h43f-wx84).
    2. Fetch the key by that fingerprint from keys.openpgp.org and keyserver.ubuntu.com, and compare the two.
    3. Export it with `gpg --export --armor --export-options export-minimal <fingerprint>` over `pmd-release-key.asc`, and write the fingerprint file.
    4. Rerun the pin job.

    A key fetched from GitHub's release page is never trusted on its own. An expiry extension keeps the fingerprint, so only the key file changes.
  - Option 4's risk, a key to manage, is that procedure. The fixtures in `tools/tests/fixtures/PmdSignature/` are signed with two test keys made for the tests, not PMD's.

## Consequences

- `.github/dependabot.yml` gains a `maven` entry for `/.config/pmd` (7 days, 14 for a major) and a `docker` entry for `/.config/gitleaks` (7 days; Docker takes no semver-specific wait). GAP-023 is closed.
- `dotnet-ci.reusable.yml` holds no tool version or hash of its own. Both PMD downloads, the dotnet job's on Linux and the ui job's on Windows for an app with UI projects (ADR-0059), read the kit's pin and check the zip against its SHA-256. The secret scan job gets the kit through `kit-tools`, as the .NET job does. Its name, which the ruleset requires, is unchanged.
- An app needs nothing. Its CI runs the kit's workflow at its kit pin, which reads the kit's pins, and the app gets newer ones with each kit release (ADR-0045). `Export-KitApp` doesn't copy `.config/`, so an app's Dependabot never sees these manifests.
- A Dependabot maven PR carries two commits: Dependabot's pom change and the workflow's pin. To check the pin, compare it with the digest on the release page. A PR whose `pin-pmd` job failed (for example, a zip under 7 days old) gets its pin by running that job again once the cause is gone. That includes a Dependabot security update for PMD: it skips the cooldown, but `Set-PmdPin` still waits until the zip is 7 days old, so an urgent fix needs its job run again then, or a pin taken by hand from a verified download.
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
- https://docs.pmd-code.org/latest/pmd_userdocs_signed_releases.html, retrieved 2026-11-16 (PMD's release key, its fingerprints, the keyservers, and the earlier key's revocation)
- https://keys.openpgp.org/vks/v1/by-fingerprint/2EFA55D0785C31F956F2F87EA0B5CA1A4E086838, retrieved 2026-11-16
- https://www.gnupg.org/documentation/manuals/gnupg/Automated-signature-checking.html, retrieved 2026-11-16 (gpg's status lines, GOODSIG and VALIDSIG)
- ADR-0024, ADR-0041, ADR-0045, ADR-0051
