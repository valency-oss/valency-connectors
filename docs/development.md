# Development and validation

Run the cross-provider packaging checks:

```bash
npm test
```

These tests include static Gemini packaging checks for `gemini-extension.json`,
the root context file, command routing, and byte-for-byte skill synchronization
across Gemini, Claude, and OpenAI. Static checks catch repository drift, but do
not prove that a particular Gemini CLI release can complete OAuth or invoke the
remote tools.

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

Provider release versions live in their respective manifests. The Claude and
OpenAI package versions can advance independently; the root Gemini extension
version lives in `gemini-extension.json`.
