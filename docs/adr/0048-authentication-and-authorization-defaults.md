# ADR-0048: Authentication and authorization defaults for apps

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

GAP-006 in `docs/quality/scorecard.md`: apps got no rules for sign-in, access or input validation. The only guard was the threat model each plan writes (ARC-006). The sample's API answered every caller, and every caller saw every bookmark. Validation covered the list's query (API-006) but not the create request's body.

The owner set v0.1.0's scope on 2026-11-10: everything except what costs money. So the defaults can't need a paid service, a cloud resource or a real identity provider to build or test. They also have to work for the apps the kit expects, which are web apps and their HTTP APIs (ARC-001, API-001).

Microsoft Learn and OWASP agree on the shape:

- Microsoft: set a fallback policy that requires a signed-in user, so a new endpoint is never public by mistake. Create access tokens only through OpenID Connect or OAuth flows, never from a username and password. Validate every token's signature, issuer, audience and lifetime in the API.
- OWASP ASVS 5.0: V8 restricts every function and every data item to consumers with explicit permission (IDOR and BOLA), enforced at a trusted layer. V9 validates tokens. V2 validates input positively at a trusted layer. The OWASP API Security Top 10 (2023) ranks broken object-level authorization first.

## Options

### Option 1: OpenID Connect provider, JWT bearer, a fallback policy and owner-scoped data

The app never stores passwords or issues tokens. Users sign in with an OpenID Connect provider: Microsoft Entra ID, or Entra External ID for customer-facing apps. The API validates the provider's access tokens with `AddJwtBearer`, configured under `Authentication:Schemes:Bearer`. A fallback policy requires a signed-in user with a `sub` claim on every endpoint. Each user's data is filtered by that `sub` in the query. Development uses `dotnet user-jwts`, which keeps its key in user secrets. Tests issue RS256 tokens with a key made in memory, and the app's real handler validates them.

- **Trade-offs:** Account security (passwords, MFA, lockout, recovery) is the provider's job, and every check is the framework's own code, configured rather than written. The package is Microsoft's `Microsoft.AspNetCore.Authentication.JwtBearer`, which Learn names for this. The cost is that a real deployment needs a provider tenant and an app registration. That's the owner's step, and Entra ID has a free tier.
- **Reversibility:** Medium. Moving to another OpenID Connect provider changes configuration only. Moving to stored passwords would mean a user store and new endpoints.
- **Risk:** Low. A misconfigured authority or audience fails closed: every request gets 401, never a wrong yes.

### Option 2: ASP.NET Core Identity, with its own user store

The app keeps users and password hashes in its own database, and `MapIdentityApi` issues its bearer tokens.

- **Trade-offs:** No outside provider is needed, even in production. But the app now owns password storage, lockout, recovery email and MFA, which is the attack surface Option 1 hands to the provider. Microsoft's own JWT guidance warns against issuing access tokens from a username and password.
- **Reversibility:** Hard. Users' password hashes live in the app's database, and moving them out means a migration every user goes through.
- **Risk:** Medium. Each piece of account management the app owns is a piece it can get wrong.

### Option 3: Authorization endpoint by endpoint, with no fallback policy

Each endpoint, or group, calls `RequireAuthorization()`; everything else is public.

- **Trade-offs:** No change for public endpoints. But an endpoint that forgets the call is public, and nothing fails to say so.
- **Reversibility:** Easy.
- **Risk:** High. Being secure depends on remembering, every time. Microsoft calls the fallback policy the preferred way.

**For the tests,** the real handler with test-issued tokens, or a mocked one. Microsoft's integration-testing guide shows a `TestAuthHandler` that signs every request in. It's simple, but it replaces the very handler the rules depend on, so it can't show that an expired, foreign or unsigned token is refused. Letting the real handler trust one in-memory key, through the documented `JwtBearerOptions.TokenValidationParameters`, tests every check the app relies on. Only the key's source differs from production.

## Recommendation

Option 1, with the real handler in tests. Account security stays with a provider built for it, the framework does every check, and the tests prove each one.

## Decision

Pending: added in auto mode (ADR-0035). SEC-007 to SEC-010 stay `proposed` until the owner accepts them.

## Consequences

- New rules in `docs/standards/security.md`, all proposed:
  - SEC-007: authorization by default.
  - SEC-008: an OpenID Connect provider and JWT bearer.
  - SEC-009: each user's own data, filtered in the query.
  - SEC-010: bounded, validated input. API-006 still says how a Minimal API validates.
- The sample adopts all four:
  - `ApiSecurityExtensions` sets up JWT bearer and the fallback policy. The health endpoints and the Development OpenAPI document opt out.
  - `Bookmark` gets an owner, and the repository filters every query by it.
  - `CreateBookmarkRequest` gets validation attributes, with a new `UriLength` attribute, since `[MaxLength]` throws on a `Uri`.
  - The domain owns the title and URL limits, and the EF model uses them.
  - The OpenAPI document declares the bearer scheme and the 401 and 403 answers.
- The FunctionalTests prove every rule. Each rule is advisory in an app until the app follows the sample, as OPS-001 to OPS-003 are.
- Breaking for anyone running the sample locally:
  - Every call needs a token (`dotnet user-jwts create`).
  - The database gains an owner column. The sample creates its schema with `EnsureCreated`, so an old `bookmarks.db` has to be deleted. Safe migrations remain GAP-008.
- What gets harder: an app whose users share data (teams, sharing) can't stop at a filter by owner. It needs its own policy, in an ADR, with resource-based authorization.

## Pillars affected

- **Security:**
  - No endpoint is public by default.
  - Tokens are fully validated.
  - Each user reaches only their own data.
  - Input is bounded.
  - Signing keys stay out of the repo.
- **Reliability:** a broken identity configuration fails closed with 401s. The health probes stay anonymous, so the platform still sees a running app.
- **Cost optimization:** nothing paid. A real tenant is the owner's later call, and Entra ID has a free tier.
- **Operational excellence:** the handler logs authentication failures without the token. The README says how to get a local token.
- **Performance efficiency:** one signature check per request. The provider's keys are fetched once and cached.

## Sources

- owner, 2026-11-10 (v0.1.0 scope: everything except what costs money)
- https://learn.microsoft.com/en-us/aspnet/core/security/authorization/policies#require-global-user-authentication, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/security, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/aspnet/core/security/authentication/jwt-authn, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests#mock-authentication, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/customize-openapi#use-document-transformers, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/aspnet/core/fundamentals/validation, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/entra/identity-platform/id-token-claims-reference#use-claims-to-reliably-identify-a-user, retrieved 2026-11-11
- https://github.com/OWASP/ASVS/tree/v5.0.0/5.0/en (V2, V8, V9), retrieved 2026-11-11
- https://api-security.owasp.org/editions/2023/en/0xa1-broken-object-level-authorization, retrieved 2026-11-11
- https://openid.net/specs/openid-connect-core-1_0.html#IDToken (sub: at most 255 ASCII characters), retrieved 2026-11-11
