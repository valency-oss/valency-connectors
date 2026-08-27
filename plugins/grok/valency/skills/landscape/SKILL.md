---
name: landscape
description: "Use when the user asks for an overview of a research field, wants to understand a domain's key players, or asks 'what's happening in X' or 'give me a landscape of X'. Triggers on requests for field summaries, top authors in an area, or subdomain breakdowns."
---

# Field Landscape

Generate a landscape overview of a research field or topic.

## Input

The user provides either:
- An arXiv category code (e.g., `cs.LG`, `q-bio.BM`, `astro-ph.CO`) — recognized by the pattern of a short prefix, a dot, and a short suffix. The server scopes dotted codes to arXiv.
- Free text describing a research area (e.g., "protein folding", "large language models")

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

### Step 1: Find papers in the field

**If the input matches an arXiv category pattern** (e.g., `cs.LG`):

Call `search_by_category` with:
- `category` (string): the category code
- `limit` (integer): 10
- `sort_by` (string): "citations"

**If the input is free text:**

Call `semantic_search_papers` with:
- `query` (string): the user's input
- `limit` (integer): 10
- `sort_by` (string): "citations"

Use the returned papers as anchors. Surface returned `ranking` and `warnings` whenever they qualify the ordering or count. For free text, citation ordering applies only within the capped semantic candidate set. Do not use the Step 1 `count` as a field total; it is the capped number of returned candidates.

If no anchor papers are returned, tell the user and stop here.

### Step 2: Get record activity

**If the input is a category code:**

Call `get_publication_trends` with:
- `category` (string): the category code
- `granularity` (string): "year"
- `format` (string): "compact"

**If the input is free text:**

Call `get_keyword_trends` with:
- `query` (string): the user's input
- `granularity` (string): "year"
- `format` (string): "compact"

Category counts are latest records in the resolved hierarchical category, while keyword counts are lexical abstract-index matches. Both are grouped by source-record `datestamp`.

An empty `periods` object is not an error. `CATEGORY_TOO_BROAD` returns direct-subcategory drill-downs but no series for the requested category. `UNKNOWN_CATEGORY` returns warnings and suggestions; surface them without silently substituting another category.

### Step 3: Identify top author-name aggregates

If the input is an arXiv category code, call `identify_prolific_authors` with:
- `category` (string): the category code
- `limit` (integer): 10

If the input was free text, skip this step and note that author-name aggregation requires a category code.

Treat returned names as author-name aggregates, not resolved people. Inspect each entry's `disambiguation_status`: retain `unambiguous`; qualify `mostly_single`, `ambiguous`, and `unresolved` with the returned evidence or warnings; exclude `likely_aggregation` and `severe_aggregation` from person rankings.

### Step 4: Identify corpus category context

Call `identify_research_domains` with:
- `limit` (integer): 10

This returns the highest-volume categories in the corpus, not topic subdomains: heterogeneous corpus context for the field.

### Step 5: Get scoped totals

**If the input is a category code**, call `analyze_corpus_metrics` with:
- `category` (string): the category code

**If the input is free text**, do not call `analyze_corpus_metrics`: its unfiltered total is a whole-corpus total, not a field total. Sum Step 2's annual counts and label the result as abstract-keyword matches.

## Output Format

### Field Summary

A brief paragraph covering:
- Category-scoped `total_papers`, or summed abstract-keyword matches for free text
- Source record/update date range
- Record-activity trajectory (from Step 2 — are matching records increasing, stable, or declining?)

### Record Activity

A year-by-year table from Step 2:

| Year | Matching records |
|------|------------------|
| 2020 | 1,234            |
| ...  | ...              |

### Author-Name Aggregates

A numbered list of up to 10 retained author-name aggregates from Step 3 with their record counts and any required disambiguation qualification.

### Corpus Category Context

A table of the highest-volume corpus or source categories from Step 4, giving context for the field without describing them as topic subdomains.

### Representative Matches

List up to 5 papers from Step 1. For category input, these are citation-ranked category results; for free text, they are citation-ranked semantic candidates within the capped candidate set. For each:
- Title (with paper ID)
- Authors (first 3, then "et al." if more)
- Source record/update date (`datestamp`)
- `first_submitted`, when present: a first-submission estimate for supported preprint sources; otherwise a record-derived month estimate
- Category

Null citation counts mean citation data is unavailable. Surface citation-coverage and ranking warnings that qualify the ordering.

### Observations

2-3 brief observations drawn from the data. Examples:
- "Matching record activity has doubled since 2021"
- "The selected corpus is concentrated in 2-3 high-volume categories"
- "One retained author-name aggregate has 3x more matching records than the next"

### Suggested Follow-ups

- Ask for a profile of `<author>` for any retained author name listed.
- Ask for trends in `<category>` for deeper trend analysis.
- Ask for papers similar to `<paper_id>` for any representative match listed.
