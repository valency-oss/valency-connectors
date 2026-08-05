---
name: profile
description: "Use when the user asks about a researcher's work, publications, research areas, collaborators, or academic profile. Triggers on questions like 'who is X', 'what does X work on', 'show me X's papers', or 'tell me about X' in a research context. Also invokable as /valency:profile <author_name>."
---

# Researcher Profile

Build a comprehensive profile for the given researcher.

## Input

The user provides an author name (e.g., "Yoshua Bengio", "Y. LeCun", "Sara Walker").

## Tool Chain

Execute these steps in order. Use the bundled Valency Bond MCP tools, exposed as `mcp__plugin_valency_valency__<tool>`.

### Step 1: Get author profile

Call `get_author_profile` with:
- `author` (string): the author name provided by the user

This returns summary stats including top categories, publication timeline, co-author count, and total papers.

If no results are found, tell the user the author was not found and suggest checking the spelling or trying a partial name. Stop here.

Store the returned `resolved_name` and use it for every subsequent author-based call.

### Step 2: Get full publication list

Call `search_by_author` with:
- `author` (string): the `resolved_name` from Step 1
- `limit` (integer): 10
- `sort_by` (string): "citations"
- `strict_mode` (string): "fuzzy"

This returns the author's top papers sorted by citation count.

### Step 3: Get research domain distribution

Call `batch_author_categories` with:
- `authors` (array of strings): a JSON array containing the `resolved_name` from Step 1, e.g. `["David W. Hogg"]`
- `max_categories` (integer): 10

This returns the category distribution for the author's publications.

### Step 4: Get top collaborators

Call `find_coauthors` with:
- `author` (string): the `resolved_name` from Step 1
- `limit` (integer): 10

This returns the author's most frequent collaborators with co-publication counts.

## Output Format

Present the results in this structure:

### Summary

A brief block with:
- **Name**: full name as it appears in the corpus
- **Total papers**: count from Step 1
- **Active years**: first paper year to last paper year
- **Primary domains**: top 3 categories from Step 3

### Research Domains

A table of the top 5 categories from Step 3:

| Category | Papers |
|----------|--------|
| cs.LG    | 42     |
| ...      | ...    |

### Top Papers

A numbered list of up to 10 papers from Step 2. For each paper show:
- Title (with paper ID)
- Year
- Categories

### Top Collaborators

A table of up to 5 collaborators from Step 4:

| Collaborator | Co-authored papers |
|--------------|-------------------|
| Name         | 15                |
| ...          | ...               |

### Suggested Follow-ups

- `/valency:network <author_name>` — map their collaboration network
- `/valency:similar <paper_id>` — find papers similar to their top work (use the ID of their most-cited paper)
