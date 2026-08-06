# Valency Bond

This repository distributes **Valency** integrations for multiple agent
providers. Each integration connects its host to the **Valency Bond MCP
server** at `https://labs.valency.io/mcp/` and bundles seven guided research
workflows.

The provider packages are self-contained. Where a host supports manifest
versions, the packages are versioned independently. Antigravity CLI, Gemini
CLI, and Kiro IDE each install their own contract from the repository root:

| Provider package | Hosts | Manifest |
| --- | --- | --- |
| [Repository root (Antigravity)](.) | Antigravity CLI | `plugin.json` |
| [Repository root (Gemini)](.) | Gemini CLI | `gemini-extension.json` |
| [Repository root (Kiro)](.) | Kiro IDE | `POWER.md` |
| [`plugins/claude/valency`](./plugins/claude/valency) | Claude Code | `.claude-plugin/plugin.json` |
| [`plugins/copilot/valency`](./plugins/copilot/valency) | GitHub Copilot CLI | `plugin.json` |
| [`plugins/openai/valency`](./plugins/openai/valency) | ChatGPT and Codex | `.codex-plugin/plugin.json` |

The root contains several provider-specific entry points because each host has
its own installation contract. See the
[repository root layout](./docs/repository-layout.md) for the owner and purpose
of every root entry.

## Install the skills only

To add the seven guided workflows to an existing agent without installing a
provider plugin, run:

```bash
npx skills@latest add valency-oss/valency-bond
```

In the selector, toggle **Valency Skills** to select or clear all seven
workflows at once, or choose individual workflows underneath it. This installs
the skill instructions only; it does not configure the Valency Bond MCP server
or authenticate it. Install the provider package for your host when you need
the complete integration.

## Install in Antigravity CLI

Install the repository as a native Antigravity plugin, then confirm that it is
listed:

```bash
agy plugin install https://github.com/valency-oss/valency-bond
agy plugin list
```

Start Antigravity CLI and open the interactive `/mcp` manager. Select
`valency`, complete the browser-based authorization flow, and confirm that the
server connects. Valency supports dynamic client registration, so you do not
need to configure an OAuth client ID, client secret, or bearer token.

OAuth and remote tool use have not yet been verified end to end with
Antigravity CLI. If its captured registration request uses a redirect host that
Valency does not currently allow, the MCP redirect allowlist and Clerk OAuth
application must be updated and deployed separately before authentication will
succeed.

The plugin packages the Valency MCP server, host-specific guidance, and seven
research skills. Antigravity exposes installed skills as slash commands; use
the skill-derived commands shown by the CLI.

### Disable, enable, or uninstall from Antigravity CLI

```bash
agy plugin disable valency
agy plugin enable valency
agy plugin uninstall valency
```

## Install in Gemini CLI

Install the repository as a Gemini CLI extension and enable automatic updates:

```bash
gemini extensions install https://github.com/valency-oss/valency-bond --auto-update
```

Restart Gemini CLI so the extension's context, skills, and `/valency:*`
commands are loaded. Start the browser-based authorization flow, then verify
that the Valency server and tools are available:

```text
/mcp auth valency
/mcp list
```

### Update or uninstall from Gemini CLI

```bash
gemini extensions update valency
gemini extensions uninstall valency
```

Restart Gemini CLI after updating so refreshed skills, commands, and context
are loaded.

## Install in GitHub Copilot CLI

Add this repository as a marketplace, then install Valency:

```bash
copilot plugin marketplace add valency-oss/valency-bond
copilot plugin install valency@valency-copilot-plugin
```

Start GitHub Copilot CLI and authenticate the plugin-provided Valency server:

```text
/mcp auth valency
```

The complete plugin is supported in GitHub Copilot CLI. Copilot coding agent
and Copilot code review do not currently support remote OAuth MCP servers, so
the Valency Bond tools are not supported on those hosted surfaces.

### Update or uninstall from GitHub Copilot CLI

Refresh the marketplace and update Valency:

```bash
copilot plugin marketplace update valency-copilot-plugin
copilot plugin update valency
```

To uninstall the plugin and remove its marketplace:

```bash
copilot plugin uninstall valency
copilot plugin marketplace remove valency-copilot-plugin
```

## Install in Kiro

Kiro's repository importer requires a Power at the repository root. This
repository provides the complete Kiro contract through the root `POWER.md`,
`mcp.json`, and `steering/` directory.

