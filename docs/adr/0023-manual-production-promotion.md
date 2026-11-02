# ADR-0023: Approval before production through a manually started workflow

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The release pipeline deploys to staging, then to production after the owner approves (ADR-0019). GitHub's "required reviewers" for environments are only available for public repositories on the Free, Pro and Team plans, and the owner's repos are private and personally owned.

## Options

### Option 1: Staging deploys automatically; production is a separate workflow the owner starts by hand

- **Trade-offs:** The same control at no cost; the production workflow promotes the exact artifact staging received. One extra workflow, started from GitHub's Actions page or the `gh` command line.
- **Reversibility:** Easy. Switch to environment reviewers if the plan changes.
- **Risk:** Low.

### Option 2: Upgrade to a plan with environment reviewers on private repos

- **Trade-offs:** Built-in approval gates; costs money every month.
- **Reversibility:** Easy.
- **Risk:** Low, at a cost.

### Option 3: Deploy to production automatically after staging

- **Trade-offs:** Fastest; no human approval before production.
- **Reversibility:** Easy.
- **Risk:** High for anything with users.

## Recommendation

Option 1: it gives the approval step for free.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- The release workflow publishes artifacts and deploys to staging; a `workflow_dispatch` production workflow promotes the same artifact.
- Built with the release pipeline, after v0.1.

## Pillars affected

Reliability: a human checks staging before production. Cost Optimization: no paid plan needed.

## Sources

- owner, 2026-11-01
- https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments, retrieved 2026-11-01
