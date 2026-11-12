# ADR-0051: PMD's copy-paste detector finds duplicate C# code in CI

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

CRF-003 says every piece of knowledge has one authoritative source. It's about knowledge, not text: code that only looks alike but changes for different reasons stays apart. No tool checked it, so it rested on the reviewer agent (GAP-020).

A tool can't see knowledge. It can see repeated code, and a long enough repeat is usually knowledge kept twice: a rule, a mapping or a calculation copied rather than shared. Short repeats are mostly look-alike code: argument checks, small test arrangements, property lists. So the tool's job is the first kind, and the reviewer's is the judgement.

What exists, free:
- **PMD's CPD** (copy-paste detector). It is BSD-style licensed, with releases on GitHub and a C# tokenizer. It has options to ignore using directives, attributes (`--ignore-annotations`) and runs of literals (`--ignore-literal-sequences`, for data tables). It writes an XML report, and `// CPD-OFF` and `// CPD-ON` comments exclude a region. It needs Java. For C#, it can't ignore identifiers or literals generally (those options are for Java and C++), so a renamed copy isn't found.
- **jscpd** (MIT) is a Node tool covering many languages with token-based detection. It needs Node, which the runner has. Its C# support is a generic tokenizer, with no C#-specific ignore options.
- **SonarQube's duplication measure** needs a Sonar server or SonarCloud: free for public repos only, and an account and a service the kit doesn't otherwise use.

Measured on the kit's own solution in CI on PR 49: see "Measurement" below.

## Options

### Option 1: PMD CPD in the shared .NET workflow, at 100 tokens

`tools/Test-Duplication.ps1` takes the hand-written C# files from the code shape tool (`Kit.CodeShape --files`, ADR-0050), so generated code is skipped by one rule in one place. It runs `pmd cpd --language cs --minimum-tokens 100 --ignore-usings --ignore-annotations --ignore-literal-sequences --file-list <files> --format xml --report-file <report> --no-fail-on-violation --no-fail-on-error` (when the solution has no C# file, it runs no CPD) and prints each place a repeat occurs in MSBuild's error format, naming the other places.

`dotnet-ci.reusable.yml` downloads PMD 7.29.0 from its GitHub release. It checks the zip's SHA-256 against GitHub's digest for the asset, as the same workflow pins the gitleaks image by digest, and runs the script with the runner's Java.

- **Trade-offs:** the C#-aware tokenizer and ignore options fit what CRF-003 asks.
  - The pinned, hash-checked download adds no package to the solution. But Dependabot can't see the version, so a newer PMD is a manual bump of two lines.
  - The tokenizer doesn't know some newer C#: a raw string literal (`"""..."""`, C# 11) stops it with a lexical error. CPD runs with `--no-fail-on-error`, so it skips such a file, and the script prints a warning for each one at the place CPD stopped. Those files aren't checked; the reviewer covers them.
  - Apps can't run it locally without Java and PMD (GAP-022).
- **Reversibility:** easy. Two CI steps and one script.
- **Risk:** low. A false finding goes between `CPD-OFF` and `CPD-ON` with its reason.

### Option 2: jscpd

- **Trade-offs:** an npm package, so it needs a lock file or an `npx` pin and Node in CI. It has no C#-specific options, so `using` blocks and attribute lists count as code, and the threshold must be higher to avoid look-alike hits.
- **Reversibility:** easy.
- **Risk:** medium. More noise for C#.

### Option 3: Keep it with the reviewer

- **Trade-offs:** no new tool, but GAP-020 stays open and a long copy can pass a tired review.
- **Reversibility:** n/a.
- **Risk:** duplication grows unnoticed.

## Recommendation

Option 1: the only free tool with a C# tokenizer and C#-specific ignores, run where the other gates run.

## Decision

Option 1, decided in auto mode (ADR-0035) on 2026-11-11, at the owner's request to close the open scorecard gaps.

**Tuning, for knowledge rather than looks:**
- **100 tokens.** By estimate, not measurement, about 10 to 15 lines of ordinary C#: long enough that a repeat is rarely an accident of style.
- **Ignore using directives, attributes and runs of literals.**
  - Usings are bookkeeping.
  - Attributes repeat by design (`[Fact]`, `[InlineData]`).
  - Runs of literals are data, such as test cases and lookup tables.
- **Hand-written files only**, as the code shape check reads them.
- **Not tuned away:** tests. A copied arrangement of 100 tokens is a missing helper, which CRF-003 counts too.

**Exceptions:** code that looks alike but changes for different reasons, which CRF-003 keeps apart, goes between `// CPD-OFF <reason>` and `// CPD-ON`. The reason is checked by the reviewer (CRF-001), as for any suppression.

## Measurement

PR 49's CI, on the kit's own solution (run 43139481712, commit `09ae97c`):
- **Duplicates at 100 tokens:** none, in 52 files.
- **Files skipped:** 6, each one a test file with a raw string literal (`"""` or `$$"""`). One is the sample's `BookmarksApiTests.cs`; five are the code shape tool's own tests. Each skip shows as a warning annotation.
- **Not measured:** shorter thresholds. 100 is a starting point, not a tuned optimum. If it lets a real copy through, or flags look-alike code, a later ADR can move it with evidence from the apps.

The first run, before `--no-fail-on-error`, stopped with exit code 5 on the same 6 files.

## Consequences

- Every app's CI runs the check after the code shape check, using the runner's Java (preinstalled on `ubuntu-latest`, and on `windows-latest`, where an app with UI projects runs it, ADR-0059).
- PMD's version and SHA-256 sit in one place, the workflow-level `env` of `dotnet-ci.reusable.yml`, which both "Download PMD" steps read (the Windows one runs for an app with UI projects, ADR-0059). Bumping PMD means updating both, from the release's asset digest. Dependabot can't see a download, so nothing yet tells the kit when PMD releases or has an advisory (GAP-023).
- CPD finds repeated code, not repeated knowledge. A rule stated in two shapes passes, and so does duplication in docs, config and scripts. The reviewer agent still checks those (CRF-003's enforcement says so).
- A file CPD can't read isn't checked: the CI log and the PR name each one, and the reviewer covers it. A later PMD release may read raw string literals; bumping PMD is the time to look.
- GAP-020 is closed. GAP-022 now also covers running this check on an app's own machine.

## Pillars affected

- **Operational excellence:** one more gate in CI, annotated on the PR.
- **Reliability:** knowledge kept once is changed once.
- **Security:** a downloaded executable, pinned to a version and checked against its published SHA-256 before it runs.
- **Cost:** about 13 seconds of CI per run on the kit, from the download to the summary (run 43139481712); no licence.
- **Performance:** none.

## Sources

- owner, 2026-11-11 (close the open scorecard gaps)
- CRF-003; ADR-0050
- https://docs.pmd-code.org/latest/pmd_userdocs_cpd.html, retrieved 2026-11-11 (options, exit codes, CPD-OFF and CPD-ON)
- https://docs.pmd-code.org/latest/pmd_userdocs_cpd_report_formats.html, retrieved 2026-11-11 (the XML report)
- https://github.com/pmd/pmd/releases/tag/pmd_releases%2F7.29.0, retrieved 2026-11-11 (the release and its asset digest)
