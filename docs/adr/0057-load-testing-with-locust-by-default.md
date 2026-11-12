# ADR-0057: Load testing with Locust by default

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

The brief's test matrix (§6.7) lists performance tests with BenchmarkDotNet and leaves load testing "later", and scorecard GAP-012 says no app has load tests. The new-app intake (ADR-0058) shows the owner every kind of test with its tools, so load testing needs tools now. The owner asked that paid options stay on the list, labelled with their price, beside a free default.

A load test runs many simulated users against a deployed app and checks its response times. It needs a script that describes what users do and machines that generate the load.

## Options

### Option 1: Locust, run in GitHub Actions

Locust (MIT) describes users in Python and runs from one command. A workflow runs it on a GitHub-hosted runner.

- **Trade-offs:** Free: GitHub Actions costs nothing on a public repo (ADR-0033). The scripts are Python rather than C#, and one runner limits how much load it can make, which suits most of the owner's apps.
- **Reversibility:** Easy. A Locust script can also run on Azure Load Testing later, without rewriting it.
- **Risk:** Low.

### Option 2: Apache JMeter

JMeter (Apache-2.0) describes tests in XML plans, usually built in its own editor, and has samplers for databases (JDBC) and message queues (JMS).

- **Trade-offs:** Free, and the stronger choice when an app's load is mostly database or queue work. Plans are harder to review in a pull request than a script.
- **Reversibility:** Easy.
- **Risk:** Low.

### Option 3: Azure Load Testing

A managed Azure service that runs JMeter or Locust scripts from many engines.

- **Trade-offs:** Paid. In East US, $10 per resource per month, plus $0.15 per virtual user hour up to 10,000 and $0.06 after, with each run billed at least 10 virtual users per engine for at least 10 minutes (Azure Retail Prices API and the pricing page, 2026-11-11). How many virtual user hours the resource fee includes is not verified. A monthly virtual-user-hour limit on the resource stops tests at the cap. It needs a cloud resource, which is the owner's call (SEC-003).
- **Reversibility:** Easy: the scripts are the same as options 1 and 2.
- **Risk:** Low technically; the cost is what to watch.

### Option 4: NBomber

Load tests written in C#.

- **Trade-offs:** The tests are .NET code, like the rest of the app. But it's free only for personal use: any organization needs Business ($1,500 a year per company) or Enterprise ($2,500 a year) (nbomber.com/pricing, 2026-11-11).
- **Reversibility:** Moderate: its scenarios don't run on the other tools.
- **Risk:** Medium: an app that starts personal and becomes an organization's needs a paid license.

## Recommendation

Option 1 as the default, with options 2, 3 and 4 listed beside it, labelled with their cost: it's free, runs where the app's CI already runs, and its scripts move to Azure Load Testing if an app ever needs more load.

## Decision

Decided by the owner, 2026-11-11: Locust is the default, run in GitHub Actions at no cost; JMeter is the alternative for apps that need heavy database or queue load; Azure Load Testing is listed as Paid, charged per virtual user hour, with a monthly cap available; NBomber, if listed, is Paid for any organization's use.

## Consequences

- `templates/app-intake.json` lists the four under the "load" kind of test, with their licenses, labels and prices, and Locust as the default (ADR-0058). Its tests (`tools/tests/KitIntake.Tests.ps1`) pin this decision.
- TST-005's toolset names Locust for load tests.
- ADR-0062 (2026-11-12) runs Locust: the shared performance workflow load tests an app started in CI, against a budget. A load test of a deployed app waits for its deployment (GAP-015). The prices above go stale; check them again before an app chooses a paid option.

## Pillars affected

- **Performance Efficiency:** apps get a way to measure response times under load.
- **Cost Optimization:** a free default, and the price of every paid option in view.

## Sources

- owner, 2026-11-11
- https://learn.microsoft.com/en-us/azure/app-testing/load-testing/quickstart-create-run-load-test-with-locust, retrieved 2026-11-11
- https://prices.azure.com/api/retail/prices, retrieved 2026-11-11
- https://azure.microsoft.com/en-us/pricing/details/load-testing/, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/app-testing/load-testing/how-to-manage-usage-limits, retrieved 2026-11-11
- https://nbomber.com/pricing, retrieved 2026-11-11
