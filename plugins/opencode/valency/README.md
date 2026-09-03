# Valency for OpenCode

Connects OpenCode to the hosted Valency Bond MCP server and provides research workflows for literature discovery, researcher analysis, trends, networks, and reading lists.

## Install

```bash
opencode plugin --global @valency/opencode
opencode mcp auth valency
```

Start a new OpenCode session after installation. OpenCode manages the browser-based OAuth flow; this package contains no credentials or local server executable.

The plugin preserves an existing `mcp.valency` entry, including a custom URL or `enabled: false` setting.

## Remove

Run `opencode mcp logout valency`, then remove `@valency/opencode` from the `plugin` array in `~/.config/opencode/opencode.json` or `opencode.jsonc`. Start a new OpenCode session afterward.

## License

MIT
