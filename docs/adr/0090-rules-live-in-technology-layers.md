# ADR-0090: Rules live in technology layers, each source in its own file, each rule with a strength

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

The owner on 2026-11-18 asked for two things.

- **Rules kept apart by where they come from:** "The Microsoft rules and my personal preferences (again) should not be conflated in any way. Clear delineation, please."
- **Rules organized by meaning:** "I kind of want to organize/separate general C# rules (for example) that should/will be enforced in all of our supported projects. Organizations/semantics are important to me. Conventions that are intuitive."
- **A catalog, not a waiting list:** "I am just seeing our efforts here as an opportunity to create a repository of rules/recommendations/suggetions, etc. Why are these rules 'proposed' and not just rules?" He then approved strength levels in place of "proposed" ("Yes, add them").

After PR 1 (ADR-0082 to ADR-0088), the rules are organized like this:

- **Files:** 293 rules in force or proposed, in 19 topic files in `docs/standards/` (code-style, security, data and the rest), plus one retired rule. The ID prefix follows the file (STY, SEC, DAT and so on).
- **Source:** each rule's `basis` says where it comes from. Of the 293, 175 are `authority` (a quoted page) and 118 are `preference`.
- **Mixed files:** 10 of the 19 files hold both kinds. For example, code-style.md has 5 authority and 13 preference rules, and security.md has 10 and 15. So a reader can't tell from a file what kind of rule it holds.
- **Two kinds of preference:** `preference` lumps together two different things:
  - the kit's method, which its guarantees depend on: TDD, Git, review, the definition of done;
  - the owner's own taste, which another developer may reasonably choose differently: CRF-011's limits, the rule of ten, `var` style, test libraries.
- **Scope:** `scope` is `core` or a list of app types (web-api, blazor, maui). "Core" holds 168 rules, from C# naming to Git rules to Azure SQL guards. "General C# rules" have no home of their own: they're spread across csharp.md, code-style.md and craft.md.
- **Status mixes two questions.** `status` is `accepted`, `proposed` or `retired`. ADR-0002 makes everything an agent adds `proposed` until the owner accepts it, and AGENTS.md says a proposed rule isn't in force. At PR 1's head (ed0ae5c), 163 of the 293 are proposed: 138 `authority` rules and 25 `preference` rules. The 138 quote their source word for word, and the quote check finds every quote on its page. So they're proposed only because an agent typed them up, not because their content is in doubt. Meanwhile `status` says nothing about how strongly a rule applies, though the sources themselves say it. Microsoft's Framework Design Guidelines prefix each guideline with `Do`, `Consider`, `Avoid` or `Do not`, and RFC 2119 defines MUST, SHOULD and MAY for requirement texts.

The kit hasn't released v0.1.0, and no app depends on a rule ID yet. Changing the layout or the IDs is cheapest now.

## Options

### Option 1: Technology layers, with each rule source in its own file (recommended)

