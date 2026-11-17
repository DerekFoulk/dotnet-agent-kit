# The image the shared CI runs Playwright tests in (GAP-033, ADR-0061): Microsoft's Playwright .NET image, which holds
# the browsers of one Playwright version and their system libraries, pinned by tag and digest where Dependabot's docker
# updater moves both. Its tag's version must be the Microsoft.Playwright version in Directory.Packages.props: Playwright
# finds only its own version's browsers. Move the two in one PR (docs/standards/testing.md, "Browser and accessibility
# tests"). Nothing builds this file: CI runs the image its FROM line names.
FROM mcr.microsoft.com/playwright/dotnet:v1.65.0-noble@sha256:8979c2903b06b3f2003226ee5073764971a6709f70932653cf70ff52a69802b9
