---
name: similar
description: "Use when the user wants to find papers similar to a specific paper, asks 'what's related to this paper', 'find me more like this', or wants to explore the neighborhood around a known paper. Triggers on known Valency corpus IDs or base IDs (including arXiv forms and DOI-shaped preprint corpus IDs), PMCIDs, or paper titles—including one-word titles—followed by a similarity request."
---

# Similar Papers

Find papers semantically similar to a given paper.

## Input

The user provides either:
- A known Valency corpus `id` or `base_id`. Exact version IDs work, and a base ID resolves to the latest stored version. These include familiar arXiv forms and DOI-shaped preprint corpus IDs.
- A PMCID (`PMC` followed by digits, case-insensitive).
- A paper title, including a one-word title.

**Identifier detection rules:**
- Treat an input as a paper identifier when it is a known corpus `id` or `base_id`, or matches the supported PMCID form.
- Bare digits are only candidate corpus IDs; do not treat them as typed PMIDs.
- A DOI-shaped string can be looked up directly only when it is itself a known corpus `id` or `base_id`. Generic DOI lookup is not supported; otherwise obtain a title.
- Route natural-language titles, including one-word titles, through title search.

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

For every response, inspect `warnings`, `_meta.limit_clamped`, and
`authors_truncated`. Empty results are successful responses, not error
envelopes. Report material warnings and any limit clamping or author-list
truncation that qualifies the results.

### Step 1: Resolve paper ID (if needed)

**If the input is a supported paper ID**:

Call `get_paper_by_id` with:
- `paper_id` (string): the provided ID
- `include_abstract` (boolean): true

Use the returned `paper.id` as the resolved paper ID. A response with `found: false` is a successful miss; tell the user the ID was not recognized and suggest searching by title instead. A genuine error envelope is an error and stops the chain.

**If the input looks like a title**:

Call `search_by_title` with:
- `query` (string): the provided title
- `limit` (integer): 5
- `include_abstract` (boolean): true

Select the result automatically if only one is returned, or if exactly one returned title equals the query after trimming and case-insensitive comparison. Otherwise present the candidates with title, ID, available source, returned `match_quality`, and warnings, and ask the user to confirm which paper they mean. Use the selected paper's ID for the next step.

If the successful response contains no papers, suggest the user check the title or try keywords from it. Stop here. A genuine error envelope is an error and stops the chain.

### Step 2: Find similar papers

Call `find_similar_papers` with:
- `paper_id` (string): the resolved paper ID
- `limit` (integer): 10
- `include_abstract` (boolean): true

If the successful response has `count: 0` and `papers: []` with a warning that the paper has no embedding, explain that semantic similarity is unavailable for this paper and suggest trying `semantic_search_papers` instead. Do not report this as a tool error. If any other successful response has no similar papers, say that none were returned. A genuine error envelope is an error and stops the chain.

### Step 3: Enrich results (if needed)

The results from Step 2 already include metadata (title, authors, abstract, categories). If any result is missing an abstract needed for display or is missing author data, call `get_paper_by_id` for those papers, with `include_abstract: true`.

## Output Format

### Source Paper

Display the seed paper's returned details only; show missing nullable values as unavailable rather than inferring them:
- **Title**: full title
- **Authors**: first 5, then "et al." if more are present or `authors_truncated` is true
- **Source**: which server (arXiv, bioRxiv, etc.), when available
- **Abstract**: first 2-3 sentences, or unavailable if no abstract was returned

### Similar Papers

A numbered list ranked by similarity. For each paper, display returned fields only; show missing nullable values as unavailable rather than inferring them:
- **Title** (with paper ID)
- **Authors**: first 3, then "et al." if more are present or `authors_truncated` is true
- **Categories**: the returned `categories` list in its original order and vocabulary
- **Abstract summary**: one sentence capturing the paper's contribution, or unavailable if no abstract was returned

### Suggested Follow-ups

- Ask for a profile of `<author>` for any author that appears in multiple similar papers.
- Ask for papers similar to `<paper_id>` to continue exploring from any listed paper.
