# SharedHostChecks fixture

A public website with no sign-in, and a FunctionalTests project that compiles the kit's shared host checks
(`tools/AppTests/Functional`) the way an app's does (ADR-0081). `tools/tests/SharedHostChecks.Tests.ps1` copies it,
with the kit's build files, into a scratch folder and runs its `AuthorizationTests`.

- As it is, most of its endpoints are public, so SEC-017's fallback policy doesn't apply and both checks skip.
- With `KIT_FIXTURE_SIGN_IN=true`, its `AppHost` part says most endpoints require sign-in, and the fallback check fails,
  because the site sets no fallback policy.
