# Valency Bond

This repository distributes **Valency** integrations for multiple agent
providers. Each integration connects its host to the **Valency Bond MCP
server** at `https://labs.valency.io/mcp/` and bundles seven guided research
workflows.

The Claude and OpenAI packages are self-contained and versioned independently.
The Gemini CLI extension is installed from the repository root:

| Provider package | Hosts | Manifest |
| --- | --- | --- |
| [Repository root](.) | Gemini CLI | `gemini-extension.json` |
| [`plugins/claude/valency`](./plugins/claude/valency) | Claude Code | `.claude-plugin/plugin.json` |
| [`plugins/openai/valency`](./plugins/openai/valency) | ChatGPT and Codex | `.codex-plugin/plugin.json` |

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

Gemini uses local TCP port `33418` while OAuth completes. The extension uses
dynamic client registration, so you do not need to configure an OAuth client
ID, client secret, or bearer token.

### Update or uninstall from Gemini CLI

```bash
gemini extensions update valency
gemini extensions uninstall valency
```

Restart Gemini CLI after updating so refreshed skills, commands, and context
are loaded.

## Install in Claude Code

Add this repository as a user-scoped marketplace, then install Valency:

```bash
claude plugin marketplace add valency-oss/valency-bond --scope user
claude plugin install valency@valency-claude-plugin --scope user
```

The plugin owns its Valency Bond connection, so installation does not require a
separate MCP configuration command. Start or restart Claude Code, open `/mcp`,
and authenticate `plugin:valency:valency` when prompted. You can start the same
browser flow from a terminal:

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