- **Layers instead of `core`.** A layer is the technology a rule is about: `csharp`, `dotnet`, `aspnetcore`, `efcore`, `blazor`, `web-api`, `maui`, and cross-cutting ones where an authority isn't tied to one framework: `web` (OWASP, HTTP API design), `ui` (WCAG) and `github` (Actions, Dependabot, rulesets).
- **The app types map to layers.** `docs/standards/app-types.yml` maps each app type to its layers, for example `web-api: [csharp, dotnet, aspnetcore, web, github, web-api]`. A choice in the app's profile adds a layer: EF Core adds `efcore`, so a MAUI app on sqlite-net doesn't get EF Core's rules. A future WPF type lists `[csharp, dotnet, github, ui, wpf]` and gets the C# and .NET rules without anyone copying them.
- **A rule that spans two layers** lives in the more specific one and is tagged with the other. For example, an EF Core rule that holds only in ASP.NET Core apps (a DbContext per request) goes in `efcore`, tagged `aspnetcore`, and an app gets it only when it has both layers. The tag is a field (`also: [aspnetcore]`), which Test-RuleSources checks names a real layer.
- **One folder per layer, one file per source.** The authority rules go in `docs/rules/<layer>/authority.md`, and the kit's method in `docs/rules/<layer>/kit.md`. Rules that belong to no technology, such as Git, the definition of done and communication, go in `docs/rules/method/`. The owner's taste leaves the kit's rules altogether, for the preferences file (the next ADR). A file holds one source, and a check fails one that doesn't.
- **IDs stay as they are** (amended by the owner on 2026-11-25; see decision 2). A rule keeps its ID for life when it moves to its layer's file: SEC-017 lives in `docs/rules/aspnetcore/authority.md` and is still SEC-017. The prefix keeps saying the rule's topic (SEC, DAT, STY, CRF and so on), which is how the scorecard groups rules; the folder says its technology layer. A new rule takes the next free number for its topic. A retired rule's ID is never reused. Nothing outside `docs/rules/` changes for the move: no rename map, no grace period, no rewritten references.
- **Each rule has a strength, in place of "proposed".** A new `strength` field says how strongly a rule applies, and `status` keeps only `accepted` and `retired`.

  | Strength | Taken from the source's wording | A gate on it | The reviewer |
  |---|---|---|---|
  | `must` | DO, DO NOT, MUST, MUST NOT, never, required; OWASP ASVS's "Verify that"; added at the build, for the owner's yes on its pull request: SHALL, and "always" as an instruction ("Always dispose..."), the opposite of "never" | fails the PR | ranks a breach Blocking |
  | `should` | CONSIDER, AVOID, SHOULD, SHOULD NOT, recommended, prefer; added at the build: a plain imperative ("Use X") on a page of recommendations | warns on the PR | ranks a breach Should fix |
  | `consider` | MAY, can, optionally, and tips | none: the rule is advice in the agent's instructions | ranks it Consider |

  - **Authority rules take their strength from their own quote,** so they're in force once the quote check passes, with no wait on the owner. A check fails a `must` whose quote holds no must-word, so an agent can't make a source sound stricter than it is. Where a page's wording is weaker than the kit wants, the rule keeps the page's strength, and a kit rule says what the kit adds ("authority" says only what the page says, owner 2026-11-17).
  - **The kit's own additions start at `should`.** An agent can add one, and it warns, so it's visible on every PR. Only the owner moves one to `must`, which records his name and date in `ratified`. That keeps ADR-0002's safeguard: no agent can write a rule that fails an app's CI.
  - **The owner's taste** is in his preferences file (the next ADR), where each preference takes a strength of his choosing.
  - **ADR-0089's mechanism carries over.** Its `Write-RuleFinding` warns or fails by status. Here it reads strength, so `Get-RuleStatus` becomes `Get-RuleStrength`, and its tests change with it.
- **Generated output in sections.** Each agent's rule files are generated in sections:
  1. "Microsoft Learn and other authorities", one subsection per layer;
  2. "The kit's method";
  3. "Your preferences".

  Each line is tagged with its origin, for example `[Microsoft Learn: ASP.NET Core]`, `[OWASP]`, `[kit]` or `[your preference]`, and a line a preference overrides is shown with the override.
- **The scorecard stays topical.** Quality areas such as Security and Tests stay the scorecard's view, listing rules from any layer. Layers are where a rule lives; areas are how good an app is.
- **Trade-offs:** gains and costs.
  - Gains: "where does a C# rule go" has one answer, and an app's rules are the union of its layers. A new app type is a list of layers plus its own. Source and topic never mix in a file.
  - Costs: every rule moves to a new file. A cross-cutting concern such as security is split across layers (web, aspnetcore, efcore), so security rules no longer sit in one file. The scorecard's Security area still gathers them, and the IDs' topic prefixes still say which rules are security rules.
- **Reversibility:** easy. Only files move; every ID and every reference to one stays.
- **Risk:** low. Paths that name `docs/standards/` change, and the existing checks find any missed one.

### Option 2: Keep the topic files and split each by source

- Each topic file splits in two, `security.authority.md` and `security.kit.md`, and the owner's taste moves to the preferences file. `scope` becomes `layers: [csharp, aspnetcore]`, a list of tags with the same names as Option 1's layers, and app-types.yml maps app types to layers the same way.
- **Trade-offs:** gains and costs.
  - Gains: IDs stay as they are, so nothing outside docs/standards changes except what `scope` becomes. A topic's rules stay in one place, which suits a reviewer reading "everything about security".
  - Costs: "general C# rules" are still spread over csharp, code-style and craft. Each is tagged `csharp`, but nothing groups them. A rule's home is its topic, and its layer is a tag the reader must look for. That falls short of the owner's "organize/separate general C# rules".
- **Reversibility:** easy.
- **Risk:** low, but the owner's semantic ask is only partly met.

### Option 3: Organize by publisher

