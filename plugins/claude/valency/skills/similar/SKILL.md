---
name: similar
description: "Use when the user wants to find papers similar to a specific paper, asks 'what's related to this paper', 'find me more like this', or wants to explore the neighborhood around a known paper. Triggers on paper IDs, arXiv IDs, DOIs, or paper titles followed by a similarity request. Also invokable as /valency:similar <paper_id_or_title>."
---

# Similar Papers

Find papers semantically similar to a given paper.

## Input

The user provides either:
- A paper identifier — one of:
  - arXiv ID (e.g., `0704.0001`, `2301.07041v3`, `arXiv:2301.07041`, or `hep-th/9901001`)
  - DOI (e.g., `10.1101/2024.01.15.575423` or any `10.<4-9 digits>/...` pattern)
  - PubMed ID / PMID (digits only, e.g., `26360422`)
- A paper title (including a one-word title)

**Identifier detection rules:**
- If the input is digits only → treat as PMID
- If the input matches `10\.\d{4,9}/\S+` → treat as DOI (covers bioRxiv, medRxiv, and other DOI-minted sources)
- If the input, optionally prefixed by `arXiv:`, matches a modern arXiv ID (`YYMM.NNNN` or `YYMM.NNNNN`, optionally with a `vN` suffix) → treat as arXiv ID
- If the input, optionally prefixed by `arXiv:`, matches a legacy archive-style ID such as `hep-th/9901001` (optionally with a `vN` suffix) → treat as arXiv ID
- Otherwise → treat as a title and resolve via search

Do not assume all bioRxiv records use the `10.1101/...` prefix. Newer records may use other DOI prefixes.

## Tool Chain

### Step 1: Resolve paper ID (if needed)

**If the input is a paper ID** (arXiv ID, DOI, or PMID):

Call `get_paper_by_id` with:
- `paper_id` (string): the provided ID

If no paper is found for a digits-only input, it may be a numeric title rather than a PMID. Fall back to `search_by_title` using the original input and follow the title-resolution path below. For any other identifier type, tell the user the ID was not recognized and suggest searching by title instead. Stop here.

**If the input does not match any supported paper-identifier pattern:**

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

## Output Format

### Source Paper

Display the seed paper's details:
- **Title**: full title
- **Authors**: first 5, then "et al." if more
- **Year**: publication year
- **Source**: which server (arXiv, bioRxiv, etc.)
- **Abstract**: first 2-3 sentences

### Similar Papers

A numbered list ranked by similarity. For each paper:
- **Title** (with paper ID)
- **Authors**: first 3, then "et al." if more
- **Year**
- **Category**
- **Abstract summary**: one sentence capturing the paper's contribution

### Suggested Follow-ups

- `/valency:profile <author>` — for any author that appears in multiple similar papers
- `/valency:similar <paper_id>` — to continue exploring from any listed paper
