---
name: fresh-collaborators
description: "Use when the user asks who a researcher should be talking to that they aren't already, wants to find new potential collaborators outside an existing network, asks 'who else is doing this work', 'who should X meet', 'who are the new faces in this field', or wants to expand a researcher's collaboration network beyond their current circle. Triggers on requests to find recent, relevant researchers who are not among an author's top coauthor matches."
---

# Fresh Collaborators

Find researchers doing thematically relevant work in records updated in the last 12–18 months whose complete returned bylines do **not** match the focal author's name bucket or the strongest returned top-100 coauthor name buckets. This does not prove that the researchers have never collaborated. Useful for expanding a researcher's collaborator pool, suggesting first-author candidates for new projects, or surfacing people for an upcoming conference / visit.

## Input

The user provides an author name (e.g., "David W. Hogg", "Karl Friston").

Optional: a number of months for the recency window. If not specified, default to **18 months**.

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

For each call, distinguish a tool error from a successful empty result and
surface material `warnings`.

**Date discipline:** Compute the cutoff date as `today - <window_months>`, formatted as `YYYY-MM-DD`. Use this cutoff string consistently as the source record/update-date filter in Steps 3 and 5.

### Step 1: Verify the author exists

Call `get_author_profile` with:
- `author` (string): the author name

If no results are found, tell the user the author was not found. Stop here.

Note from this result:
- The `resolved_name`, treated as a normalized corpus name bucket rather than proof of a unique identity
- The top 5 categories (you'll use these in Step 4 to select themes)
- The total paper count (sets context for the author summary)

### Step 2: Build the exclusion set (returned coauthor name buckets)

Call `find_coauthors` with:
- `author` (string): the resolved name from Step 1
- `limit` (integer): 100

Build the **exclusion set** from every returned `coauthor_norm` matching key, plus the normalized focal `resolved_name`. Use `coauthor` only as the display value; use `coauthor_norm` for matching.

This call returns at most 100 of the strongest coauthor name buckets and has no pagination. Name variants may split across buckets, and weaker coauthors may be absent — acceptable, since reconnecting with a weak tie is also useful. Describe the exclusion only as the returned top-100 name buckets.

### Step 3: Pull the focal author's record-window papers (current themes)

Call `search_by_author` with:
- `author` (string): the resolved name
- `limit` (integer): 10
- `sort_by` (string): "relevance"
- `strict_mode` (string): "fuzzy"
- `start_date` (string): the cutoff date computed in the Date discipline section, `YYYY-MM-DD`

These are up to 10 relevance-ranked author matches from the source record/update-date window, not a definitive list of the author's most recently published papers. Use them as evidence of the author's *current* intellectual direction with that qualification.

### Step 4: Identify 2–4 current themes

From the Step 3 papers, identify **2 to 4 distinct themes** that characterize the author's work in the record-date window. A theme is a short natural-language phrase (5–12 words) suitable as a semantic search query — not a category code.

Construct themes by reading the record-window paper titles and abstracts. For each theme, you should be able to point to at least two of those papers as evidence. If the papers cluster tightly, 2 themes is fine; if they span disparate topics, use up to 4.

Examples of well-formed themes:
- "Bayesian experimental design for cosmological survey forecasting"
- "Equivariant neural networks for stellar abundance prediction"
- "Metacognitive uncertainty in human and machine inference"

Bad themes (too narrow or too broad):
- "stars" (too broad)
- "Section 4 of the 2025 paper on REACH 21cm calibration" (too narrow / not a search query)

### Step 5: Search for record-window work in each theme

For each theme from Step 4, call `semantic_search_papers` with:
- `query` (string): the theme phrase
- `start_date` (string): the cutoff date computed in the Date discipline section, `YYYY-MM-DD`
- `limit` (integer): 25
- `sort_by` (string): "relevance"
- `include_abstract` (boolean): false
- `max_authors` (integer): 500

`start_date` is a server-side `datestamp` prefilter: it restricts semantic search by source record/update date, not publication date, and does not establish that every result was recently first-submitted.

If a theme returns fewer than 5 papers, that theme is too narrow or the corpus is too sparse for this query and record-date window. Note this in the output but do not stop.

### Step 6: Filter against the exclusion set

For each surviving paper, compare every returned `authors` name (after normalization — lowercase, strip accents/diacritics, collapse whitespace) with the focal-name and top-100 `coauthor_norm` matching keys built in Step 2. **Drop any paper** for which any returned author name matches.

Also drop papers with an empty byline or `authors_truncated: true` after requesting 500 authors: an incomplete returned byline cannot substantiate that the focal or excluded coauthor name buckets are absent. The retained papers therefore establish only that their complete returned bylines contained no matching focal or top-100 bucket name.

### Step 7: Rank and categorize the fresh faces

For each remaining paper, identify the **first-author name bucket** as the primary "fresh face" candidate (other returned authors are noted but secondary). Treat each candidate as a name bucket attached to paper occurrences rather than proof of a unique person. For each first-author name bucket across all surviving papers:

1. **Junior/senior heuristic.** Without making additional tool calls, infer junior vs senior from signals available in the paper records: number of papers in the result set (1 = likely junior; many = likely established), position of the focal-author-adjacent name in the author list, and seniority cues from coauthors. Tag each candidate `[junior]`, `[senior]`, or `[unclear]`.

2. **Theme attribution.** Tag each candidate with which theme(s) surfaced them. Candidates surfaced by multiple themes are stronger matches and should be ranked higher.

3. **Deduplicate paper occurrences.** Group matching first-author display strings as a name bucket and list all surfacing papers, without claiming that the grouped records prove a unique person.

## Output Format

### Author Summary

A short block:
- **Focal author**: name (resolved), total papers, primary domains
- **Returned coauthor name-bucket count**: count from Step 2 (at most 100; weaker coauthors may be absent)
- **Record-date window**: e.g. "Last 18 months by source record/update date (cutoff: 2024-10-07)"
- **Themes searched**: bullet list of the 2–4 themes from Step 4

### Fresh Faces

A ranked list of fresh-face name-bucket candidates. Rank by: (a) number of distinct themes that surfaced them, then (b) the semantic-search `final_score` values of their surfacing papers.

For each candidate:

#### N. Author Name `[junior|senior|unclear]`

- **Surfaced by themes**: theme A; theme B (if multiple)
- **Surfacing paper(s)**: Title (paper ID), available `first_submitted` estimate or source record/update `datestamp`, source-specific categories as returned
- **Why fresh**: explicit confirmation that no name in the complete returned byline matched the focal name or a returned top-100 coauthor name bucket
- **Why interesting**: one sentence on the connection to the focal author's current work

Show the top 10 candidates. If fewer than 10 survived, show all of them. Date fields are source-aware: `first_submitted` is a first-submission estimate for supported preprint sources and a record-derived month estimate otherwise; `datestamp` is a source record/update date. Neither is a publication date.

### Theme Coverage Notes

For each theme from Step 4, report the number of papers returned by the record-date-prefiltered search and the number that survived exclusion filtering. Sparse results characterize only this query and record-date window; they do not show that no one is working on the theme.

### Suggested Follow-ups

- Ask for a profile of `<fresh_face_name>` for a deeper look at any candidate.
- Ask for papers similar to `<surfacing_paper_id>` to find more work in that vein.
- Ask for a reading list for `<focal_author>` for the *what* to read alongside the *who* to meet.
