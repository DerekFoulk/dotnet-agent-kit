# The image the shared CI runs Playwright tests in (GAP-033, ADR-0061): Microsoft's Playwright .NET image, which holds
# the browsers of one Playwright version and their system libraries, pinned by tag and digest where Dependabot's docker
# updater moves both. Its tag's version must be the Microsoft.Playwright version in Directory.Packages.props: Playwright
# finds only its own version's browsers. Move the two in one PR (docs/standards/testing.md, "Browser and accessibility
# tests"). Nothing builds this file: CI runs the image its FROM line names.
FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@sha256:6955861f6e17b2580c00f0970198e446f006cdae6c34fb8f9ad5318aaab50da0
