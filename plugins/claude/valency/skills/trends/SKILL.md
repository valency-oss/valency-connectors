---
name: trends
description: "Use when the user asks how a research topic has changed over time, wants publication volume trends, asks 'is X growing', 'when did X take off', or wants to compare the trajectories of two fields. Triggers on trend, growth, or timeline questions about research areas. Also invokable as /valency:trends <keyword_or_category>."
---

# Publication Trends

Show how a topic or category has evolved over time.

## Input

The user provides one of:
- An arXiv category code (e.g., `cs.LG`, `astro-ph.CO`, `hep-th`, `math-ph`, `quant-ph`) — validate against the arXiv taxonomy rather than requiring a dot
- A keyword or phrase (e.g., "transformer", "CRISPR")
- Multiple categories or keywords separated by commas or "vs" (e.g., "cs.LG, cs.CL" or "transformers vs RNNs") — for comparison

## Tool Chain

### Step 1: Get trend data

Recognize both dotted subject classes such as `cs.LG` and `astro-ph.CO` and archive-level hyphenated categories such as `hep-th`, `math-ph`, and `quant-ph`. If a category-looking value is uncertain, try it as a category first and fall back to keyword handling only when the tool reports that the category is invalid.

Split comma-separated or `vs` comparisons into individual terms and classify each term independently as a category or keyword. Mixed comparisons are valid.

**For each category term:**

Call `get_publication_trends` with:
- `category` (string): the category code
- `granularity` (string): "year"
- `format` (string): "compact"

**For each keyword/phrase term:**

Call `get_keyword_trends` with:
- `query` (string): the keyword
- `granularity` (string): "year"
- `format` (string): "compact"

Note: `get_publication_trends_batch` exists but is unreliable and frequently times out. Use individual calls instead and combine the results into a comparison table.

**Partial-year discipline:** Treat the current calendar year's count as year-to-date. Label it `YTD` in tables and exclude it from full-year growth, decline, inflection-point, and trajectory comparisons unless the data supports a same-period comparison with prior years.

### Step 2: Get representative papers

For each category input, call `search_by_category` with:
- `category` (string): the category code
- `limit` (integer): 5
- `sort_by` (string): "relevance"

For each keyword input, call `search_by_abstract` with:
- `query` (string): the keyword or phrase
- `limit` (integer): 5
- `sort_by` (string): "relevance"

For a comparison, classify and search each input independently with the corresponding category or keyword tool. Keep each result set labeled with its comparison topic.

## Output Format

### Trend Data

**For single input:** a year-by-year table:

| Year | Papers |
|------|--------|
| 2018 | 500    |
| ...  | ...    |

**For comparisons:** a side-by-side table:

| Year | cs.LG  | cs.CL  |
|------|--------|--------|
| 2018 | 500    | 300    |
| ...  | ...    | ...    |

### Narrative Summary

A 3-5 sentence narrative covering:
- When the field or topic first appeared in the corpus
- Key inflection points among completed years (years where volume jumped or dropped significantly)
- Current trajectory (accelerating, plateauing, declining), based on completed years unless a same-period YTD comparison is available
- For comparisons: which topic is growing faster and when they diverged

### Representative Papers

A numbered list of 3-5 papers per Step 2 topic. For comparisons, group and label the papers by topic. For each paper:
- Title (with paper ID)
- Authors (first 3, then "et al.")
- Year

### Suggested Follow-ups

- `/valency:landscape <category>` — for a broader overview of the field
- `/valency:profile <author>` — for authors driving the trend
- `/valency:trends <other_keyword>` — to compare with related topics
