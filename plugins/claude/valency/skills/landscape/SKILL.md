---
name: landscape
description: "Use when the user asks for an overview of a research field, wants to understand a domain's key players, or asks 'what's happening in X' or 'give me a landscape of X'. Triggers on requests for field summaries, top authors in an area, or subdomain breakdowns. Also invokable as /valency:landscape <topic_or_category>."
---

# Field Landscape

Generate a landscape overview of a research field or topic.

## Input

The user provides either:
- An arXiv category code (e.g., `cs.LG`, `q-bio.BM`, `astro-ph.CO`, `hep-th`, `math-ph`, `quant-ph`) — validate against the arXiv taxonomy rather than requiring a dot
- Free text describing a research area (e.g., "protein folding", "large language models")

## Tool Chain

### Step 1: Find papers in the field

**If the input is a valid arXiv category:**

Recognize both dotted subject classes such as `cs.LG` and `astro-ph.CO` and archive-level hyphenated categories such as `hep-th`, `math-ph`, and `quant-ph`. If a category-looking value is uncertain, try it as a category first and fall back to free-text handling only when the tool reports that the category is invalid.

Call `search_by_category` with:
- `category` (string): the category code
- `limit` (integer): 10
- `sort_by` (string): "citations"

**If the input is free text:**

Call `semantic_search_papers` with:
- `query` (string): the user's input
- `limit` (integer): 10
- `sort_by` (string): "citations"

If no results are found, tell the user and suggest trying different terms or checking category codes with a broader search. Stop here.

### Step 2: Get publication trends

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

Treat the current calendar year's count as year-to-date. Label it `YTD` and exclude it from full-year growth or decline claims unless the data supports a same-period comparison with prior years.

### Step 3: Identify top authors

Call `identify_prolific_authors` with:
- `category` (string): the category code (if input was a category), otherwise omit
- `limit` (integer): 10

Note: if the input was free text and no category was identified, skip this step and note that top-author ranking requires a category code.

This tool can time out for very large categories (e.g., cs.LG). If it times out, skip this section in the output and note that author ranking was unavailable due to the size of the category.

### Step 4: Add corpus-wide domain context (category input only)

If the input is a category code, call `identify_research_domains` with:
- `limit` (integer): 10

These are corpus-wide domain rankings, not subdomains of the requested category. Use them only as clearly labeled broader-corpus context.

If the input is free text, skip this step. The tool cannot filter its domain rankings to the requested topic.

### Step 5: Get category metrics (category input only)

If the input is a category code, call `analyze_corpus_metrics` with:
- `category` (string): the category code

If the input is free text, skip this step. Step 1 is a limited semantic-search sample, not a topic-wide paper count or date range.

## Output Format

### Field Summary

A brief paragraph covering:
- For a category, the total paper count and date range from Step 5
- For free text, the size and date range of the Step 1 search sample, explicitly labeled as sample metadata rather than field-wide metrics
- Growth trajectory from completed years in Step 2; use the current year's YTD value only for a supported same-period comparison

### Publication Trends

A year-by-year table from Step 2:

| Year | Papers |
|------|--------|
| 2020 | 1,234  |
| ...  | ...    |

### Top Authors

A numbered list of the top 10 authors from Step 3 with their paper counts.

### Corpus-Wide Domain Context

For category input only, show a table of the corpus-wide research domains from Step 4. Label it as broader-corpus context, not a subdomain breakdown for the requested field. Omit this section for free-text input.

### Notable Papers

List 5 papers from Step 1 (the most-cited papers found). For each:
- Title (with paper ID)
- Authors (first 3, then "et al." if more)
- Year
- Category

### Observations

2-3 brief observations drawn from the data. Examples:
- "Publication volume has doubled since 2021"
- "The ten-paper sample spans 3 categories"
- "Author X dominates with 3x more papers than the next most prolific"

### Suggested Follow-ups

- `/valency:profile <author>` — for any top author listed
- `/valency:trends <category>` — for deeper trend analysis
- `/valency:similar <paper_id>` — for any notable paper listed
