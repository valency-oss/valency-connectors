---
name: valency-fresh-collaborators
description: "Use when the user asks who a researcher should be talking to beyond their strongest known collaborators, wants to find potential collaborators outside the returned top coauthor network, asks 'who else is doing this work', 'who should X meet', 'who are the new faces in this field', or wants to expand a researcher's collaboration network beyond their current circle. Triggers on requests to find recent, relevant researchers outside an author's returned strongest-coauthor list."
---

# Fresh Collaborators

Find researchers doing recent (last 12–18 months), thematically relevant work who are **outside the focal author's returned top-100 coauthor network**. This is a strongest-ties exclusion, not proof that a candidate has never coauthored with the focal author. Useful for expanding a researcher's collaborator pool, suggesting first-author candidates for new projects, or surfacing people for an upcoming conference / visit.

## Tool conventions

- Use the Valency Bond MCP tools available in the current agent (e.g., `semantic_search_papers`). Tool names may be qualified with an MCP server prefix; call the matching exposed tool.
- Never fabricate paper titles, authors, abstracts, or metadata. All data must come from tool results.
- If a tool returns no results, say so plainly and suggest a different spelling or query.
- Produce clean, scannable output with consistent markdown formatting.

## Input

The user provides an author name (e.g., "David W. Hogg", "Karl Friston").

Optional: a number of months for the recency window. If not specified, default to **18 months**.

## Tool chain

**Date discipline:** Compute the cutoff date as `today - <window_months>`, formatted as `YYYY-MM-DD`. Use this cutoff string consistently in Steps 3 and 5.

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

Build the **exclusion set** from stable author identifiers returned by the tools whenever they are available. Also retain the server-resolved canonical names and any returned aliases for the focal author and every coauthor. Use lowercase/trim/collapse-whitespace normalization only as a fallback; name-only matching does not reliably reconcile initials, punctuation, ordering, or diacritics.

Note: 100 is the maximum the tool accepts and represents the focal author's strongest collaborators. People who have co-authored only one or two papers may still appear. Describe results as fresh relative to the returned top-100 network, never as verified first-time collaborators.

### Step 3: Pull the focal author's recent papers (current themes)

Call `search_by_author` with:
- `author` (string): the resolved name
- `limit` (integer): 10
- `sort_by` (string): "relevance"
- `strict_mode` (string): "fuzzy"

The default `relevance` sort orders by recency, but sorting alone does not enforce the configured window. Inspect each returned paper's publication date and retain only papers dated on or after the computed cutoff. Do not infer that an undated paper is recent from its result position. The filtered papers represent the author's *current* intellectual direction within the requested window.

If no returned papers fall within the window, explain that there is not enough corpus evidence in the requested period to derive current themes and stop. If fewer than 4 dated, in-window papers remain, derive one explicitly evidence-limited theme from their titles and abstracts and disclose how many papers support it; do not invent a second theme.

### Step 4: Identify 1–4 current themes

If Step 3 returned at least 4 papers, identify **1 to 4 distinct themes** that characterize the author's recent work. Use one theme when all of the evidence supports a single coherent topic; do not split a topic merely to reach a minimum count. If Step 3 returned 1 to 3 papers, identify exactly **one evidence-limited theme** supported by every available paper and disclose the paper count. A theme is a short natural-language phrase (5–12 words) suitable as a semantic search query — not a category code.

Construct themes by reading the recent paper titles and abstracts. When at least 4 papers are available, each theme must be supported by at least two recent papers. The 1-to-3-paper fallback is exempt from the two-paper-per-theme requirement: use all available evidence and do not invent additional themes. If 4 or more recent papers cluster tightly, use one theme; if they span disparate topics, use up to 4.

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

If a theme returns fewer than 5 papers, report only the observed count and suggest broadening the query or recency window. Do not diagnose the theme as narrow or the field as sparse from retrieval yield alone.

### Step 6: Filter against the exclusion set

For each surviving paper, inspect its authors using stable identifiers first, then server-resolved canonical identities or returned aliases:

1. Drop the paper if the focal author appears anywhere in its author list.
2. Resolve the first author as the fresh-face candidate. Drop the candidate if that first author's identity is in the known-coauthor exclusion set.
3. Do not drop an otherwise fresh first-author candidate merely because a different author on the paper is a known coauthor.

If only name strings are available and the first author's identity is plausibly an ambiguous variant of the focal author or a known coauthor, conservatively exclude that candidate rather than presenting them as fresh.

This removes the focal author's own papers and first-author candidates found in the returned top-100 coauthor set. What remains is fresh relative to that capped, identity-resolved exclusion set.

### Step 7: Rank and categorize the fresh faces

For each remaining paper, identify the **first author** as the primary "fresh face" candidate (other authors are noted but secondary). For each unique first author across all surviving papers:

1. **Seniority tag.** Tag each candidate `[unclear]` by default. Use `[junior]` or `[senior]` only when the returned records contain explicit profile or publication-history evidence for that classification. Do not infer seniority from how often someone appears in this capped, recent, theme-specific result set, their author position, or their coauthors.

2. **Theme attribution.** Tag each candidate with which theme(s) surfaced them. Candidates surfaced by multiple themes are stronger matches and should be ranked higher.

3. **Deduplicate.** If the same first author appears via multiple papers, merge into a single entry and list all surfacing papers.

## Output format

### Author summary

A short block:
- **Focal author**: name (resolved), total papers, primary domains
- **Existing coauthor network size**: total from Step 2 (note that only the top 100 are in the exclusion set)
- **Recency window**: e.g. "Last 18 months (cutoff: 2024-10-07)"
- **Themes searched**: bullet list of the 1–4 themes selected in Step 4

### Fresh faces

A ranked list of fresh-face candidates. Rank by: (a) number of distinct themes that surfaced them, then (b) similarity scores of their surfacing papers.

For each candidate:

#### N. Author Name `[junior|senior|unclear]`

- **Surfaced by themes**: theme A; theme B (if multiple)
- **Surfacing paper(s)**: Title (paper ID), year, category
- **Why fresh**: confirmation that this resolved identity is not in the focal author's returned top-100 coauthor set; omit identity-ambiguous candidates
- **Why interesting**: one sentence on the connection to the focal author's current work

Show the top 10 candidates. If fewer than 10 survived, show all of them.

### Theme coverage notes

For each theme from Step 4, report the number of papers returned by the capped, date-restricted search and the number that survived exclusion filtering. Describe these only as search-coverage counts within the Valency corpus; do not infer that a field is crowded, sparse, or inactive from capped retrieval yield.

### Suggested follow-ups

- "Profile `<fresh_face_name>`" — for a deeper look at any candidate
- "Papers similar to `<surfacing_paper_id>`" — to find more work in that vein
- "Reading list for `<focal_author>`" — for the *what* to read alongside the *who* to meet
