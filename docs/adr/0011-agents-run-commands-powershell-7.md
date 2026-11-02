# ADR-0011: Agents run commands; scripts target PowerShell 7

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

Agents repeatedly handed the owner commands to run instead of running them, and one command was given with a tool that wasn't on PATH. The owner wants agents to run things for him, and anything he runs himself as one user-friendly script with its purpose explained (owner, 2026-10-31). He used the PowerShell ISE, which only works with Windows PowerShell 5.1 and gets no new features. CI runners use PowerShell 7.

## Options

### Option 1: Agents run commands first; kit scripts target PowerShell 7; the owner uses VS Code with the PowerShell extension in ISE Mode

- **Trade-offs:** Scripts behave the same locally and in CI; ISE Mode keeps the ISE's layout and F5/F8 keys. A setup script must still run in 5.1 to install PowerShell 7 on a new machine.
- **Reversibility:** Easy.
- **Risk:** Low.

### Option 2: Keep scripts compatible with the ISE and Windows PowerShell 5.1

- **Trade-offs:** Familiar editor; no modern syntax, and behavior differs from CI.
- **Reversibility:** Easy.
- **Risk:** Medium. Divergence between local and CI runs.

## Recommendation

Option 1: Microsoft names VS Code with the PowerShell extension as the ISE's replacement, and it matches CI.

## Decision

Accepted as recommended, revised (owner, 2026-11-01).

## Consequences

- Agents run commands themselves and say in one line what each one does first.
- Kit scripts start with `#Requires -Version 7.0`, except `tools/Initialize-DevMachine.ps1`, which runs in 5.1 so a new machine can install PowerShell 7 with it.
- Every kit script gets Pester tests, written first.

## Pillars affected

Operational Excellence: the same scripts run the same way for agents, the owner and CI.

## Sources

- owner, 2026-10-31
- owner, 2026-11-01
- https://learn.microsoft.com/powershell/scripting/dev-cross-plat/vscode/how-to-replicate-the-ise-experience-in-vscode, retrieved 2026-11-01
