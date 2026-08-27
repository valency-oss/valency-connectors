---
name: reading-list
description: "Use when the user asks what a researcher should be reading, wants a curated bibliography for a researcher's interests, asks 'what should X read', 'find me adjacent work to X's research', or wants to know what literature surrounds an author's body of work. Triggers on reading-list, bibliography, or 'what should I read next' style requests anchored on a specific researcher."
---

# Researcher Reading List

Build a curated reading list for a researcher, organized by intellectual thread, by triangulating off representative record-recent and highest citation-ranked returned work.

## Input

The user provides an author name (e.g., "David W. Hogg", "Yoshua Bengio", "Jennifer Doudna").

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

### Step 1: Resolve the author and get profile context

Call `get_author_identity` with:
- `author` (string): the author name provided by the user

If `candidates` are returned, ask for an ORCID or identifying paper before continuing. If the identity is unverifiable or not found, say so and stop. Carry forward the selected display name and ORCID when returned.

Then call `get_author_profile` with:
- `author` (string): the selected display name
- `orcid` (string, when returned): the resolved ORCID

Note the profile's top categories for later theme interpretation. Use `resolved_name` as a normalized corpus name bucket for self-authorship matching, not as proof of identity. Inspect and report warnings from both calls.

### Step 2: Get citation-ranked papers (career anchors)

Call `find_papers_by_researcher` with:
- `orcid` (string): the resolved ORCID when Step 1 returned one
- otherwise `author` (string): the selected display name
- `limit` (integer): 5
- `sort_by` (string): "citations"

Inspect `candidates`, `disambiguation_status`, each paper's `match_type`, warnings, returned count, and cap. Stop if the result is `unverifiable`; visibly qualify ambiguous, name-only, or incomplete results. Citations are nullable, best-effort enrichment, so these are only the highest citation-ranked results returned, not necessarily the author's career maxima.

### Step 3: Get record-recent papers (current direction)

Call `find_papers_by_researcher` with:
- `orcid` (string): the resolved ORCID when Step 1 returned one
- otherwise `author` (string): the selected display name
- `limit` (integer): 5
- `sort_by` (string): "recency"

Inspect `candidates`, `disambiguation_status`, each paper's `match_type`, warnings, returned count, and cap. Stop if the result is `unverifiable`; visibly qualify ambiguous, name-only, or incomplete results. These are the first record-recent results returned, not publication chronology. They may represent the author's *current* intellectual direction with that qualification.

### Step 4: Select 3–5 representative seed papers

From the combined Step 2 + Step 3 results, select 3 to 5 **seed papers** that best represent the author's distinct intellectual threads:

- Always include the first highest citation-ranked result returned (career anchor).
- Always include the first record-recent result returned that has a substantive abstract (current direction).
- Fill the remaining slots by picking papers whose titles and available metadata support different threads. Source-specific category-list differences alone do not establish distinct intellectual threads.

If two papers have nearly identical category lists and similar topics, pick only one.

### Step 5: Find similar papers for each seed

For each seed paper from Step 4, call `find_similar_papers` with:
- `paper_id` (string): the seed paper's ID
- `limit` (integer): 10
- `include_abstract` (boolean): false
- `max_authors` (integer): 500

If a seed paper has no embedding, the call succeeds with an empty result and a warning; mark that seed as skipped and continue with the others. Treat an actual error separately. Inspect warnings, empty results, and clamp metadata.

### Step 6: Aggregate and clean

After all `find_similar_papers` calls complete:

1. **Tag each result** with the seed paper that surfaced it.
2. **Deduplicate by paper family** — use `(source, base_id ?? id)` as the family key so versions share a family without conflating identifiers from different sources. If a family appears in multiple seeds' similar lists, keep the entry with the highest similarity score and merge the seed tags.
3. **Filter out returned self-authorship matches** — drop any paper whose returned author list contains the focal `resolved_name` bucket from Step 1. Also drop papers with an empty byline or `authors_truncated: true` after requesting 500 authors, because absence cannot be established.
4. **Group by seed** — partition the cleaned results by which seed paper(s) surfaced them. This grouping defines the reading-list "threads."

## Output Format

### Researcher Summary

A short block:
- **Name**: full name as it appears in the corpus
- **Total papers**: from Step 1
- **Primary domains**: top 3 categories from Step 1

### Reading List by Thread

For each seed paper from Step 4, produce a thread section:

#### Thread N: <one-line characterization of the thread>

Anchored by the seed paper:
- **Seed**: Title (paper ID), available `first_submitted` estimate or source record/update `datestamp`, source-specific categories as returned

Recommended reading (up to 8 papers per thread, ordered by similarity score; fewer or zero is valid after caps, empty results, and filtering):

1. **Title** (paper ID) — first 3 returned authors, with truncation or unknown authors labeled; available `first_submitted` estimate or source record/update `datestamp`; source-specific categories as returned — one-sentence reason it matters here
2. ...

Never label `first_submitted` or `datestamp` as a publication date or year. `first_submitted` is a first-submission estimate for arXiv, bioRxiv, and medRxiv, and a record-derived month estimate otherwise; `datestamp` is a source record/update date.

If a seed paper was skipped because it had no embedding, add a note under that thread: *"This seed had no embedding; no similar papers could be retrieved."*

### Cross-Thread Highlights

If any paper appeared as similar to **multiple** seeds, highlight it as a cross-thread find — these are often the most interesting recommendations because they sit at the intersection of the author's threads:

- **Title** (paper ID) — surfaced by Seed A *and* Seed C — why this matters

If no cross-thread papers were found, omit this section.

### Suggested Follow-ups

- Ask for a profile of `<author>` for any author that appears across multiple recommendations.
- Ask for papers similar to `<paper_id>` to dig deeper into any specific recommendation.
- Ask for fresh collaborators for `<author>` when the user is interested in *who* (not what) to engage with next.
