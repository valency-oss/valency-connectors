# Development and validation

Run the cross-provider packaging checks:

```bash
npm test
```

These tests include static checks for the native Antigravity plugin, the Gemini
extension, the Copilot marketplace and provider package, command routing, and
the Kiro Power. They also enforce byte-for-byte skill synchronization across
the shared root, Claude, Copilot, OpenAI, and Kiro copies. The Antigravity
checks pin the exact `plugin.json` and `mcp_config.json` contracts, the
host-specific rule, and separation from the legacy Gemini payload.

The Kiro checks pin the supported `POWER.md` frontmatter, the credential-free
remote endpoint in `mcp.json`, and the one-to-one mapping from all seven
workflows to `steering/*.md`. Each Kiro steering file must remain byte-identical
to its canonical `skills/*/SKILL.md` source.

Static checks catch repository drift, but do not prove that Antigravity CLI can
install the plugin, complete OAuth, or invoke a remote tool. They likewise do
not prove that a particular Gemini CLI release can complete OAuth or invoke the
remote tools. They also do not prove that GitHub Copilot CLI can install its
plugin, complete OAuth, or invoke a remote tool. The Kiro static checks do not
prove that Kiro can install the Power, complete OAuth, or invoke a remote tool.

## Kiro Power

Kiro requires `POWER.md` at a repository root for repository-URL imports. The
root `POWER.md`, `mcp.json`, and `steering/` directory therefore form one
self-contained Kiro Power alongside the independent Antigravity and Gemini
contracts. Kiro does not currently document a standalone Power validator.

For live validation, record the Kiro IDE version, then:

1. Open the Powers panel and choose **Add Custom Power** → **Import power from
   GitHub**.
2. Enter `https://github.com/valency-oss/valency-bond` and confirm the Power
   installs. To test unpublished local changes, instead choose **Import power
   from a folder** and select the repository root.
3. Verify that all seven workflows are reachable through their focused
   steering files.
4. Confirm that Kiro registers and starts the `valency` server from `mcp.json`.
5. Complete browser OAuth through dynamic client registration.
6. Run a representative read-only Valency Bond tool call.

Record each result separately. A successful folder import does not prove that
OAuth or remote tool use works. If OAuth fails, capture the registration
request and exact redirect URI. Before sharing that evidence, redact
authorization codes, access or refresh tokens, cookies, client secrets, and
unrelated personal data; retain only the redirect URI and non-sensitive request
fields needed for diagnosis. Coordinate any MCP allowlist or upstream OAuth
application change separately from this provider package.

See [Repository root layout](./repository-layout.md) before adding, moving, or
consolidating root files. Several similarly named files implement different
provider schemas and are intentionally kept separate.

## Universal installer

The canonical installer source lives in `installer/install.sh`. Its initial
provider adapters detect, install, update, and optionally authenticate the
Claude Code and Codex packages from this repository. Hosting the script at the
public Valency URL is a separate deployment step; this repository does not
claim that route is available merely because the source has been merged.

The installer tests invoke the complete script with isolated home directories,
controlled terminal input, and mocked provider executables. Run them through
the installer test command, or invoke their component checks while iterating:

```bash
npm run test:installer
bash -n installer/install.sh
bash installer/tests/installer_test.sh
shellcheck installer/install.sh installer/tests/installer_test.sh installer/tests/fixtures/mock-provider
```

The CI workflow also executes the same installer suite under Bash 3.2, which is
the Bash version supplied by older macOS releases.

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
