# Corrections log

Every time the owner has to step in and correct an agent, it's logged here with what it became (success criterion S6). Within one kit release, a correction becomes a check, a rule, a skill or an ADR, or it's rejected with a reason. Practice-task runs tag each correction with one of the eight themes from brief §1.

| Date | Theme | What happened | Became | Status |
|---|---|---|---|---|
| 2026-11-02 | "Done" reported before it was verified | The agent pushed review fixes to PR 2's branch and reported them as awaiting review, without checking the PR's state. The owner had already merged it, so the fixes never reached `main`, and the thread replies said "Fixed". | A step in the `finish-work` skill: read the PR's current state (`gh pr view --json state`) before pushing to its branch or reporting on it; if it's merged, carry new commits to `main` in a new PR (build step 3). The fixes went to `main` through a follow-up PR. | Open until build step 3 |
