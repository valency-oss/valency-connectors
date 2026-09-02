# Changelog

All notable changes to the Valency VS Code extension are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-09-02

### Changed

- The walkthrough now leads with **Sign in to Valency**, followed by what was installed and running a first skill, so new users connect before anything else.
- Onboarding (walkthrough plus the sign-in notification) now runs again when the extension is reinstalled, not only on the very first install. Updating an already-onboarded install stays quiet.

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
