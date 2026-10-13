---
name: valency-trends
description: "Use when the user asks how a research topic has changed over time, wants publication volume trends, asks 'is X growing', 'when did X take off', or wants to compare the trajectories of two fields. Triggers on trend, growth, or timeline questions about research areas."
---

# Publication Trends

Show how a topic or category has evolved over time using the Valency research corpus.

## Tool conventions

- Use the Valency MCP tools available in the current agent (e.g., `get_publication_trends`). Tool names may be qualified with an MCP server prefix; call the matching exposed tool.
- Never fabricate paper titles, authors, abstracts, or metadata. All data must come from tool results.
- If a tool returns no results, say so plainly and suggest a different spelling or query.
- Produce clean, scannable output with consistent markdown formatting.

## Input

The user provides one of:
- An arXiv category code (e.g., `cs.LG`) — recognized by the short-prefix-dot-suffix pattern
- A keyword or phrase (e.g., "transformer", "CRISPR")
- Multiple categories or keywords separated by commas or "vs" (e.g., "cs.LG, cs.CL" or "transformers vs RNNs") — for comparison

## Tool chain

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

Call `get_publication_trends` individually for each category with:
- `category` (string): each category code
- `granularity` (string): "year"
- `format` (string): "compact"

Note: `get_publication_trends_batch` exists but is unreliable and frequently times out. Use individual calls instead and combine the results into a comparison table.

**If the input contains multiple keywords** (comma-separated or "vs"):

Call `get_keyword_trends` once per keyword with:
- `query` (string): each keyword
- `granularity` (string): "year"
- `format` (string): "compact"

### Step 2: Get recent representative papers

Call `search_by_abstract` with:
- `query` (string): the keyword or category name (use the human-readable name for categories, e.g., "machine learning" for cs.LG)
- `limit` (integer): 5
- `sort_by` (string): "relevance"

## Output format

### Trend data

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

### Narrative summary

A 3-5 sentence narrative covering:
- When the field or topic first appeared in the corpus
- Key inflection points (years where volume jumped or dropped significantly)
- Current trajectory (accelerating, plateauing, declining)
- For comparisons: which topic is growing faster and when they diverged

### Representative recent papers

A numbered list of 3-5 papers from Step 2. For each:
- Title (with paper ID)
- Authors (first 3, then "et al.")
- Year

### Suggested follow-ups

- "Landscape of `<category>`" — for a broader overview of the field
- "Profile `<author>`" — for authors driving the trend
- "Trends for `<other_keyword>`" — to compare with related topics
