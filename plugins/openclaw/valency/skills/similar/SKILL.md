---
name: similar
description: "Use when the user wants papers similar to a known paper, asks what's related to it, or wants to explore its research neighborhood. Handles Valency corpus IDs, PMCIDs, titles including one word, and DOI-shaped inputs without assuming generic DOI lookup."
---

# Similar Papers

Find papers whose stored embeddings are closest to a resolved seed paper.

## Tool discovery

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; discover and call the matching exposed tool.
If the required Valency Bond tools are unavailable, say so and stop.

For every call, inspect `warnings`, `_meta.limit_clamped`, empty results, and
per-paper `authors_truncated`. A successful empty response is not a tool error.
If the MCP tool returns an error envelope instead of its normal response, report
the error and stop that chain.

## Step 1: Classify and resolve the seed

Route the input by what it represents, not by a generic identifier regex:

1. **Known corpus ID:** Use direct lookup for an `id` or `base_id` copied from a
   Valency result. This includes exact version IDs and base IDs, which resolve to
   the latest stored version. Familiar arXiv version/base forms are corpus IDs.
2. **PMCID:** A case-insensitive `PMC` followed by digits is accepted directly.
3. **Bare digits:** Numeric shape alone does not establish a typed PMID lookup.
   If the user presents the value as an ID, try it only as a candidate corpus
   ID; it succeeds only when that value is the stored corpus/base ID.
4. **DOI-shaped input:** There is no generic DOI lookup. A DOI-shaped preprint
   identifier may be looked up directly only when it is itself a known corpus
   `id` or `base_id` (for example, a `10.1101/...` preprint corpus ID, optionally
   versioned). For any other DOI, ask for or derive the paper title outside this
   tool chain; do not promise DOI resolution.
5. **Title:** Route every natural-language title, including a single word, to
   title search.

For a direct-lookup branch, call:

```json
{"paper_id":"<corpus ID, candidate corpus ID, or PMCID>","include_abstract":true}
```

Use the returned paper's canonical `id` as the seed. `found:false` is a
successful lookup with no match: explain that the value was not found as a
corpus ID and ask for the title. A tool error is different; report it and stop.

For a title branch, call `search_by_title`:

```json
{"query":"<entire supplied title>","limit":5,"include_abstract":true}
```

Auto-select only when the response contains one paper, or exactly one returned
title equals the query after Unicode case-folding, trimming, and collapsing
whitespace. Otherwise present the candidates with title, ID, available source,
`match_quality`, and response warnings, then ask the user to select one. If no
papers are returned, report the successful zero-result response and suggest
checking the title or using more distinctive title words.

After title selection, retrieve the selected seed with:

```json
{"paper_id":"<selected paper.id>","include_abstract":true}
```

This establishes the canonical seed ID and enriches its details. Do not fill any
field that remains absent or null.

## Step 2: Find neighbors

Call `find_similar_papers`:

```json
{"paper_id":"<canonical seed id>","limit":10,"include_abstract":true}
```

The order is descending cosine similarity between stored paper embeddings.
Inspect `warnings`, `_meta.limit_clamped`, and the paper count before rendering.

- A seed with no embedding returns a successful response with `count:0`,
  `papers:[]`, and a warning. Explain that paper-to-paper similarity is
  unavailable for this seed. Offer `semantic_search_papers` using the required
  seed title plus its abstract when a usable abstract is present; the title
  alone is the only grounded fallback when the abstract is absent. This is not
  a tool error.
- Any other successful empty response means no neighbors were returned under
  the call's scope; report that result and its warnings.
- For a genuine tool error, report the error separately and stop.

## Step 3: Enrich only missing details

Similarity results should contain the requested abstracts. If a result lacks
details needed for display, call:

```json
{"paper_id":"<result paper.id>","include_abstract":true}
```

Merge only returned fields. An empty author or category list and an absent
abstract, source, URL, or date are valid missing metadata; label them unavailable
or omit the optional field rather than synthesizing a value. Inspect warnings,
`_meta.limit_clamped`, empty results, and `authors_truncated` on every call.

## Output

### Source paper

Show:

- title and canonical corpus ID;
- ordered author head (first 5);
- the returned `categories` list exactly as provided, preserving its
  source-specific vocabulary;
- **Corpus source** only when `source` is non-null;
- a linked title using `url` when non-null, otherwise the unlinked corpus ID;
- for arXiv, bioRxiv, or medRxiv, **First-submission estimate** from non-null `first_submitted`;
- for every other or unknown source, **Record-derived month estimate** from non-null `first_submitted`;
- **Source record/update date** from `datestamp` when available;
- abstract when available, otherwise **Abstract unavailable**.

### Similar papers

Render a numbered list in returned similarity order. For each paper show:

- linked title when `url` is non-null, plus corpus ID and similarity score;
- ordered author head (first 3);
- all returned categories as a list, without choosing or translating a
  “primary” category;
- optional corpus source;
- a source-aware **first-submission estimate** or **record-derived month estimate** from `first_submitted`, plus **source record/update date** from `datestamp`;
- a one-sentence contribution summary grounded in the abstract, or
  **Abstract unavailable** when no abstract was returned.

When `authors_truncated:true`, append “et al.” and report `total_authors` when
present, explicitly marking the byline as truncated. When the full returned
byline is longer than the display head, append “et al.” without implying the
displayed names are complete. Never label `first_submitted` or `datestamp` as a
publication date or year.

End with the tool warnings that affect coverage or interpretation, including a
clamped limit or truncated byline. Then offer to continue from any returned
paper's corpus ID.
