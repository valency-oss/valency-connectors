# Development and validation

Run the cross-provider packaging checks:

```bash
npm test
```

These tests include static checks for the native Antigravity plugin, the Gemini
extension, the Copilot marketplace and provider package, command routing, and
byte-for-byte skill synchronization across the shared root, Claude, Copilot,
and OpenAI copies. The Antigravity checks pin the exact `plugin.json` and
`mcp_config.json` contracts, the host-specific rule, and separation from the
legacy Gemini payload.

Static checks catch repository drift, but do not prove that Antigravity CLI can
install the plugin, complete OAuth, or invoke a remote tool. They likewise do
not prove that a particular Gemini CLI release can complete OAuth or invoke the
remote tools. They also do not prove that GitHub Copilot CLI can install its
plugin, complete OAuth, or invoke a remote tool.

With Antigravity CLI installed, record `agy --version`, install the repository,
confirm it with `agy plugin list`, then use the interactive `/mcp` manager to
authenticate `valency` and make a representative tool call. Capture the dynamic
client registration request and submitted OAuth redirect URI during release
validation. If the redirect host is not accepted by Valency's MCP registration
allowlist and upstream OAuth application, coordinate that MCP/auth change and
deployment separately; do not add credentials or a callback workaround to the
plugin package.

With Gemini CLI installed, validate the root extension and complete a live
install, `/mcp auth valency`, `/mcp list`, and representative tool call before
release. Record the Gemini CLI version with those results. The root extension
installed from GitHub follows this repository's default branch; `--auto-update`
keeps that checkout current.

With Claude Code installed, run both strict Claude validators:

```bash
npm run validate:claude
```

With `uv` and the Codex plugin development skills installed, run the shared
OpenAI package validator:

```bash
npm run validate:openai
```

The command uses the `plugin-creator` validator bundled with the installed
Codex development skills and succeeds only when it exits with status `0`.
Record `codex --version` with release validation results so the validator's
host revision is explicit without copying or pinning that external validator
inside this repository.

Provider release versions live in their respective manifests when the host
supports them. Antigravity's `plugin.json` schema has no version field, so its
package revision follows the repository commit. The Claude and OpenAI package
versions can advance independently; the Copilot package version lives in
`plugins/copilot/valency/plugin.json`, and the root Gemini extension version
lives in `gemini-extension.json`.
