# Repository root layout

Valency Bond is a distribution monorepo: one repository publishes native
packages for several agent providers. The root looks busier than a typical
single-application repository because multiple providers require root-level
entry points for direct repository installation.

Each host reads only the contract it recognizes. For example, Kiro reads
`POWER.md` and `mcp.json`, while Antigravity reads `plugin.json` and
`mcp_config.json`. These files sometimes describe the same Valency Bond service
using different provider schemas. Do not consolidate similarly named files
unless every affected provider contract and packaging test is updated.

## Root provider entry points

| Entry | Consumer | Purpose |
| --- | --- | --- |
| `POWER.md` | Kiro IDE | Defines the Valency Power metadata, onboarding, and seven workflow routes. Kiro requires this file at the repository root for GitHub imports. |
| `mcp.json` | Kiro IDE | Connects the Power to the remote Valency Bond MCP server using Kiro's schema. |
| `steering/` | Kiro IDE | Contains Kiro-readable copies of the seven canonical workflows. Packaging tests enforce byte-for-byte parity with `skills/`. |
| `plugin.json` | Antigravity CLI | Declares the repository-root Antigravity plugin. |
| `mcp_config.json` | Antigravity CLI | Connects Antigravity to Valency Bond using Antigravity's MCP schema. It is not interchangeable with Kiro's `mcp.json`. |
| `rules/` | Antigravity CLI | Provides host-specific setup and interaction guidance. |
| `gemini-extension.json` | Gemini CLI | Declares the repository-root Gemini extension and its MCP connection. |
| `GEMINI.md` | Gemini CLI | Supplies extension context that Gemini loads with Valency. |
| `commands/` | Gemini CLI | Defines the seven `/valency:*` commands and routes each command to its matching workflow. |

## Shared workflow source

| Entry | Consumer | Purpose |
| --- | --- | --- |
| `skills/` | All provider packages | Holds the seven canonical, provider-neutral Valency workflows. Provider packages copy this content into the format their host expects, and tests prevent drift. |

## Provider marketplaces and packages

| Entry | Consumer | Purpose |
| --- | --- | --- |
| `.agents/` | Codex | Declares this repository's OpenAI plugin marketplace. |
| `.claude-plugin/` | Claude Code | Declares this repository's Claude plugin marketplace. |
| `.github/` | GitHub and CI | Contains the GitHub Copilot marketplace plus GitHub Actions workflows. |
| `plugins/` | Claude, Copilot, and OpenAI hosts | Contains self-contained provider packages for hosts that install from a nested marketplace path. Kiro is at the root because its GitHub importer requires root `POWER.md`. |

## Development and repository infrastructure

| Entry | Purpose |
| --- | --- |
| `README.md` | User-facing installation and usage documentation for every provider. |
| `docs/` | Maintainer documentation, including validation instructions and this layout guide. |
| `installer/` | Source and isolated tests for the interactive multi-provider installer. Provider support is added here only when the host exposes a supported install flow. |
| `scripts/` | Repository validation helpers, including the OpenAI package validator wrapper. |
| `test/` | Cross-provider packaging tests that pin manifests, endpoints, workflow mappings, and synchronization. |
| `package.json` | Defines the repository's Node-based validation commands. This repository is not published as an npm package. |
| `LICENSE` | MIT license for this repository and its provider integration files. The hosted Valency Bond service has its own license. |

## When changing the root

Before moving, renaming, or combining a root entry:

1. Identify every host that reads it and recheck that host's current packaging
   documentation.
2. Keep provider additions additive; do not repurpose another host's working
   manifest or configuration.
3. Update `test/packaging.test.js` so the intended root contract is explicit.
4. Run the static validators in [Development and validation](./development.md).
5. Treat a real host install, OAuth flow, and tool call as separate evidence;
   static file checks do not prove them.
