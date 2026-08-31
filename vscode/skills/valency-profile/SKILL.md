---
name: valency-profile
description: "Use when the user asks about a researcher's work, publications, research areas, collaborators, or academic profile. Triggers on questions like 'who is X', 'what does X work on', 'show me X's papers', or 'tell me about X' in a research context."
---

# Researcher Profile

Build a comprehensive profile for the given researcher using the Valency research corpus.

## Tool conventions

- Use the Valency MCP tools available in the current agent (e.g., `get_author_profile`). Tool names may be qualified with an MCP server prefix; call the matching exposed tool.
- Never fabricate paper titles, authors, abstracts, or metadata. All data must come from tool results.
- If a tool returns no results, say so plainly and suggest a different spelling or query.
- Produce clean, scannable output with consistent markdown formatting.

## Input

The user provides an author name (e.g., "Yoshua Bengio", "Y. LeCun", "Sara Walker").

## Tool chain

Execute these steps in order.

### Step 1: Get author profile

Call `get_author_profile` with:
- `author` (string): the author name provided by the user

This returns summary stats including top categories, publication timeline, co-author count, and total papers.

If no results are found, tell the user the author was not found and suggest checking the spelling or trying a partial name. Stop here.

### Step 2: Get full publication list

Call `search_by_author` with:
- `author` (string): the author name
- `limit` (integer): 10
- `sort_by` (string): "citations"
- `strict_mode` (string): "fuzzy"

This returns the author's top papers sorted by citation count.

### Step 3: Get research domain distribution

Call `batch_author_categories` with:
- `authors` (array of strings): a JSON array containing the author name, e.g. `["David W. Hogg"]`
- `max_categories` (integer): 10

This returns the category distribution for the author's publications.

### Step 4: Get top collaborators

Call `find_coauthors` with:
- `author` (string): the author name
- `limit` (integer): 10

This returns the author's most frequent collaborators with co-publication counts.

## Output format

Present the results in this structure:

### Summary

A brief block with:
- **Name**: full name as it appears in the corpus
- **Total papers**: count from Step 1
- **Active years**: first paper year to last paper year
- **Primary domains**: top 3 categories from Step 3

### Research domains

A table of the top 5 categories from Step 3:

| Category | Papers |
|----------|--------|
| cs.LG    | 42     |
| ...      | ...    |

### Top papers

A numbered list of up to 10 papers from Step 2. For each paper show:
- Title (with paper ID)
- Year
- Categories

### Top collaborators

A table of up to 5 collaborators from Step 4:

| Collaborator | Co-authored papers |
|--------------|-------------------|
| Name         | 15                |
| ...          | ...               |

### Suggested follow-ups

- "Show me the network for `<author_name>`" — map their collaboration network
- "Find papers similar to `<paper_id>`" — find papers similar to their top work (use the ID of their most-cited paper)
