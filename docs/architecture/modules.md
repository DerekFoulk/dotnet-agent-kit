# The kit's parts and how they depend on each other

ARC-013 asks every repo to keep a diagram of its modules and their dependencies here, and `tools/Test-ArchitectureDiagram.ps1` checks that it's there. Keeping it current is code review's job: a change that adds a part, or a dependency between parts, updates the diagram in the same PR.

## The kit

```mermaid
flowchart LR
    standards["docs/standards<br/>(the rules)"]
    adr["docs/adr"]
    rules["generated agent rules<br/>(.claude/rules, .github/instructions)"]
    tools["tools/<br/>(PowerShell checks and generators)"]
    codeshape["tools/CodeShape<br/>(Kit.CodeShape)"]
    ci[".github/workflows<br/>(kit-checks, app-checks, dotnet-ci)"]
    templates["templates/app"]
    sample["sample/<br/>(the Bookmarks app)"]
    webui["fixtures/WebUi"]
    apps["an app repo"]

    standards -->|cite| adr
    tools -->|Build-AgentRules reads| standards
    tools -->|writes| rules
    tools -->|runs| codeshape
    ci -->|runs| tools
    ci -->|builds and tests| sample
    ci -->|builds and tests| webui
    tools -->|New-KitApp and Export-KitApp copy| templates
    templates --> apps
    tools -->|.kit/tools| apps
    ci -->|reusable workflows| apps
```

## The sample's layers

The sample is one ARC-001 module. Each arrow is a project reference; `sample/tests/Bookmarks.Architecture.Tests` fails if a layer depends outward.

```mermaid
flowchart LR
    Api["Bookmarks.Api"] --> Application["Bookmarks.Application"]
    Api --> Infrastructure["Bookmarks.Infrastructure"]
    Api --> Contracts["Bookmarks.Contracts"]
    Api --> ServiceDefaults["Bookmarks.ServiceDefaults"]
    Infrastructure --> Application
    Application --> Domain["Bookmarks.Domain<br/>(pure: ARC-008)"]
    Application --> Contracts
```
