# Development and validation

Run the cross-provider packaging checks:

```bash
npm test
```

These tests include static checks for the native Antigravity plugin, the
Copilot, Cursor, and Grok marketplaces and provider packages, the OpenCode npm
package, workflow routing, and the Kiro Power. They enforce byte-for-byte skill
synchronization across the shared root, Claude, Copilot, Cursor, Grok, OpenAI,
and Kiro copies. OpenCode's namespaced projections must differ only in the
frontmatter name.
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
OAuth, or invoke a remote tool. OpenCode package tests exercise its configuration
hook directly, but do not prove npm installation, browser OAuth, or a remote tool
call. Record each layer of evidence separately.

## OpenCode npm package

`plugins/opencode/valency` is the publishable `@valency/opencode` package. Its
single configuration hook adds the hosted `valency` MCP server only when the
user has not already configured that name, then appends its package-relative
skills directory without duplicating it. OpenCode owns MCP transport and OAuth;
the package contains no local server, credentials, or authorization headers.

OpenCode skill names are prefixed with `valency-` to avoid collisions in its
global skill registry. Regenerate them after changing a canonical skill:

```bash
npm run sync:opencode
npm test
npm pack --dry-run ./plugins/opencode/valency
```

The generator copies every canonical skill and changes only its frontmatter
name. Packaging tests pin the projected folders, exact transformation, plugin
behavior, endpoint, public npm metadata, and credential-free payload.

For release validation, record the OpenCode version. Install the published
package, or extract the npm tarball and pass its package directory to
`opencode plugin --global`; OpenCode 1.18.26 does not accept a `.tgz` path
directly. Then run:

```bash
opencode debug config
opencode debug skill
opencode mcp auth valency
opencode mcp list
```

Confirm every `valency-*` skill is discoverable, complete browser OAuth, invoke
one representative read-only Valency Bond tool, restart OpenCode, and confirm
authentication is reused. Test a pre-existing disabled or custom `mcp.valency`
separately; the plugin must preserve it.

## Cursor provider package

The root `.cursor-plugin/marketplace.json` routes Cursor to the self-contained
package at `plugins/cursor/valency`. That package has its own native manifest,
full-surface `mcp.json`, synchronized skills, and a TeX/BibTeX literature
rule tailored for Cursor.

The package connects only to the canonical full endpoint at
`https://mcp.valency.io/` and exposes the full tool surface.
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
https://github.com/valency-oss/valency-connectors`. Open `/plugin`, install Valency
from the Marketplace tab, and confirm that all seven skills, the literature
rule, and the `valency` MCP connection load. Complete Cursor-managed OAuth and
run a representative read-only Valency Bond tool call.

Record static validation, installation, OAuth, tool discovery, and tool-call
results separately. If OAuth fails, record only the non-sensitive callback URI
after removing its query and fragment components. Redact authorization codes,
tokens, cookies, client secrets, and personal data from the OAuth results. Note
the Cursor surface; any redirect-allowlist or identity-provider change happens
on the Valency service side, not here. Do not add credentials or a callback
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

For an installation smoke test, add the root marketplace, install
`valency --trust`, and confirm
`grok plugin details valency` plus `grok inspect` report seven skills and one
HTTP MCP server. Then authenticate `valency` from `/mcps`, record the actual
non-sensitive callback URI, and make one representative read-only Valency Bond
tool call. Exercise update and uninstall separately without changing unrelated
Grok configuration.

Record static validation, installation, OAuth, and tool-call
results as separate evidence. If OAuth fails, do not package credentials or
guess at a callback workaround; any broker or upstream OAuth application
change happens on the Valency service side, not in this package.

## Kiro Power

Kiro requires `POWER.md` at a repository root for repository-URL imports. The
root `POWER.md`, `mcp.json`, and `steering/` directory therefore form one
self-contained Kiro Power alongside the independent Antigravity contract. Kiro
does not currently document a standalone Power validator.

For live validation, record the Kiro IDE version, then:

1. Open the Powers panel and choose **Add Custom Power** → **Import power from
   GitHub**.
2. Enter `https://github.com/valency-oss/valency-connectors` and confirm the Power
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
fields needed for diagnosis. Any MCP allowlist or upstream OAuth application
change belongs to the Valency service, not this provider package.

See [Repository root layout](./repository-layout.md) before adding, moving, or
consolidating root files. Several similarly named files implement different
provider schemas and are intentionally kept separate.

With Antigravity CLI installed, record `agy --version`, install the repository,
confirm it with `agy plugin list`, then use the interactive `/mcp` manager to
authenticate `valency` and make a representative tool call. Capture the dynamic
client registration request and submitted OAuth redirect URI during release
validation. If the redirect host is not accepted by Valency's MCP registration
allowlist and upstream OAuth application, that MCP/auth change belongs on the
Valency service side; do not add credentials or a callback workaround to the
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
package revision follows the repository commit. Claude and OpenAI versions can
advance independently; Copilot and Grok versions live in their provider
manifests, and the OpenCode npm version lives in
`plugins/opencode/valency/package.json`.