- `docs/rules/microsoft-learn/<doc set>/`, `docs/rules/owasp/`, `docs/rules/w3c/` and so on, mirroring `docs/inventory/`, plus `docs/rules/kit/`.
- **Trade-offs:** gains and costs.
  - Gains: the source is the folder, so it can't be mixed by construction. A page re-read maps straight to a folder.
  - Costs: what applies to my app becomes a question of publishers, not technologies. OWASP's rules apply to web-api and blazor, and Microsoft Learn's .NET doc set holds C#, libraries and hosting together. An app type would list publishers and doc sets, which is less intuitive than technologies.
- **Reversibility:** medium.
- **Risk:** medium. A publisher that covers several technologies needs tags anyway, so it ends up as Option 1 or 2 with a different folder name.

## Recommendation

Option 1. It's the only one that gives "general C# rules" a home of their own, keeps every file to one source, and lets a new app type pick up shared rules by listing layers. Keeping every ID means no reference anywhere changes.

## Decision

Approved by the owner: Option 1, with all eight recommendations below (decision 8: "Yes to both") ("Approve all six" for 1 to 6, "Yes, add them" for 7). Each question, with the recommended answer he approved:

1. **Layers and their names.** Take the list above: csharp, dotnet, aspnetcore, efcore, blazor, web-api, maui, web, ui, github, plus `method` for the kit's own rules. Recommended: yes, since each is a technology a developer already knows by that name.
2. **IDs stay as they are.** Approved on 2026-11-18 as "renumber by layer, with a rename map", then reversed by the owner on 2026-11-25 ("Keep the IDs") on the agent's revised recommendation. The reasons: stable IDs are the convention (Microsoft's analyzer IDs such as CA1822, OWASP ASVS requirement numbers and CWE numbers never change when their categories move); the topic prefix and the layer folder are two separate groupings, and both survive; and renumbering would have touched every ADR, the scorecard, skills, tests, code comments, BannedSymbols messages and the inventory, with a rename map and a grace period, for a benefit only in how an ID reads.
3. **Profile choices add layers.** EF Core adds `efcore`. Recommended: yes, since otherwise a MAUI app on sqlite-net gets EF Core's rules.
4. **The owner's taste leaves the kit's rules** and moves to his preferences file in the next ADR, and the kit keeps only the floor, authority rules and its method. Recommended: yes, as his 2026-11-15 and 2026-11-18 asks say, once the preferences ADR gives CI a repo file to read.
5. **ADRs keep their text.** With decision 2 reversed, every rule ID an ADR names stays valid, so no ADR changes and no rename map is needed. (Approved on 2026-11-18 as "ADRs keep their old IDs, resolved through renames.yml".)
6. **A rule that spans two layers** goes in the more specific layer, tagged with the other. Recommended: yes, since the more specific technology is where a reader looks first.
7. **Strength replaces "proposed".** `must`, `should` or `consider`, from the source's wording; the kit's own additions start at `should`, and only the owner promotes one to `must`. Approved by the owner on 2026-11-18 ("Yes, add them"). The table of words above is the agent's mapping and is open to his changes.
8. **Every rule stands on its own** (proposed 2026-11-18, after SEC-007; approved by the owner: "Yes to both"). The owner: "I want to be confident that the rules make sense and stand on their own with only the contents of the rule(s)... Let's be vigilant with this going forward."
   - A rule that holds only for some apps says so in a `when:` field, in terms the app profile records: has sign-in, has a database, serves an HTTP API, holds personal data.
   - The generator gives an app only the rules whose `when` holds for it, and a rule's gate skips with a reason where it doesn't.
   - A check fails an authority rule whose quote states a condition ("for a server-side app where...", "if the app...") that the rule has no `when` for. The reviewer checks the same in a kit rule.
   - SEC-007 was the case in point. It dropped SEC-017's condition, "most or all endpoints require authentication", so a public site would have had to fake a sign-in policy. It's retired.
   - PR 2 touches every rule anyway, so the move is where each rule gets its `when`, once. That isn't a re-review of the rules' content.
