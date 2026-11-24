# The image the shared CI runs Playwright tests in (GAP-033, ADR-0061): Microsoft's Playwright .NET image, which holds
# the browsers of one Playwright version and their system libraries, pinned by tag and digest where Dependabot's docker
# updater moves both. Its tag's version must be the Microsoft.Playwright version in Directory.Packages.props: Playwright
# finds only its own version's browsers. Move the two in one PR (docs/standards/testing.md, "Browser and accessibility
# tests"). Nothing builds this file: CI runs the image its FROM line names.
FROM mcr.microsoft.com/playwright/dotnet:v1.65.1-noble@sha256:d6f5dc4c392790d21671887dcfa1d37c6a9fcb088a5950d991dcea7e519a5c30
