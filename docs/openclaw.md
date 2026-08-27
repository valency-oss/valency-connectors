# OpenClaw connector

## Scope and status

This document records the implemented Valency connector contract for
**OpenClaw 2026.8.1**. The OpenClaw sources are pinned to commit
[`fa09ec4c49b969794996158838cf69b1344165a3`](https://github.com/openclaw/openclaw/commit/fa09ec4c49b969794996158838cf69b1344165a3),
accessed 2026-08-27.

The native package lives at `plugins/openclaw/valency`. It connects OpenClaw to
the hosted Valency MCP server and carries the seven canonical skills. It does
not contain the MCP server implementation, a local wrapper, credentials, or
authorization headers.

The package is prepared for installation from a repository checkout. It has
not been published on ClawHub, and this repository does not claim a completed
live OpenClaw install, browser OAuth flow, or Valency tool call. ClawHub is an
optional future distribution channel rather than the initial install path.

## Why the connector is native

A native OpenClaw plugin can declare all three parts of the connector in one
package:

- plugin-owned skill directories;
- a static remote MCP server using `streamable-http`; and
- OpenClaw-managed `auth: "oauth"`.

OpenClaw reads `skills` and `mcpServers` from `openclaw.plugin.json` before it
loads plugin code. The server exists only while the plugin is enabled, and an
operator's `mcp.servers.valency` setting remains authoritative. Declaring the
server does not bypass normal tool policy. These boundaries are defined by the
pinned [manifest field and MCP server reference](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/plugins/manifest.md#L136-L265).
The remote transport and OAuth fields follow OpenClaw's pinned
[MCP configuration reference](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/gateway/configuration-reference.md#L98-L190).

A portable Agent Plugins 1.0.0 bundle can carry skills and a Streamable HTTP
MCP definition, but its closed MCP schema has no OAuth field. Valency would
therefore require a second operator-owned server override before login. See the
[Agent Plugins MCP transport specification](https://agent-plugins.org/specification#streamable-http-and-legacy-httpsse)
and OpenClaw's pinned [bundle mapping](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/plugins/bundles.md#L75-L168).
The native package avoids that duplicated connection configuration.

The connector must be additive. The repository-root `plugin.json` belongs to
Antigravity, root `mcp.json` belongs to Kiro, and root `skills/` is the shared
workflow source. OpenClaw therefore gets a self-contained nested package rather
than changes to another provider's root contract.

## Implemented package contract

```text
plugins/openclaw/valency/
├── package.json
├── openclaw.plugin.json
├── index.js
├── skills/
│   ├── fresh-collaborators/SKILL.md
│   ├── landscape/SKILL.md
│   ├── network/SKILL.md
│   ├── profile/SKILL.md
│   ├── reading-list/SKILL.md
│   ├── similar/SKILL.md
│   └── trends/SKILL.md
└── LICENSE
```

The MIT-licensed package identity is `@valency-oss/openclaw-valency` at
version `0.1.0`. Its plugin API, Gateway, and optional peer-dependency
compatibility floors are 2026.8.1; its build and SDK metadata also pin
2026.8.1. The package is ESM, and `openclaw.extensions` points directly to the
checked-in `index.js`.

That direct JavaScript entry is deliberate. OpenClaw requires a real runtime
entry for a managed native install, even when useful behavior is declarative;
its installer behavior is pinned in
[`src/plugins/install.test.ts`](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/src/plugins/install.test.ts#L1415-L1480).
OpenClaw's package-ready guidance also points external runtime entries at built
JavaScript included in the tarball, as documented in the pinned
[building guide](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/plugins/building-plugins.md#L61-L108)
and [package-proof steps](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/plugins/building-plugins.md#L183-L208).
Because this entry is already authored as ESM JavaScript, adding TypeScript
source and a generated `dist/` copy would create synchronization work without
changing the installed artifact.

The entry exposes the required empty registration function and registers no
OpenClaw tools, hooks, services, or commands. MCP owns the tool catalog and
tool execution. Do not add `registerTool` wrappers around the hosted service.
Native plugins execute in the Gateway process and must be treated as trusted
code even when the entry is empty; see OpenClaw's pinned
[plugin security guidance](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/gateway/security.md#L335-L346).

`openclaw.plugin.json` pins the following connector behavior:

```json
{
  "id": "valency",
  "version": "0.1.0",
  "skills": ["./skills"],
  "mcpServers": {
    "valency": {
      "url": "https://labs.valency.io/mcp/",
      "transport": "streamable-http",
      "auth": "oauth"
    }
  },
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
```

The excerpt omits presentation-only manifest fields. The config schema is
strictly empty because there is no package-specific operator configuration.
The seven package skills remain byte-identical to
`skills/*/SKILL.md`; OpenClaw loads plugin skill roots at its documented
precedence without requiring OpenClaw-specific skill metadata. See the pinned
[skill loading reference](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/tools/skills.md#L25-L151).

## Install, authorize, and restart

Until a catalog release exists, install from the nested package in an
authorized repository checkout:

```bash
git clone https://github.com/valency-oss/valency-bond.git
openclaw plugins install ./valency-bond/plugins/openclaw/valency
openclaw plugins enable valency
openclaw gateway restart
openclaw mcp login valency
```

The private repository requires GitHub credentials with access. Local path
installation and Gateway restart are documented by OpenClaw's pinned
[plugin quick start](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/tools/plugin.md#L20-L99).
OpenClaw may ask the operator to review and trust a non-ClawHub source. A
managed Gateway can restart automatically, but the explicit restart ensures
the running process sees the installed package.

OAuth is a separate browser step. `openclaw mcp login valency` starts the
loopback callback and authorization flow; installation itself neither opens an
account session nor embeds credentials. OpenClaw's exact shared-credential flow
is documented in the pinned
[MCP OAuth workflow](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/cli/mcp.md#L731-L814).

No ClawHub or npm registry install command is documented because
`@valency-oss/openclaw-valency` has not been published through either path.
ClawHub publication is an optional distribution step, not a different
connector architecture or a prerequisite for checkout installation.
OpenClaw's pinned publishing documentation states that a release must be
created and pass review before it appears on normal install surfaces:
[ClawHub publishing lifecycle](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/clawhub/publishing.md#L60-L67).

## Uninstall

Clear the separately managed OAuth session before removing the package:

```bash
openclaw mcp logout valency
openclaw plugins uninstall valency
openclaw gateway restart
```

Removing plugin files is not evidence that saved OAuth credentials were
cleared. Conversely, logging out does not remove the package. The explicit
Gateway restart ensures the running process drops the skills and static MCP
server.

## Validation boundary

Repository packaging tests should pin:

1. the exact package id, version, OpenClaw 2026.8.1 compatibility/build floor,
   direct JavaScript entry, and file inventory;
2. the exact manifest id, strict empty config schema, seven-skill root, hosted
   `streamable-http` endpoint, and `auth: "oauth"`;
3. the absence of credentials, bearer tokens, authorization headers, local MCP
   wrappers, and alternate or profile-specific endpoints;
4. exactly seven expected skill directories, each byte-identical to its root
   canonical source; and
5. package `LICENSE` equality plus install, uninstall, layout, and validation
   documentation.

Static tests and `npm pack --dry-run` catch repository and payload drift. They
do not prove that OpenClaw can install the tarball, that the active Gateway has
reloaded it, that Valency accepts OpenClaw's OAuth redirect, or that a remote
tool call succeeds.

Release validation must record each layer independently against an explicit
OpenClaw version:

1. Create the actual npm tarball and review its included files.
2. Install it through `npm-pack:<tarball.tgz>`; a linked directory is useful
   for development but does not exercise managed package installation.
3. Inspect `valency` with `openclaw plugins inspect valency --runtime --json`.
   This loads a fresh CLI process and does not prove the already-running
   Gateway has loaded the same package.
4. Restart the Gateway and confirm a fresh session exposes all seven skills and
   the `valency` MCP server.
5. Run `openclaw mcp login valency`, then probe the server. Browser OAuth,
   connection status, and tool discovery are separate results.
6. Make one representative read-only Valency tool call.
7. Exercise update and uninstall separately without changing unrelated
   OpenClaw configuration.

If OAuth fails, retain only the non-sensitive callback URI after removing its
query and fragment. Redact authorization codes, access and refresh tokens,
cookies, client secrets, PKCE state and verifiers, and personal data. A static
configuration cannot prove redirect compatibility. Coordinate any Valency
redirect-allowlist or upstream identity-provider change separately; never put
sensitive evidence or a callback workaround in this package.

OpenClaw's pinned plugin guide explains that cold inspection and a runtime
inspection in another CLI process do not prove the active Gateway state:
[runtime registration and Gateway verification](https://github.com/openclaw/openclaw/blob/fa09ec4c49b969794996158838cf69b1344165a3/docs/tools/plugin.md#L70-L99).