9. **Rules accepted before strengths carry over at `must`** (proposed by the build, 2026-11-25; the owner's yes on the pull request that adds strengths accepts it). Every kit rule the owner had accepted (`status: accepted`, `basis: preference`) is in force and gated today, so it starts at `must`, with `ratified: ADR-0090` recording that his acceptance carried over. Starting it at `should` would turn its gates into warnings. A kit rule that was only proposed starts at `should`, as decision 7 says, and the owner promoted OPS-004 and ARC-009 to `must` on 2026-11-25. An authority rule takes its quotes' strength whatever its old status.

The build lands in two pull requests: strengths and `when` first, with the rules still in `docs/standards/` and `scope` unchanged, then the move into layers, which replaces `scope: core`.

## Consequences

- **Files:**
  - `docs/standards/` becomes `docs/rules/<layer>/{authority,kit}.md` and `docs/rules/method/`.
  - `app-types.yml` gets `layers`, and the intake's profile names the layers its choices add.
  - Every rule keeps its ID.
- **Checks:**
  - Test-RuleSources fails a file that holds a rule of another source or another layer, and a new rule that reuses a retired rule's ID. It also fails a rule with no `strength`, an authority `must` whose quote holds no must-word, and a kit `must` with no `ratified`.
  - Every gate reports through `Write-RuleFinding`, which fails a `must`, warns on a `should`, and never runs for a `consider`.
  - As built: the check scripts that report through `Write-RuleFinding` are the ones ADR-0089 lists. A gate that isn't one of them (a build gate, a test, a CI step) still fails whatever the rule's strength, as ADR-0089 says of a proposed rule's, so a `should` rule's build gate turns on only what a `must` rule already does, and Test-RuleSources fails a `consider` rule that has a gate. So SEC-008, a kit rule at `should`, keeps failing an app's tests through its shared host checks (`TokenTests`, and the OpenAPI document's bearer scheme in `OpenApiDocumentTests`), as SEC-017's, a `must`, do; ADR-0089 held both for the owner to decide. `Write-RuleFinding` also skips a rule, with its reason, in an app whose profile says one of its `when` conditions doesn't hold or whose app types its scope doesn't name.
  - AGENTS.md's "Whose rules win" and ADR-0002's "proposed until the owner accepts" change to the strength rule. That's a guardrail text, so the PR needs the owner's yes at its head commit.
  - Build-AgentRules writes the sectioned, tagged output.
  - The pre-commit hook and the reviewer run the same source check before CI (the owner's "instructions and skills, not only CI").
- **What moves where:**
  - **Kit method:** each `preference` rule is sorted, and the kit's method stays as `kit`.
  - **The owner's taste:** it moves to the preferences file, with the list of each call in the PR for the owner. Nothing of his is dropped.
  - **Gates that check taste:** a gate on a rule that moves to preferences (CRF-011's code-shape limits, STY-008) reads its limits or on-switch from the merged preferences, never from a hard-coded value. The preferences ADR settles how. This answers the plan v2 review's blocking item.
  - **How the owner's taste still reaches his apps' CI.** CI has no user preferences file, only what the repo commits, so moving a preference out of the kit depends on the repo's preferences file. For example, New-KitApp and Sync-KitApp would seed the app's committed `.config/preferences.json` from the developer's user file, and CI's gates would read that. The preferences ADR settles the details, and this ADR's move waits for it: until then, a gated rule that moves to preferences would stop gating in CI.
- **References to update:** only paths that name `docs/standards/` (scripts, skills, AGENTS.md, templates, tests, `Export-KitApp`'s copy list). Rule IDs don't change, so the scorecard, code comments, BannedSymbols messages, the inventory and the ADRs stay as they are.
- **What gets harder:** finding "all the security rules" means the scorecard's Security area, not one file.
- **Follow-ups:**
  - the preferences ADR (ADR-0091), which needs the owner's approval first;
  - unsupported app types, each defined by its layers (GAP-048);
  - GAP-049, a fresh app per type in CI, which proves each type's layer list.

## Pillars affected

- **Operational excellence:** an agent's rules say where each comes from, and a person can find a rule by its technology.
- **Security:** the floor and the security authorities stay in force and are tagged with their source. A security rule can't be hidden among preferences.
- **Reliability, cost, performance:** none. This changes only docs and offline checks.

## Sources

- owner, 2026-11-18 ("Organizations/semantics are important to me. Conventions that are intuitive")
- owner, 2026-11-18 ("The Microsoft rules and my personal preferences (again) should not be conflated in any way. Clear delineation, please.")
- owner, 2026-11-18 ("I am just seeing our efforts here as an opportunity to create a repository of rules/recommendations/suggetions, etc."; strength levels approved: "Yes, add them")
- owner, 2026-11-15 (three sources of a recommendation; corrections log)
- Microsoft Learn, Framework design guidelines: https://learn.microsoft.com/dotnet/standard/design-guidelines/ ("The guidelines are organized as simple recommendations prefixed with the terms `Do`, `Consider`, `Avoid`, and `Do not`.")
- RFC 2119, Key words for use in RFCs to Indicate Requirement Levels: https://www.rfc-editor.org/rfc/rfc2119
- ADR-0002, ADR-0089
- ADR-0082
- ADR-0084
