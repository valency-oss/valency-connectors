---
name: fresh-collaborators
description: "Use when the user asks who a researcher should be talking to that they aren't already, wants to find potential collaborators beyond the strongest returned coauthor name buckets, asks 'who else is doing this work', 'who should X meet', 'who are the new faces in this field', or wants to expand a researcher's collaboration network beyond their current circle. Triggers on requests to find recent, relevant researchers whose returned byline names do not match the focal name or one of the strongest returned top-100 coauthor name buckets."
---

# Fresh Collaborators

Find researchers attached to thematically relevant records updated in the last 12–18 months for which no returned byline name matches the focal name or one of the strongest returned top-100 coauthor name buckets. This is not proof that the researchers have never collaborated. Useful for expanding a researcher's collaborator pool, suggesting first-author candidates for new projects, or surfacing people for an upcoming conference / visit.

## Input

The user provides an author name (e.g., "David W. Hogg", "Karl Friston").

Optional: a number of months for the recency window. If not specified, default to **18 months**.

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

**Date discipline:** Compute the cutoff date as `today - <window_months>`, formatted as `YYYY-MM-DD`. Use this cutoff string consistently in Step 5.

### Step 1: Resolve the author and get profile context

Call `get_author_identity` with:
- `author` (string): the author name

If `candidates` are returned, ask for an ORCID or identifying paper before continuing. If the identity is unverifiable or not found, say so and stop. Carry forward the selected display name and ORCID when returned.

Then call `get_author_profile` with:
- `author` (string): the selected display name
- `orcid` (string, when returned): the resolved ORCID

Note from the profile:
- The `resolved_name`, used as a normalized corpus name bucket for the coauthor call
- The top 5 categories (you'll use these in Step 4 to select themes)
- The total paper count (sets context for the network size)

Inspect and report warnings from both calls.

### Step 2: Build the exclusion set (returned coauthor name buckets)

Call `find_coauthors` with:
- `author` (string): the resolved name from Step 1
- `limit` (integer): 100

Build the **exclusion set** from every returned `coauthor` / `coauthor_norm` name bucket, plus the focal author's `resolved_name` itself.

This call returns at most 100 of the strongest coauthor name buckets and has no pagination. Name variants may split across buckets, and weaker coauthors may be absent. Inspect and report warnings and `_meta.limit_clamped`; describe the exclusion only as the returned top-100 name buckets.

### Step 3: Pull the focal author's record-recent papers (current themes)

Call `find_papers_by_researcher` with:
- `orcid` (string): the resolved ORCID when Step 1 returned one
- otherwise `author` (string): the selected display name
- `limit` (integer): 10
- `sort_by` (string): "recency"

Inspect `candidates`, `disambiguation_status`, each paper's `match_type`, warnings, returned count, and cap. Stop if the result is `unverifiable`; visibly qualify ambiguous, name-only, or incomplete results. This is record-recency ordering, not publication chronology. Use the returned papers as evidence of the author's *current* intellectual direction with that qualification.

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
- `max_authors` (integer): 500

`start_date` is a server-side `datestamp` prefilter: it restricts the search by source record/update date, not publication date, and does not establish that every result was recently first-submitted. Inspect and report warnings, empty results, and clamping.

If a theme returns fewer than 5 papers, that theme is too narrow or the corpus is too sparse for this query and record-date window. Note this in the output but do not stop.

### Step 6: Filter against the exclusion set

For each surviving paper, compare every returned `authors` name (after normalization — lowercase, strip extra whitespace) with the focal-name and top-100 coauthor bucket keys built in Step 2. **Drop any paper** for which any returned author name matches.

Also drop papers with an empty byline or `authors_truncated: true` after requesting 500 authors: they cannot substantiate that the focal author and excluded coauthor buckets are absent. State only that the retained complete returned bylines contained no matching focal or top-100 bucket name.

### Step 7: Rank and categorize the fresh faces

For each remaining paper, identify the **first-author name bucket** as the primary "fresh face" candidate (other returned authors are noted but secondary). Treat each as a paper occurrence rather than proof of a unique person. For each first-author name bucket across all surviving papers:

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
- **Why fresh**: explicit confirmation that no returned byline name matched the focal name or a returned top-100 coauthor name bucket, qualified if the byline was empty or truncated
- **Why interesting**: one sentence on the connection to the focal author's current work

Show the top 10 candidates. If fewer than 10 survived, show all of them. Never label `first_submitted` or `datestamp` as a publication date or year.

### Theme Coverage Notes

For each theme from Step 4, report the number of papers returned by the record-date-prefiltered search and the number that survived exclusion filtering. Sparse results characterize only this query and record-date window; they do not show that no one is working on the theme.

### Suggested Follow-ups

- Ask for a profile of `<fresh_face_name>` for a deeper look at any candidate.
- Ask for papers similar to `<surfacing_paper_id>` to find more work in that vein.
- Ask for a reading list for `<focal_author>` for the *what* to read alongside the *who* to meet.
