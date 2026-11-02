---
name: tdd-cycle
description: Implement one behavior test-first. Write one failing test, commit it as red, make the suite pass, commit it as green, then refactor. Use for every change to production code, scripts or checks, one test-list item at a time.
---

# TDD cycle

Canon TDD (ADR-0018): take **one** item from the plan's test list at a time. Never convert the whole list into tests up front.

## Red

1. Write one test for the next item. Use the kit's tools: xUnit v3, Moq, FluentAssertions and friends for .NET (ADR-0003), Pester 6 for PowerShell.
2. Run it and confirm it **fails on an assertion**, for the reason you expect. A compile error, a missing function or a crash in the test itself isn't red yet. Add a stub with the right shape that returns the wrong answer, then rerun.
3. Commit only the test (and its stub), with the trailer in the final paragraph:

   ```text
   test: <the behavior, in plain words>

   TDD: red
   Co-Authored-By: ...
   ```

## Green

4. Write the simplest change that makes the **full** suite pass, not just the new test.
5. Commit it with the trailer `TDD: green`, again in the final paragraph. The subject is `feat:` or `fix:`.

## Refactor

6. With everything green, clean up: names, duplication, structure. Run the full suite before and after. Commit it as `refactor:` (no TDD trailer).
7. Go back to Red for the next item. When the list is empty, run `finish-work`.

## Notes

- A bug fix starts with a test that reproduces the bug (red), before any fix.
- If a test passes on its first run, it isn't testing what you think. Check it before moving on.
- Run `git log -1 --format='%(trailers:key=TDD,valueonly)'` to confirm git reads the trailer.
