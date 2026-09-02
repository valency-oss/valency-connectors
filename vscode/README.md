# Valency

Search, discover, and analyze tens of millions of research papers and preprints — without leaving your editor.

This extension connects VS Code's agent to the hosted [Valency](https://valency.io) MCP server and bundles seven research skills that know how to use it. There is nothing to configure: no API keys, no JSON editing, no local server.

## What you get

- **The Valency MCP server**, registered automatically at `https://mcp.valency.io/`. VS Code handles the browser sign-in; the extension ships no credentials and reads nothing from your workspace.
- **Seven agent skills**, selected automatically by what you ask:

| Skill | Ask things like |
| --- | --- |
| `valency-profile` | "Who is Yoshua Bengio and what do they work on?" |
| `valency-landscape` | "Give me a landscape of cs.LG" |
| `valency-similar` | "Find papers similar to arXiv 1706.03762" |
| `valency-trends` | "Is diffusion model research still growing?" |
| `valency-network` | "Who does Yann LeCun collaborate with?" |
| `valency-reading-list` | "What should a student of geometric deep learning be reading?" |
| `valency-fresh-collaborators` | "Who should this researcher be talking to that they aren't already?" |

## Getting started

1. Install the extension — the **Get started with Valency** walkthrough opens, along with a notification offering to sign in.
2. Choose **Sign in** (or run **Valency: Sign in** from the Command Palette) and complete the sign-in when your browser opens.
3. Ask the agent: **"Profile Yoshua Bengio"**.

## Requirements

- Visual Studio Code **1.109** or later.
- A Valency account, created automatically on first sign-in.

## Support

- Homepage: <https://valency.io>
- Issues: <https://github.com/valency-oss/valency-connectors/issues>
- Contact: <support@valency.io>

## License

The extension is [MIT licensed](https://github.com/valency-oss/valency-connectors/blob/main/vscode/LICENSE). The hosted Valency Bond MCP server is a proprietary service; see the [Valency privacy policy](https://www.valency.io/privacy).
