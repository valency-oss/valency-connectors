# Development and validation

Run the cross-provider packaging checks:

```bash
npm test
```

These tests include static checks for the native Antigravity plugin and native
OpenClaw plugin, plus the Copilot, Cursor, and Grok marketplaces and provider packages.
They cover workflow routing and the Kiro Power. They also enforce byte-for-byte skill synchronization
across the shared root, Claude, Copilot, Cursor, Grok, OpenAI, OpenClaw, and
Kiro copies. The Antigravity checks pin the exact `plugin.json` and
`mcp_config.json` contracts and the host-specific rule. The OpenClaw checks pin
its skill-only manifest, explicit operator MCP setup, package and runtime
metadata, exact file inventory, license, and direct JavaScript entry.

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
OAuth, or invoke a remote tool. The OpenClaw package checks likewise do not
prove a managed install, a running Gateway reload, browser OAuth, or a Valency
tool call.

## Cursor provider package

The root `.cursor-plugin/marketplace.json` routes Cursor to the self-contained
package at `plugins/cursor/valency`. That package has its own native manifest,
full-surface `mcp.json`, synchronized skills, and the TeX/BibTeX literature
rule imported from `valency-oss/valency-cursor-bond`.

The initial package connects only to the canonical full endpoint at
`https://labs.valency.io/mcp/`. Profile selection and reduced authoring
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

For a private-release smoke test, use Git credentials authorized to read this
repository. Add the root marketplace, install `valency --trust`, and confirm
`grok plugin details valency` plus `grok inspect` report seven skills and one
HTTP MCP server. Then authenticate `valency` from `/mcps`, record the actual
non-sensitive callback URI, and make one representative read-only Valency Bond
tool call. Exercise update and uninstall separately without changing unrelated
Grok configuration.

Record static validation, private-repository installation, OAuth, and tool-call
results as separate evidence. If OAuth fails, do not package credentials or
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

## OpenClaw package

`plugins/openclaw/valency` is a self-contained native skill package for
OpenClaw 2026.8.1 and newer. Its checked-in ESM JavaScript entry is the
installed runtime entry, so there is no TypeScript source or generated `dist/`
tree to build or synchronize. The entry intentionally registers no tools.

The package manifest intentionally omits `mcpServers`. OpenClaw 2026.8.2 adds a
plugin-root `cwd` while normalizing native manifest HTTP MCP servers; Codex
rejects that field for `streamable_http`. In addition, `openclaw mcp login`
authorizes only servers saved under operator-managed `mcp.servers`. Installation
therefore keeps the seven skills in the package and configures the hosted server
explicitly with `openclaw mcp set`.

`npm test` is the repository's static contract check. It verifies the strict
empty config schema, absence of a manifest MCP contribution, compatibility
floor, JavaScript entry, seven byte-identical skills, license, and absence of
credentials, authorization headers, alternate endpoints, or a local MCP
wrapper. To inspect the package payload without publishing it, also review:

```bash
npm pack --dry-run --json ./plugins/openclaw/valency
```

Those checks do not execute an OpenClaw install. For quick checkout
development, link the package and restart the Gateway:

```bash
openclaw plugins install --link ./plugins/openclaw/valency
openclaw plugins enable valency
openclaw mcp set valency '{"url":"https://labs.valency.io/mcp/","transport":"streamable-http","auth":"oauth"}'
openclaw plugins inspect valency --runtime --json
openclaw gateway restart
```

A link smoke test does not prove the managed package path. Before release,
record the OpenClaw version, create the actual npm tarball, review its contents,
and install that tarball through `npm-pack:`:

```bash
npm pack ./plugins/openclaw/valency
openclaw plugins install npm-pack:<tarball.tgz>
openclaw plugins enable valency
openclaw mcp set valency '{"url":"https://labs.valency.io/mcp/","transport":"streamable-http","auth":"oauth"}'
openclaw plugins inspect valency --runtime --json
openclaw gateway restart
```

Then verify the running Gateway and a fresh OpenClaw session expose all seven
skills. Confirm `openclaw mcp status --verbose` reports the operator-managed
`valency` server, complete authorization separately with `openclaw mcp login
valency`, and confirm the connection with `openclaw mcp doctor valency
--probe`. Run one representative read-only Valency tool call.

Record installation, runtime discovery, MCP configuration, Gateway restart,
OAuth, MCP probing, tool use, update, and uninstall as separate results. Static
checks, a cold manifest inspection, and `plugins inspect --runtime` in a fresh
CLI process do not prove that an already-running Gateway loaded the package.

If OAuth fails, keep only the non-sensitive callback URI after removing its
query and fragment. Redact authorization codes, access and refresh tokens,
cookies, client secrets, PKCE state and verifiers, and personal data. Do not
add credentials or a callback workaround to the package; coordinate redirect
allowlisting or upstream OAuth changes separately.

ClawHub is an optional future distribution channel and is not part of this
initial validation path. Until publication occurs, do not record a ClawHub
install as available or successful. See [OpenClaw connector design and
sources](./openclaw.md) for the pinned package rationale.

See [Repository root layout](./repository-layout.md) before adding, moving, or
consolidating root files. Several similarly named files implement different
provider schemas and are intentionally kept separate.

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
`plugins/copilot/valency/plugin.json`, the Grok package version lives in
`plugins/grok/valency/.grok-plugin/plugin.json`, and the OpenClaw package and
manifest both pin version `0.1.0`.
