# SharedHostChecks fixture

A public website whose one host is a small HTTP API: anyone may read it, so it sets no fallback authorization policy.
Its `admin` group requires authorization (mapped without a leading slash, with an any-method `feed` endpoint and a
`status` endpoint that allows anonymous callers again), and `/staff` requires it through requirement metadata alone.
Its FunctionalTests project compiles the kit's shared host checks (`tools/AppTests/Functional`) the way an app's does
(ADR-0081). `tools/tests/SharedHostChecks.Tests.ps1` copies it, with the kit's build files, into a scratch folder and runs its `AuthorizationTests`, `OpenApiDocumentTests` and `TokenTests`.

- As it is, most of its endpoints are public, so SEC-017's fallback policy doesn't apply: the authorization checks
  skip, and the document check looks only at the signed-in operations, which its document says require the Bearer
  scheme.
- With `KIT_FIXTURE_DOCUMENT=unprotected`, the site serves `openapi-unprotected.json`, where those operations don't
  require the Bearer scheme, and the document check fails, naming each.
- With `KIT_FIXTURE_DOCUMENT=public`, it serves `openapi-public.json`, which describes only the public operations and
  declares no Bearer scheme, and the document check passes.
- With `KIT_FIXTURE_SIGN_IN=true`, its `AppHost` part says most endpoints require sign-in, and the fallback check fails,
  because the site sets no fallback policy.
- As it is, it signs in the caller of any bearer token without checking the token, and its `AppHost` part says it signs
  users in and names `/staff` as its route. The token checks fail it for the unsigned token, the changed one and the
  one signed with a new key.
- With `KIT_FIXTURE_PUBLIC_ONLY=true` and `KIT_FIXTURE_SIGNS_USERS_IN=false`, it's a public website that signs nobody
  in, with only its home page and its document, and its `AppHost` part says so and names `/` as its route. The token
  checks skip.

The document is a fixed file rather than the built-in generator's, so a test can change what it says.
