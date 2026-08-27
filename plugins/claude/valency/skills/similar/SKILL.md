---
name: similar
description: "Use when the user wants to find papers similar to a specific paper, asks 'what's related to this paper', 'find me more like this', or wants to explore the neighborhood around a known paper. Triggers on paper IDs (arXiv-style, DOI-shaped, or PMCID) or paper titles — including one-word titles — followed by a similarity request."
---

# Similar Papers

Find papers whose stored embeddings are closest to a resolved seed paper.

## Tool discovery

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; discover and call the matching exposed tool.
If the required Valency Bond tools are unavailable, say so and stop.

For every call, inspect `warnings` and per-paper `authors_truncated`. A
successful empty response is not a tool error. If the MCP tool returns an error
envelope instead of its normal response, report the error and stop that chain.

Date fields carry the **source-aware date label**: non-null `first_submitted`
is a first-submission estimate for arXiv, bioRxiv, and medRxiv records and a
record-derived month estimate for other sources; `datestamp` is the source
record/update date. None is a publication date.

## Step 1: Classify and resolve the seed

Route the input:

1. **Known corpus ID:** Use direct lookup for an `id` or `base_id` copied from a
   Valency result. This includes exact version IDs and base IDs, which resolve to
   the latest stored version. Familiar arXiv version/base forms are corpus IDs.
2. **PMCID:** A case-insensitive `PMC` followed by digits is accepted directly.
3. **Bare digits:** Try only as a candidate corpus ID — there is no typed PMID
   lookup; it succeeds only when the value is a stored corpus/base ID.
4. **DOI-shaped input:** Direct lookup works only when the string is itself a
   known corpus `id` or `base_id` (bioRxiv/medRxiv corpus IDs are DOI-shaped,
   e.g. `10.1101/...`); for any other DOI, ask for the title — there is no
   generic DOI lookup.
5. **Title:** Route every natural-language title, including a single word, to
   title search.

For a direct-lookup branch, call:

```json
{"paper_id":"<corpus ID, candidate corpus ID, or PMCID>"}
```

Use the returned paper's canonical `id` as the seed. `found:false` is a
successful lookup with no match: explain that the value was not found as a
corpus ID and ask for the title. A tool error is different; report it and stop.

For a title branch, call `search_by_title`:

```json
{"query":"<entire supplied title>","limit":5}
```

Auto-select only when the response contains one paper, or exactly one returned
title equals the query after trimming, case-insensitive comparison, and
ignoring a trailing period (PubMed titles often carry one). Otherwise present
the candidates with title, ID, available source, `match_quality`, and response
warnings, then ask the user to select one. If no papers are returned, report
the successful zero-result response and suggest checking the title or using
more distinctive title words.

Use the selected paper's `id` as the seed; `search_by_title` already returns
every field the output renders, so no follow-up lookup is needed.

## Step 2: Find neighbors

Call `find_similar_papers`:

```json
{"paper_id":"<canonical seed id>","limit":10}
```

The order is descending cosine similarity between stored paper embeddings.

- A seed with no embedding returns a successful response with `count:0`,
  `papers:[]`, and a warning. Explain that paper-to-paper similarity is
  unavailable for this seed and offer `semantic_search_papers`, building the
  query from the seed's title plus its abstract — title alone when no abstract
  was returned. This is not a tool error.
- Any other successful empty response means no neighbors were returned under
  the call's scope; report that result and its warnings.
- For a genuine tool error, report the error separately and stop.

Similarity results already include every field the output renders; no
enrichment call is needed.

## Output

### Source paper

Show:

- linked title (via `url` when non-null) and canonical corpus ID;
- ordered author head (first 5);
- the returned `categories` list exactly as provided, preserving its
  source-specific vocabulary;
- **Corpus source** only when `source` is non-null;
- the source-aware date label (`first_submitted` and/or `datestamp`);
- abstract when available, otherwise **Abstract unavailable**.

### Similar papers

Render a numbered list in returned similarity order. For each paper show:

- linked title (via `url` when non-null), corpus ID, and similarity score;
- ordered author head (first 3);
- all returned categories as a list;
- optional corpus source;
- the source-aware date label;
- a one-sentence contribution summary grounded in the abstract, or
  **Abstract unavailable** when no abstract was returned.

Append “et al.” whenever more authors exist than shown (`authors_truncated:
true` or a returned byline longer than the display head), reporting
`total_authors` for truncated bylines.

End with the tool warnings that affect coverage or interpretation. Then offer
to continue from any returned paper's corpus ID.
