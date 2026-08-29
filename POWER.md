---
name: "valency"
displayName: "Valency"
description: "Search, profile, and analyze research papers through the Valency Bond MCP server."
keywords: ["research papers", "researcher profile", "research landscape", "similar papers", "publication trends", "research network", "research reading list", "fresh collaborators", "research onboarding"]
author: "Valency Systems Inc"
---

# Valency

Valency provides guided research discovery and analysis through the Valency
Bond MCP server.

## Onboarding

This Power connects Kiro to the MCP server named `valency` in `mcp.json`.
Kiro manages the browser-based authorization flow. Valency Bond supports
dynamic client registration (DCR), so do not ask the user for a client ID,
client secret, bearer token, or fixed callback URL.

If the tools are unavailable, open Kiro's MCP panel, confirm MCP support is
enabled, and complete the host-managed authorization flow for `valency`. Do
not invent research records or continue a workflow that requires unavailable
Valency Bond tools.

## Workflows

Use Kiro's `readSteering` action with `powerName="valency"` to load the focused
steering file that matches the user's request before calling Valency Bond
tools. Keep these workflows distinct rather than replacing them with generic
research instructions:

- `quickstart` — teach a personalized Valency playbook and offer tailored examples → `steering/quickstart.md`
- `profile` — build a researcher's publication and collaboration profile → `steering/profile.md`
- `landscape` — summarize a field, its trajectory, and its key participants → `steering/landscape.md`
- `similar` — find papers related to a known title or stable identifier → `steering/similar.md`
- `trends` — analyze or compare publication activity over time → `steering/trends.md`
- `network` — map a researcher's direct and second-degree collaborators → `steering/network.md`
- `reading-list` — curate adjacent literature around a researcher's work → `steering/reading-list.md`
- `fresh-collaborators` — find relevant researchers outside an established coauthor network → `steering/fresh-collaborators.md`

## License and support

- Power license: [MIT](https://github.com/valency-oss/valency-bond/blob/main/LICENSE)
- Valency Bond MCP server license: Proprietary
- [Privacy Policy](https://www.valency.io/privacy)
- [Support](mailto:support@valency.io)