In the Kiro IDE:

1. Open the **Powers panel** and choose **Add Custom Power**.
2. Select **Import power from GitHub**.
3. Enter `https://github.com/valency-oss/valency-bond`, then install the Power.
4. Activate Valency and complete Kiro's browser-based authorization flow.

Kiro registers the `valency` server from the bundled `mcp.json`. Kiro manages
OAuth and dynamic client registration; the package contains no client ID,
client secret, bearer token, or fixed callback URL.

### Update or remove Valency from Kiro

Open **Powers panel** → **Installed Powers** → **Valency**. Choose **Check for
updates**, followed by **Install updates** when Kiro offers one.

To uninstall, use the Power detail controls to remove Valency from Installed
Powers. Removing the Power should be done in Kiro rather than by editing its
generated MCP configuration directly.

## Install in Claude Code

Add this repository as a user-scoped marketplace, then install Valency:

```bash
claude plugin marketplace add valency-oss/valency-bond --scope user
claude plugin install valency@valency-claude-plugin --scope user
```

Start or restart Claude Code, open `/mcp`, and authenticate `plugin:valency:valency` 
when prompted. You can start the same browser flow from a terminal:

```bash
claude mcp login plugin:valency:valency
```

Claude uses local TCP port `33418` while OAuth completes. If the port is
unavailable, identify the process holding it and stop that process only when it
is safe to do so:

```bash
lsof -nP -iTCP:33418 -sTCP:LISTEN
```

On Windows PowerShell, use
`Get-NetTCPConnection -LocalPort 33418 -State Listen`.

### Existing manual Claude MCP connections

Installing Valency never deletes an MCP connection you configured yourself.
Authenticate and verify `plugin:valency:valency` first. If Claude shows two
sets of Valency tools, inspect the existing entry with `claude mcp list` and
`claude mcp get SERVER_NAME`. You may then explicitly remove that old entry
with:

```bash
claude mcp remove SERVER_NAME --scope SCOPE
```

Replace `SERVER_NAME` with the name reported by Claude. `SCOPE` must be
`local`, `project`, or `user`.

### Update or uninstall from Claude Code

```bash
claude plugin marketplace update valency-claude-plugin
claude plugin update valency@valency-claude-plugin --scope user
```

Restart Claude Code or run `/reload-plugins` after updating. To uninstall:

```bash
claude plugin uninstall valency@valency-claude-plugin --scope user
claude plugin marketplace remove valency-claude-plugin --scope user
```

Uninstalling the plugin does not remove unrelated or manually configured MCP
connections.

## Install in Codex

Add this repository as a marketplace, then install Valency:

```bash
codex plugin marketplace add valency-oss/valency-bond
codex plugin add valency@valency
```

Start a new Codex session so the bundled skills and Valency Bond tools are
loaded. If installation finishes without opening the host-managed authorization
flow, run:

```bash
codex mcp login valency
```

Codex manages the resulting credentials. The plugin does not accept or require
a manually configured bearer token.

## Use in ChatGPT

ChatGPT and Codex share the OpenAI provider package in this repository.
ChatGPT desktop can install from a repository marketplace and complete the
host-managed Valency Bond authorization flow.

ChatGPT web does **not** install directly from a repository marketplace. Web
distribution requires either a published directory listing or a plugin shared
through a ChatGPT workspace. Until one of those sources contains Valency, use
ChatGPT desktop, Claude Code, or Codex instead.

## Guided workflows

Valency can run seven research workflows from natural-language requests:

- Build a researcher profile.
- Map a research landscape.
- Find papers similar to a title or stable identifier.
- Analyze publication trends.
- Map a collaboration network.
- Build a researcher reading list.
- Find fresh collaborators outside an author's established network.

The Valency Bond MCP server works with research discovery, metadata, abstracts,
citations, relationships, semantic similarity, and corpus analytics.
Availability varies by record and source. Valency never fabricates missing
records and submits feedback only when you explicitly request it.

## License

This repository and its provider integrations are MIT-licensed. See
[`LICENSE`](./LICENSE).

See the [development guide](./docs/development.md) for packaging checks and
provider-specific validation.

Organization-wide contribution, trademark, and security policies for
`valency-oss` are maintained at
[`valency-oss/.github`](https://github.com/valency-oss/.github).
