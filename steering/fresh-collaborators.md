---
name: fresh-collaborators
description: "Use when the user asks who a researcher should be talking to that they aren't already, wants to find new potential collaborators outside an existing network, asks 'who else is doing this work', 'who should X meet', 'who are the new faces in this field', or wants to expand a researcher's collaboration network beyond their current circle. Triggers on requests to find recent, relevant researchers who are NOT in an author's existing coauthor list."
---

# Fresh Collaborators

Find researchers doing recent (last 12–18 months), thematically relevant work who are **not** in the focal author's existing coauthor network. Useful for expanding a researcher's collaborator pool, suggesting first-author candidates for new projects, or surfacing people for an upcoming conference / visit.

## Input

The user provides an author name (e.g., "David W. Hogg", "Karl Friston").

Optional: a number of months for the recency window. If not specified, default to **18 months**.

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

**Date discipline:** Compute the cutoff date as `today - <window_months>`, formatted as `YYYY-MM-DD`. Use this cutoff string consistently in Step 5.

### Step 1: Verify the author exists

Call `get_author_profile` with:
- `author` (string): the author name

If no results are found, tell the user the author was not found. Stop here.

Note from this result:
- The `resolved_name`
- The top 5 categories (you'll use these in Step 4 to select themes)
- The total paper count (sets context for the network size)

### Step 2: Build the exclusion set (existing coauthor network)

Call `find_coauthors` with:
- `author` (string): the resolved name from Step 1
- `limit` (integer): 100

Build the **exclusion set**: a set of normalized names containing every `coauthor_norm` from this result, plus the focal author's `resolved_name` itself.

Note: 100 is the maximum the tool accepts and represents the focal author's strongest collaborators. People who have co-authored only one or two papers may still slip through as "fresh" — that is acceptable, since one-paper coauthors are weak ties and reconnecting with them is also useful.

### Step 3: Pull the focal author's recent papers (current themes)

Call `search_by_author` with:
- `author` (string): the resolved name
- `limit` (integer): 10
- `sort_by` (string): "relevance"
- `strict_mode` (string): "fuzzy"

The default `relevance` sort orders by recency. These 10 papers represent the author's *current* intellectual direction.

### Step 4: Identify 2–4 current themes

From the Step 3 papers, identify **2 to 4 distinct themes** that characterize the author's recent work. A theme is a short natural-language phrase (5–12 words) suitable as a semantic search query — not a category code.

Construct themes by reading the recent paper titles and abstracts. For each theme, you should be able to point to at least two of the recent papers as evidence. If the recent papers cluster tightly, 2 themes is fine; if they span disparate topics, use up to 4.

Examples of well-formed themes:
- "Bayesian experimental design for cosmological survey forecasting"
- "Equivariant neural networks for stellar abundance prediction"
- "Metacognitive uncertainty in human and machine inference"

Bad themes (too narrow or too broad):
- "stars" (too broad)
- "Section 4 of the 2025 paper on REACH 21cm calibration" (too narrow / not a search query)

### Step 5: Search for recent work in each theme

For each theme from Step 4, call `semantic_search_papers` with:
- `query` (string): the theme phrase
- `start_date` (string): the cutoff date computed in the Date discipline section, `YYYY-MM-DD`
- `limit` (integer): 25
- `sort_by` (string): "relevance"
- `include_abstract` (boolean): false

Passing `start_date` restricts the server-side similarity search to papers published on or after the cutoff, so every result is recent by construction — no in-memory date filtering needed.

If a theme returns fewer than 5 papers, that theme is too narrow or the corpus is too sparse for the recency window. Note this in the output but do not stop.

### Step 6: Filter against the exclusion set

For each surviving paper, inspect its `authors` list. **Drop any paper** for which **any author** in the list (after normalization — lowercase, strip extra whitespace) appears in the exclusion set built in Step 2.

This removes papers by the focal author themselves, by their direct collaborators, and by anyone in the top-100 coauthor network. What remains is, by construction, "fresh."

### Step 7: Rank and categorize the fresh faces

For each remaining paper, identify the **first author** as the primary "fresh face" candidate (other authors are noted but secondary). For each unique first author across all surviving papers:

1. **Junior/senior heuristic.** Without making additional tool calls, infer junior vs senior from signals available in the paper records: number of papers in the result set (1 = likely junior; many = likely established), position of the focal-author-adjacent name in the author list, and seniority cues from coauthors. Tag each candidate `[junior]`, `[senior]`, or `[unclear]`.

2. **Theme attribution.** Tag each candidate with which theme(s) surfaced them. Candidates surfaced by multiple themes are stronger matches and should be ranked higher.

3. **Deduplicate.** If the same first author appears via multiple papers, merge into a single entry and list all surfacing papers.

## Output Format

### Author Summary

A short block:
- **Focal author**: name (resolved), total papers, primary domains
- **Existing coauthor network size**: total from Step 2 (note that only the top 100 are in the exclusion set)
- **Recency window**: e.g. "Last 18 months (cutoff: 2024-10-07)"
- **Themes searched**: bullet list of the 2–4 themes from Step 4

### Fresh Faces

A ranked list of fresh-face candidates. Rank by: (a) number of distinct themes that surfaced them, then (b) similarity scores of their surfacing papers.

For each candidate:

#### N. Author Name `[junior|senior|unclear]`

- **Surfaced by themes**: theme A; theme B (if multiple)
- **Surfacing paper(s)**: Title (paper ID), year, category
- **Why fresh**: explicit confirmation that this person is **not** in the focal author's top-100 coauthor list
- **Why interesting**: one sentence on the connection to the focal author's current work

Show the top 10 candidates. If fewer than 10 survived, show all of them.

### Theme Coverage Notes

For each theme from Step 4, report the number of papers returned by the date-restricted search and the number that survived exclusion filtering. This helps the user see which themes are crowded (lots of fresh activity) vs sparse (no one is doing this).

### Suggested Follow-ups

- Ask for a profile of `<fresh_face_name>` for a deeper look at any candidate.
- Ask for papers similar to `<surfacing_paper_id>` to find more work in that vein.
- Ask for a reading list for `<focal_author>` for the *what* to read alongside the *who* to meet.
