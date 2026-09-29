# Valency

Valency searches and analyzes research from arXiv, bioRxiv, medRxiv, and
PubMed through the bundled **Valency Bond** MCP server. Reach for its tools
when the user asks about papers, authors, citations, research trends, or
academic literature.

## MCP server

The plugin registers the `valency` MCP server itself. If its tools are not
available, say that Valency Bond is unavailable and ask the user to open the
interactive `/mcp` manager, select `valency`, and complete authentication. Do
not tell the user to install a separate connector plugin.

## Rules

- Never fabricate paper titles, authors, abstracts, citations, identifiers, or
  metadata. Base research claims on Valency Bond tool results.
- If a tool returns no results or lacks a field, say so plainly and suggest a
  different query when useful.
- Call `submit_feedback` only when the user explicitly asks to send feedback.
- Produce clean, scannable Markdown.

## Tool selection

- For conceptual queries, prefer `semantic_search_papers` or
  `search_by_abstract`; use `search_by_title` for title matching.
- For precise author work, resolve the author identity before making later
  publication, category, or collaboration calls, and reuse the resolved name.
- For a known paper, use `find_similar_papers` for semantic neighbors and
  `get_citing_papers` for citation relationships.
- Reuse stable Valency paper identifiers across calls instead of repeating
  searches.
- Use export tools when the user wants BibTeX, CSV, or JSON output.
