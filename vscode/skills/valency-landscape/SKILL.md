---
name: valency-landscape
description: "Use when the user asks for an overview of a research field, wants to understand a domain's key players, or asks 'what's happening in X' or 'give me a landscape of X'. Triggers on requests for field summaries, top authors in an area, or subdomain breakdowns."
---

# Field Landscape

Generate a landscape overview of a research field or topic using the Valency research corpus.

## Tool conventions

- Use the Valency MCP tools available in the current agent (e.g., `search_by_category`). Tool names may be qualified with an MCP server prefix; call the matching exposed tool.
- Never fabricate paper titles, authors, abstracts, or metadata. All data must come from tool results.
- If a tool returns no results, say so plainly and suggest a different spelling or query.
- Produce clean, scannable output with consistent markdown formatting.

## Input

The user provides either:
- An arXiv category code (e.g., `cs.LG`, `q-bio.BM`, `astro-ph.CO`) — recognized by the pattern of a short prefix, a dot, and a short suffix
- Free text describing a research area (e.g., "protein folding", "large language models")

## Tool chain

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

### Step 3: Identify top authors

Call `identify_prolific_authors` with:
- `category` (string): the category code (if input was a category), otherwise omit
- `limit` (integer): 10

Note: if the input was free text and no category was identified, skip this step and note that top-author ranking requires a category code.

This tool can time out for very large categories (e.g., cs.LG). If it times out, skip this section in the output and note that author ranking was unavailable due to the size of the category.

### Step 4: Identify subdomains

Call `identify_research_domains` with:
- `limit` (integer): 10

Note: this returns corpus-wide domain rankings. If the input was a category, the results contextualize where this category sits within the broader landscape.

### Step 5: Get corpus metrics

Call `analyze_corpus_metrics` with:
- `category` (string): the category code (if input was a category), otherwise omit

## Output format

### Field summary

A brief paragraph covering:
- Total papers found (from Step 5 or Step 1 result count)
- Date range of publications
- Growth trajectory (from Step 2 — is volume increasing, stable, or declining?)

### Publication trends

A year-by-year table from Step 2:

| Year | Papers |
|------|--------|
| 2020 | 1,234  |
| ...  | ...    |

### Top authors

A numbered list of the top 10 authors from Step 3 with their paper counts.

### Subdomain breakdown

A table of the top research domains from Step 4, giving context for how this field relates to the broader corpus.

### Notable recent papers

List 5 papers from Step 1 (the most-cited papers found). For each:
- Title (with paper ID)
- Authors (first 3, then "et al." if more)
- Year
- Category

### Observations

2-3 brief observations drawn from the data. Examples:
- "Publication volume has doubled since 2021"
- "The field is concentrated in 2-3 subdomain categories"
- "Author X dominates with 3x more papers than the next most prolific"

### Suggested follow-ups

- "Profile `<author>`" — for any top author listed
- "Trends for `<category>`" — for deeper trend analysis
- "Papers similar to `<paper_id>`" — for any notable paper listed
