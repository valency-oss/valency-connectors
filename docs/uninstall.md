# Uninstall Valency Bond

Use the instructions for the host where you installed Valency. Removing a
provider package does not remove unrelated MCP servers or connections that you
configured manually.

## Claude Code

```bash
claude plugin uninstall valency@valency-claude-plugin --scope user
claude plugin marketplace remove valency-claude-plugin --scope user
```

If Claude still shows Valency tools, inspect manually configured MCP servers
with `claude mcp list`. Remove one only after confirming that it is the old
connection you intended to delete:

```bash
claude mcp remove SERVER_NAME --scope SCOPE
```

Replace `SERVER_NAME` with the name reported by Claude and `SCOPE` with
`local`, `project`, or `user`.

## Codex

```bash
codex plugin remove valency@valency
codex plugin marketplace remove valency
```

`codex plugin marketplace remove` expects the configured marketplace name.
This repository is registered as `valency`, even though it was added using the
source `valency-oss/valency-bond`.

Start a new Codex session after uninstalling.

## ChatGPT

Open ChatGPT's plugin settings and remove **Valency**. If a workspace installed
the plugin for you, a workspace administrator may need to remove it.

## Cursor

Open `/plugin` in Cursor Agent or **Customize → Plugins** in the Cursor IDE,
then disable or uninstall **Valency**. Use Cursor's controls instead of editing
its generated plugin or MCP files directly.

## GitHub Copilot CLI

```bash
copilot plugin uninstall valency
copilot plugin marketplace remove valency-copilot-plugin
```

`valency-copilot-plugin` is the marketplace name declared by this repository;
the remove command uses that name rather than the repository source.

## Antigravity CLI

```bash
agy plugin uninstall valency
```

## Grok Build

```bash
grok plugin uninstall valency
grok plugin marketplace remove https://github.com/valency-oss/valency-bond.git
```

## Kiro

Open **Powers → Installed Powers → Valency** and use the Power detail controls
to remove it. Do not edit Kiro's generated MCP configuration directly.

## OpenClaw

Clear the OAuth session and operator-managed MCP definition before removing the
plugin, then restart the Gateway:

```bash
openclaw mcp logout valency
openclaw mcp unset valency
openclaw plugins uninstall valency
openclaw gateway restart
```

OAuth credentials and the MCP definition are managed separately from the
package, so plugin removal alone clears neither. A managed Gateway may restart
automatically after uninstall; the explicit restart ensures the running Gateway
drops the package's skills and the operator-managed MCP server.

## Skills-only installation

Run the interactive remover and select the Valency skills you installed:

```bash
npx skills@latest remove
```
