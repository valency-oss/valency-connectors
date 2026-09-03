---
name: trends
description: "Use when the user asks how research activity for a topic has changed over time, wants publication volume trends, asks 'is X growing', 'when did X take off', or wants to compare the trajectories of two fields. Triggers on trend, growth, or timeline questions about research areas."
---

# Record Activity Trends

Show how matching research records for a topic or category have changed over time.

## Input

The user provides one of:
- An arXiv category code (e.g., `cs.LG`) — recognized by the short-prefix-dot-suffix pattern; the server scopes dotted codes to arXiv.
- A keyword or phrase (e.g., "transformer", "CRISPR")
- Multiple categories or keywords separated by commas or "vs" (e.g., "cs.LG, cs.CL" or "transformers vs RNNs") — for comparison

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

### Step 1: Get trend data

**If the input is a single category code:**

Call `get_publication_trends` with:
- `category` (string): the category code
- `granularity` (string): "year"
- `format` (string): "compact"

**If the input is a single keyword/phrase:**

Call `get_keyword_trends` with:
- `query` (string): the keyword
- `granularity` (string): "year"
- `format` (string): "compact"

**If the input contains multiple categories** (comma-separated or "vs"):

Call `get_publication_trends_batch` once with:
- `categories` (array of strings): the category codes
- `granularity` (string): "year"
- `format` (string): "compact"

The batch call accepts up to 20 categories under one optional `source` filter and deduplicates them in first-occurrence order. Per-category series are keyed by category in `data`.

**If the input contains multiple keywords** (comma-separated or "vs"):

Call `get_keyword_trends` once per keyword with:
- `query` (string): each keyword
- `granularity` (string): "year"
- `format` (string): "compact"

Category series count latest records in the resolved hierarchical category. Keyword series count lexical abstract-index matches. Both group records by source-record `datestamp`, so they show matching record activity rather than publication history.

Inspect `too_broad_categories`: those categories' `data` entries are drill-down objects (`error`, `direct_subcategories`) instead of period series — show the drill-down in place of that series while retaining successful siblings. Unknown categories surface in top-level `warnings` with suggestions; do not silently substitute another category. A successful empty series is not an error. Within one batch call, only `CATEGORY_TOO_BROAD` is resilient per entry — any other failure fails the whole batch — while separate per-keyword calls fail independently.

### Step 2: Get representative matches

Call `search_by_abstract` with:
- `query` (string): the keyword or category name (use the human-readable name for categories, e.g., "machine learning" for cs.LG)
- `limit` (integer): 5
- `sort_by` (string): "relevance"

These are representative abstract-text matches, not necessarily recent papers. Relevance ranks abstract-text match strength; surface returned fallback or ranking warnings.

## Output Format

### Record Activity

**For single input:** a year-by-year table:

| Year | Matching records |
|------|------------------|
| 2018 | 500              |
| ...  | ...              |

**For comparisons:** a side-by-side table of matching records:

| Year | cs.LG | cs.CL |
|------|-------|-------|
| 2018 | 500   | 300   |
| ...  | ...   | ...   |

### Narrative Summary

A 3-5 sentence narrative covering:
- The first observed matching record in this corpus
- Key inflection points (years where matching record activity jumped or dropped significantly)
- Current record-activity trajectory (accelerating, plateauing, declining)
- For comparisons: which scoped series is growing faster and when their matching-record activity diverged

### Representative Matches

A numbered list of 3-5 papers from Step 2. For each:
- Title (with paper ID)
- Authors (first 3, then "et al.")
- Source record/update date (`datestamp`)
- `first_submitted`, when present: a first-submission estimate for supported preprint sources; otherwise a record-derived month estimate

### Suggested Follow-ups

- Ask for a landscape of `<category>` for a broader overview of the field.
- Ask for a profile of `<author>` for authors driving the trend.
- Ask for trends in `<other_keyword>` to compare with related topics.
