<p align="center">
  <a href="https://valency.io">
    <img
      src="./docs/assets/horizontal_solid_cyan_valency.svg"
      alt="Valency"
      width="420"
    >
  </a>
</p>

# Valency Bond Connectors

Valency Bond connects AI assistants to [Valency](https://valency.io) for
research discovery and analysis. Each provider package connects to the hosted
Valency Bond MCP server and includes eight guided workflows: a personalized
quickstart, researcher profiles, field landscapes, similar papers, publication
trends, collaboration networks, reading lists, and fresh collaborators.

Authentication is handled through your agent's browser-based sign-in flow. The
packages do not require a client secret, bearer token, or manually configured
authorization header.

> [!NOTE]
> While this repository is private, installation requires GitHub credentials
> with access to `valency-oss/valency-bond`.

## Install

### Claude Code

```bash
claude plugin marketplace add valency-oss/valency-bond --scope user &&
  claude plugin install valency@valency-claude-plugin --scope user &&
  claude mcp login plugin:valency:valency
```

Restart Claude Code or run `/reload-plugins` after installation.

### Codex

```bash
codex plugin marketplace add valency-oss/valency-bond &&
  codex plugin add valency@valency &&
  codex mcp login valency
```

The plugin installation includes both the seven skills and the Valency Bond MCP
connection. `codex mcp login valency` authorizes that bundled connection; users
do not need to add a separate MCP server or install a separate Valency app.

Start a new Codex session after installation so its skills and MCP tools load.

### ChatGPT

In ChatGPT desktop, add `valency-oss/valency-bond` as a plugin marketplace,
install **Valency**, and complete the browser-based authorization flow when
prompted.

ChatGPT web cannot install directly from a repository marketplace. It requires
Valency to be distributed through the ChatGPT plugin directory or a ChatGPT
workspace.

### Cursor

```bash
cursor-agent plugin marketplace add https://github.com/valency-oss/valency-bond
```

Then open `/plugin` in Cursor Agent, select the **Marketplace** tab, and install
**Valency**. In the Cursor IDE, use **Customize → Plugins**. Reload Cursor and
complete the Cursor-managed authentication flow when the `valency` MCP server
prompts you to connect.

### GitHub Copilot CLI

```bash
copilot plugin marketplace add valency-oss/valency-bond &&
  copilot plugin install valency@valency-copilot-plugin
```

Start Copilot CLI and run `/mcp auth valency`. Valency Bond is supported in
Copilot CLI; Copilot coding agent and Copilot code review do not currently
support its remote OAuth MCP server.

### Antigravity CLI

```bash
agy plugin install https://github.com/valency-oss/valency-bond
```

Open Antigravity's `/mcp` manager, select `valency`, and complete the browser
authorization flow.

### Grok Build

```bash
grok plugin marketplace add valency-oss/valency-bond &&
  grok plugin install valency --trust
```

Start a new Grok session, open `/mcps`, select `valency`, and press `i` to
authenticate. `--trust` allows Grok to activate the package's remote MCP
server; the package does not contain a local executable or credentials.

### Kiro

1. Open the **Powers** panel and choose **Add Custom Power**.
2. Select **Import power from GitHub**.
3. Enter `https://github.com/valency-oss/valency-bond` and install the Power.
4. Activate Valency and complete Kiro's browser-based authorization flow.

### Skills-only installation

To install the eight guided workflows without the Valency Bond MCP server:

```bash
npx skills@latest add valency-oss/valency-bond
```

Toggle **Valency Skills** to select or clear all eight workflows, or choose
individual skills. This does not configure or authenticate the MCP server.

## More information

- [Uninstall Valency Bond](./docs/uninstall.md)
- [Development and validation](./docs/development.md)
- [Repository layout](./docs/repository-layout.md)
- [MIT license](./LICENSE)

Organization-wide contribution, trademark, and security policies are
maintained in [`valency-oss/.github`](https://github.com/valency-oss/.github).
