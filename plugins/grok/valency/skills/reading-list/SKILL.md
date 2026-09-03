---
name: reading-list
description: "Use when the user asks what a researcher should be reading, wants a curated bibliography for a researcher's interests, asks 'what should X read', 'find me adjacent work to X's research', or wants to know what literature surrounds an author's body of work. Triggers on reading-list, bibliography, or 'what should I read next' style requests anchored on a specific researcher."
---

# Researcher Reading List

Build a curated reading list for a researcher, organized by intellectual thread, by triangulating off representative relevance-ranked and highest citation-ranked returned work.

## Input

The user provides an author name (e.g., "David W. Hogg", "Yoshua Bengio", "Jennifer Doudna").

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

For each call, distinguish a tool error from a successful empty result and
surface material `warnings`.

### Step 1: Verify the author exists

Call `get_author_profile` with:
- `author` (string): the author name provided by the user

If no results are found, tell the user the author was not found and suggest checking the spelling or trying a partial name. Stop here.

Note the author's top categories from this result — you'll use them later to interpret which themes the reading list is covering. Also note the resolved author name (`resolved_name`) — use it consistently in subsequent calls and when filtering returned self-authorship matches.

### Step 2: Get citation-ranked papers (career-anchor candidates)

Call `search_by_author` with:
- `author` (string): the resolved name
- `limit` (integer): 5
- `sort_by` (string): "citations"
- `strict_mode` (string): "fuzzy"

These are the highest citation-ranked results returned within this query's scope and available citation coverage, not necessarily the author's definitive most-cited works. Citation counts are nullable, best-effort enrichment.

### Step 3: Get relevance-ranked papers (current-direction evidence)

Call `search_by_author` with:
- `author` (string): the resolved name
- `limit` (integer): 5
- `sort_by` (string): "relevance"
- `strict_mode` (string): "fuzzy"

These are the first relevance-ranked results returned, not a definitive list of the author's most recent publications. They may represent the author's *current* intellectual direction with that qualification.

### Step 4: Select 3–5 representative seed papers

From the combined Step 2 + Step 3 results, select 3 to 5 **seed papers** that best represent the author's distinct intellectual threads:

- Always include the first citation-ranked result returned (career-anchor candidate).
- Always include, from the Step 3 pool, the paper with the latest `first_submitted` or `datestamp` that has a substantive abstract (current-direction candidate).
- Fill the remaining slots by picking papers whose titles and available metadata support different threads. Source-specific category-list differences alone do not establish distinct intellectual threads.

If two papers have nearly identical category lists and similar topics, pick only one.

### Step 5: Find similar papers for each seed

For each seed paper from Step 4, call `find_similar_papers` with:
- `paper_id` (string): the seed paper's ID
- `limit` (integer): 10
- `include_abstract` (boolean): false
- `max_authors` (integer): 500

If the successful response has `count: 0` and `papers: []` with a warning that the seed has no embedding, mark that seed as skipped and continue with the others. Do not report this as a tool error; treat a genuine error envelope separately.

### Step 6: Aggregate and clean

After all `find_similar_papers` calls complete:

1. **Tag each result** with the seed paper that surfaced it.
2. **Deduplicate by paper family** — use `(source, base_id ?? id)` as the family key so versions share a family without conflating identifiers from different sources. If a family appears in multiple seeds' similar lists, keep the entry with the highest similarity score and merge the seed tags.
3. **Filter out returned self-authorship matches** — drop any paper whose returned author list contains a name matching the focal `resolved_name` from Step 1 after normalization (lowercase, strip accents/diacritics, collapse whitespace). Also drop papers with an empty byline or `authors_truncated: true` after requesting 500 authors, because an incomplete returned byline cannot establish the focal name bucket's absence.
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

1. **Title** (paper ID) — first 3 returned authors; available `first_submitted` estimate or source record/update `datestamp`; source-specific categories as returned — one-sentence reason it matters here
2. ...

Date fields are source-aware: `first_submitted` is a first-submission estimate for supported preprint sources and a record-derived month estimate otherwise; `datestamp` is a source record/update date. Neither is a publication date.

If a seed paper was skipped because it had no embedding, add a note under that thread: *"This seed had no embedding; no similar papers could be retrieved."*

### Cross-Thread Highlights

If any paper appeared as similar to **multiple** seeds, highlight it as a cross-thread find — these are often the most interesting recommendations because they sit at the intersection of the author's threads:

- **Title** (paper ID) — surfaced by Seed A *and* Seed C — why this matters

If no cross-thread papers were found, omit this section.

### Suggested Follow-ups

- Ask for a profile of `<author>` for any author that appears across multiple recommendations.
- Ask for papers similar to `<paper_id>` to dig deeper into any specific recommendation.
- Ask for fresh collaborators for `<author>` when the user is interested in *who* (not what) to engage with next.
