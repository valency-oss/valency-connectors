# Changelog

All notable changes to the Valency VS Code extension are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2026-09-02

### Fixed

- Reinstalling after uninstalling did not onboard when the reinstalled version differed from the previously recorded one, because a version change was treated as an automatic update. The extension now uses the `updated` flag VS Code records on every install: fresh installs and reinstalls onboard, while automatic updates and the Update button stay quiet.
- The install registry is now read from the active profile's location as well as the shared extensions folder, so named profiles are detected correctly.

### Added

- A **Valency** output channel that logs each onboarding decision and the install facts behind it.

## [0.1.4] - 2026-09-02

### Fixed

- Reinstalling the same version within one VS Code session did not onboard again: VS Code reuses the existing extension folder in that case instead of re-extracting it, so the folder timestamp used as the install marker never changed. The marker now also uses the install timestamp VS Code records in its extensions registry, which is refreshed on every install.

## [0.1.3] - 2026-09-02

### Changed

- The walkthrough now leads with **Sign in to Valency**, followed by what was installed and running a first skill, so new users connect before anything else.
- Onboarding (walkthrough plus the sign-in notification) now runs again when the extension is reinstalled, not only on the very first install. Updating an already-onboarded install stays quiet.
- The walkthrough is re-opened until VS Code has actually registered it, since opening it too early after startup silently showed the generic Welcome page instead. The sign-in notification no longer waits on the walkthrough.

## [0.1.2] - 2026-09-02

### Added

- A **Valency: Sign in** command that starts the Valency server interactively, which is what triggers the browser sign-in. Chat's automatic server start deliberately suppresses prompts, so this gives users a one-click path to connect. The command shows progress while connecting, then confirms with the number of research tools available (with an **Open Chat** shortcut) or warns with a **Show Output** shortcut if the connection did not complete.
- First-run onboarding: the extension now activates once on install, opens the **Get started with Valency** walkthrough directly (instead of relying on VS Code's install-time heuristics, which skip command-line and repeat installs), and shows a notification with a **Sign in** button.

### Changed

- The walkthrough's second step is now **Sign in to Valency** with a **Sign in** button, replacing the trust-prompt step: MCP servers contributed by extensions are trusted by default, so no trust prompt appears.

## [0.1.1] - 2026-08-31

### Changed

- Removed the cyan gallery banner so the Marketplace listing header uses the default background instead of rendering the cyan icon on a matching cyan field.

## [0.1.0] - 2026-08-31

### Added

- MCP server definition provider registering the hosted Valency Bond endpoint (`https://mcp.valency.io/`), with trust and OAuth sign-in handled entirely by VS Code.
- Seven agent skills vendored from `valency-skills`: `valency-profile`, `valency-landscape`, `valency-similar`, `valency-trends`, `valency-network`, `valency-reading-list`, and `valency-fresh-collaborators`.
- A three-step **Get started with Valency** walkthrough covering what was installed, the trust prompt and browser sign-in, and a first skill run.
