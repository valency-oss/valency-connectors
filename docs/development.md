# Development and validation

Run the cross-provider packaging checks:

```bash
npm test
```

These tests include static checks for the native Antigravity plugin, the
Copilot, Cursor, and Grok marketplaces and provider packages, workflow routing,
and the Kiro Power. They also enforce byte-for-byte skill synchronization
across the shared root, Claude, Copilot, Cursor, Grok, OpenAI, and Kiro copies.
The Antigravity checks pin the exact `plugin.json` and `mcp_config.json`
contracts and the host-specific rule.

The Kiro checks pin the supported `POWER.md` frontmatter, the credential-free
remote endpoint in `mcp.json`, and the one-to-one mapping from all seven
workflows to `steering/*.md`. Each Kiro steering file must remain byte-identical
to its canonical `skills/*/SKILL.md` source.

Static checks catch repository drift, but do not prove that Antigravity CLI can
install the plugin, complete OAuth, or invoke a remote tool. They also do not
prove that GitHub Copilot CLI can install its plugin, complete OAuth, or invoke a
remote tool.
Cursor package checks do not prove that Cursor can install the plugin, complete
OAuth, or invoke a remote tool. Static validation does not prove that Grok Build
can install the plugin, complete OAuth, or invoke a remote tool.
The Kiro static checks do not prove that Kiro can install the Power, complete
OAuth, or invoke a remote tool.

## Cursor provider package

The root `.cursor-plugin/marketplace.json` routes Cursor to the self-contained
package at `plugins/cursor/valency`. That package has its own native manifest,
full-surface `mcp.json`, synchronized skills, and the TeX/BibTeX literature
rule imported from `valency-oss/valency-cursor-bond`.

The initial package connects only to the canonical full endpoint at
`https://mcp.valency.io/`. Profile selection and reduced authoring
endpoints are intentionally deferred until those service contracts are ready.
The package must not contain a profile-specific endpoint or server name,
credentials, authorization headers, or a local MCP wrapper.

Run `npm test` while changing the Cursor package. To check both JSON manifests
against the current official Cursor schemas without adding a repository
dependency, run:

```bash
uvx --from check-jsonschema==0.37.4 check-jsonschema \
  --no-cache \
  --schemafile https://raw.githubusercontent.com/cursor/plugins/main/schemas/marketplace.schema.json \
  .cursor-plugin/marketplace.json
uvx --from check-jsonschema==0.37.4 check-jsonschema \
  --no-cache \
  --schemafile https://raw.githubusercontent.com/cursor/plugins/main/schemas/plugin.schema.json \
  plugins/cursor/valency/.cursor-plugin/plugin.json
```

For host validation, record the Cursor version and add this repository as a
marketplace with `cursor-agent plugin marketplace add
https://github.com/valency-oss/valency-bond`. Open `/plugin`, install Valency
from the Marketplace tab, and confirm that all seven skills, the literature
rule, and the `valency` MCP connection load. Complete Cursor-managed OAuth and
run a representative read-only Valency Bond tool call.

Record static validation, installation, OAuth, tool discovery, and tool-call
results separately. If OAuth fails, record only the non-sensitive callback URI
after removing its query and fragment components. Redact authorization codes,
tokens, cookies, client secrets, and personal data from the OAuth results. Note
the Cursor surface, then coordinate any Valency redirect-allowlist or upstream
identity-provider work separately. Do not add credentials or a callback
workaround to the provider package.

## Grok Build plugin

The repository-root `.grok-plugin/marketplace.json` maps `valency` to the
self-contained `plugins/grok/valency` package. Its seven skills must remain
byte-identical to the canonical root skills. Its `.mcp.json` must contain only
the remote HTTP endpoint; Grok owns OAuth and dynamic client registration.

With Grok Build installed, record `grok version` and validate the package:

```bash
grok plugin validate plugins/grok/valency
```

For a release smoke test, add the public root marketplace, install
`valency --trust`, and confirm
`grok plugin details valency` plus `grok inspect` report seven skills and one
HTTP MCP server. Then authenticate `valency` from `/mcps`, record the actual
non-sensitive callback URI, and make one representative read-only Valency Bond
tool call. Exercise update and uninstall separately without changing unrelated
Grok configuration.

Record static validation, repository installation, OAuth, and tool-call results
as separate evidence. If OAuth fails, do not package credentials or
guess at a callback workaround; coordinate any broker or upstream OAuth
application change separately.

## Kiro Power

Kiro requires `POWER.md` at a repository root for repository-URL imports. The
root `POWER.md`, `mcp.json`, and `steering/` directory therefore form one
self-contained Kiro Power alongside the independent Antigravity contract. Kiro
does not currently document a standalone Power validator.

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

The canonical installer source lives in `installer/install.sh`. Its provider
adapters detect, inspect, plan, install or update, verify, and report
authentication for Claude Code, Codex, Antigravity CLI, GitHub Copilot CLI, and
Grok Build. A Bash-3.2-compatible provider registry drives the
shared lifecycle while small host adapters retain the exact native commands
and output contracts. Cursor and Kiro are intentionally excluded because their
complete package installation flows remain host-interactive. Hosting the
script at the public Valency URL is a separate deployment step; this repository
does not claim that route is available merely because the source has been
merged.

Only Claude Code and Codex expose standalone Valency MCP login commands. The
other supported installer targets report `manual action required` and print
their exact in-host OAuth action without launching an agent TUI. Installation
and authentication remain separate outcomes.

The installer tests invoke the complete script with isolated home directories,
controlled terminal input, parseable host-output fixtures, and mocked provider
executables. Run them through
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
`plugins/copilot/valency/plugin.json`, and the Grok package version lives in
`plugins/grok/valency/.grok-plugin/plugin.json`.
