# Trust the server, then sign in

Two one-time prompts stand between you and the corpus:

1. **Trust prompt** — the first time the Valency server starts, VS Code asks whether to trust it. Choose **Trust**. The server is hosted at `mcp.valency.io`; the extension ships no credentials of its own.
2. **Browser sign-in** — VS Code then opens your browser to sign in with Valency. Complete the sign-in and return to VS Code.

VS Code stores the sign-in and refreshes it automatically from then on.

To redo either step later, run **MCP: Reset Trust** or **MCP: List Servers** from the Command Palette.
