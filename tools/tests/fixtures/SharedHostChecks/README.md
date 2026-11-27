# SharedHostChecks fixture

A public website whose one host is a small HTTP API: anyone may read it, so it sets no fallback authorization policy,
and only `POST /admin/notices` requires authorization. Its FunctionalTests project compiles the kit's shared host
checks (`tools/AppTests/Functional`) the way an app's does (ADR-0081). `tools/tests/SharedHostChecks.Tests.ps1` copies
it, with the kit's build files, into a scratch folder and runs its `AuthorizationTests` and `OpenApiDocumentTests`.

- As it is, most of its endpoints are public, so SEC-017's fallback policy doesn't apply: the authorization checks
  skip, and the document check looks only at the notices operation, which its document says requires the Bearer
  scheme.
- With `KIT_FIXTURE_DOCUMENT=unprotected`, the site serves `openapi-unprotected.json`, where that operation doesn't
  require the Bearer scheme, and the document check fails.
- With `KIT_FIXTURE_SIGN_IN=true`, its `AppHost` part says most endpoints require sign-in, and the fallback check fails,
  because the site sets no fallback policy.

The document is a fixed file rather than the built-in generator's, so a test can change what it says.
