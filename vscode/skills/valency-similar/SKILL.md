---
name: valency-similar
description: "Use when the user wants to find papers similar to a specific paper, asks 'what's related to this paper', 'find me more like this', or wants to explore the neighborhood around a known paper. Triggers on paper IDs, arXiv IDs, DOIs, PubMed IDs, or paper titles followed by a similarity request."
---

# Similar Papers

Find papers semantically similar to a given paper using the Valency research corpus.

## Tool conventions

- Use the Valency MCP tools available in the current agent (e.g., `find_similar_papers`). Tool names may be qualified with an MCP server prefix; call the matching exposed tool.
- Never fabricate paper titles, authors, abstracts, or metadata. All data must come from tool results.
- If a tool returns no results, say so plainly and suggest a different spelling or query.
- Produce clean, scannable output with consistent markdown formatting.

## Input

The user provides either:
- A paper identifier — one of:
  - arXiv ID (e.g., `2301.07041` or `2301.07041v3`)
  - DOI (e.g., `10.1101/2024.01.15.575423` or any `10.xxxx/...` pattern)
  - PubMed ID / PMID (digits only, e.g., `26360422`)
- A paper title (contains spaces, reads as natural language)

**Identifier detection rules:**
- If the input is digits only → treat as PMID
- If the input matches `10.xxxx/...` → treat as DOI (covers bioRxiv, medRxiv, and other DOI-minted sources)
- If the input matches a numeric pattern with dots like `NNNN.NNNNN` (optionally with `vN` suffix) → treat as arXiv ID
- Otherwise → treat as a title and resolve via search

Do not assume all bioRxiv records use the `10.1101/...` prefix. Newer records may use other DOI prefixes.

## Tool chain

### Step 1: Resolve paper ID (if needed)

**If the input is a paper ID** (arXiv ID, DOI, or PMID):

Call `get_paper_by_id` with:
- `paper_id` (string): the provided ID

If no paper is found, tell the user the ID was not recognized and suggest searching by title instead. Stop here.

**If the input looks like a title** (contains spaces):

Call `search_by_title` with:
- `query` (string): the provided title
- `limit` (integer): 5

Present the top matches and ask the user to confirm which paper they mean, unless only one result is returned or the top result is a near-exact title match. Use the confirmed paper's ID for the next step.

If no results are found, suggest the user check the title or try keywords from it. Stop here.

### Step 2: Find similar papers

Call `find_similar_papers` with:
- `paper_id` (string): the resolved paper ID
- `limit` (integer): 10

If the paper has no embedding and returns an error, tell the user that semantic similarity is not available for this paper and suggest trying `semantic_search_papers` with keywords from its abstract instead. Stop here.

### Step 3: Enrich results (if needed)

The results from Step 2 already include metadata (title, authors, abstract, categories). If any result is missing abstract or author data, call `get_paper_by_id` for those papers.

## Output format

### Source paper

Display the seed paper's details:
- **Title**: full title
- **Authors**: first 5, then "et al." if more
- **Year**: publication year
- **Source**: which server (arXiv, bioRxiv, etc.)
- **Abstract**: first 2-3 sentences

### Similar papers

A numbered list ranked by similarity. For each paper:
- **Title** (with paper ID)
- **Authors**: first 3, then "et al." if more
- **Year**
- **Category**
- **Abstract summary**: one sentence capturing the paper's contribution

### Suggested follow-ups

- "Profile `<author>`" — for any author that appears in multiple similar papers
- "Papers similar to `<paper_id>`" — to continue exploring from any listed paper
