---
name: trends
description: "Use when the user asks how research record activity for a topic has changed over time, asks 'is X growing', 'when did X take off', or wants to compare the trajectories of two fields. Triggers on trend, growth, or timeline questions about research areas."
---

# Record Activity Trends

Show how matching research records for a topic or category have changed over time.

## Input

The user provides one of:
- An arXiv category code (e.g., `cs.LG`) — recognized by the short-prefix-dot-suffix pattern. Treat dotted codes as arXiv-scoped and pass `source: "arxiv"` on category calls.
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
- `source` (string): "arxiv"
- `granularity` (string): "year"
- `format` (string): "standard"

**If the input is a single keyword/phrase:**

Call `get_keyword_trends` with:
- `query` (string): the keyword
- `granularity` (string): "year"
- `format` (string): "standard"

**If the input contains multiple categories** (comma-separated or "vs"):

Call `get_publication_trends_batch` once with:
- `categories` (array of strings): the category codes
- `source` (string): "arxiv"
- `granularity` (string): "year"
- `format` (string): "standard"

The batch call accepts 2–20 same-source categories and deduplicates them while preserving order.

**If the input contains multiple keywords** (comma-separated or "vs"):

Call `get_keyword_trends` once per keyword with:
- `query` (string): each keyword
- `granularity` (string): "year"
- `format` (string): "standard"

For a successful single-category or keyword response, read `periods` rows as `{period, paper_count}`; `count` is the number of periods. In a batch response, read category series from `data`; `category_count`, not `count`, is the number of categories.

Category series count latest records in the resolved hierarchical category. Keyword series count lexical abstract-index matches. Both group records by source-record `datestamp`, so they show matching record activity rather than publication history.

Inspect `too_broad_categories` and every batch entry's `status`. For `CATEGORY_TOO_BROAD`, show the direct-subcategory drill-down in place of that series while retaining successful siblings. For `UNKNOWN_CATEGORY`, surface its warnings and suggestions without substitution. A successful empty series is not an error, and a true group or input error does not erase independent successful results.

### Step 2: Get representative matches

Call `search_by_abstract` with:
- `query` (string): the keyword or category name (use the human-readable name for categories, e.g., "machine learning" for cs.LG)
- `limit` (integer): 5
- `sort_by` (string): "relevance"

These are representative abstract-text matches, not necessarily recent papers. Relevance ranks abstract-text match strength; surface returned fallback or ranking warnings and effective limit clamping.

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

Retain each series' category or keyword inclusion scope when describing growth or divergence.

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
