---
name: reading-list
description: "Use when the user asks what a researcher should be reading, wants a curated bibliography for a researcher's interests, asks 'what should X read', 'find me adjacent work to X's research', or wants to know what literature surrounds an author's body of work. Triggers on reading-list, bibliography, or 'what should I read next' style requests anchored on a specific researcher. Also invokable as /valency:reading-list <author_name>."
---

# Researcher Reading List

Build a curated reading list for a researcher, organized by intellectual thread, by triangulating off their most representative recent and most-cited work.

## Input

The user provides an author name (e.g., "David W. Hogg", "Yoshua Bengio", "Jennifer Doudna").

## Tool Chain

### Step 1: Verify the author exists

Call `get_author_profile` with:
- `author` (string): the author name provided by the user

If no results are found, tell the user the author was not found and suggest checking the spelling or trying a partial name. Stop here.

Note the author's top categories from this result — you'll use them later to interpret which themes the reading list is covering. Also note the resolved author name (`resolved_name`) — use it consistently in subsequent calls and when filtering self-citations.

### Step 2: Get top-cited papers (career anchors)

Call `search_by_author` with:
- `author` (string): the `resolved_name` from Step 1
- `limit` (integer): 5
- `sort_by` (string): "citations"
- `strict_mode` (string): "fuzzy"

These are the author's most influential works — they anchor the "what defined their career so far" threads.

### Step 3: Get recent papers (current direction)

Call `search_by_author` with:
- `author` (string): the `resolved_name` from Step 1
- `limit` (integer): 5
- `sort_by` (string): "relevance"
- `strict_mode` (string): "fuzzy"

The default `relevance` sort orders by recency. These represent the author's *current* intellectual direction, which may differ from their most-cited work.

### Step 4: Select 1–5 representative seed papers

Deduplicate the combined Step 2 + Step 3 results. If no papers remain, explain that the corpus has no usable paper records for this author and stop. Group the papers into distinct, evidence-supported intellectual threads, then select at most one representative **seed paper** per thread, up to 5 seeds. When at least 3 distinct threads are available, select 3 to 5 seeds. When only 1 or 2 distinct threads are supported, select 1 or 2 seeds and disclose that fewer than 3 were chosen to avoid redundant threads.

- Prefer the single most-cited paper as the representative of its thread when available (career anchor).
- Prefer the most recent paper with a substantive abstract as the representative of its thread when available (current direction). If no recent paper has an abstract, the most recent available paper may represent that thread; state that abstract-based theme interpretation is limited.
- Fill the remaining slots by picking papers whose category lists differ — i.e. cover different threads of the author's work, not five papers in the same subfield.

If two papers have nearly identical category lists and similar topics, pick only one.

### Step 5: Find similar papers for each seed

For each seed paper from Step 4, call `find_similar_papers` with:
- `paper_id` (string): the seed paper's ID
- `limit` (integer): 10
- `include_abstract` (boolean): false

If a seed paper has no embedding and the call returns an error, skip that seed and continue with the others. Note the skip in the output.

If every seed is skipped or no similar papers are returned, report the seed papers and the retrieval limitation, then stop without inventing recommendations.

### Step 6: Aggregate and clean

After all `find_similar_papers` calls complete:

1. **Tag each result** with the seed paper that surfaced it.
2. **Deduplicate** — if a paper appears in multiple seeds' similar lists, merge it into one record while retaining a separate similarity score for each seed. When ordering a thread, use that thread's seed-specific score rather than a score from another seed.
3. **Filter out self-authored papers** — compare the focal author's stable identifier with paper-author identifiers whenever available, then use server-resolved canonical identities or returned aliases. Lowercase/trim/collapse-whitespace name matching is only a fallback and does not reliably reconcile initials, punctuation, ordering, or diacritics. If a name-only match is plausibly the focal author but remains ambiguous, conservatively exclude the paper.
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
- **Seed**: Title (paper ID), year, categories

Recommended reading (up to 5–8 papers per thread, ordered by that thread's seed-specific similarity score). If fewer than 5 survive retrieval, deduplication, and self-author filtering, show every available result and disclose the limited count:

1. **Title** (paper ID) — first 3 authors, year, category — one-sentence reason it matters here
2. ...

If a seed paper was skipped because it had no embedding, add a note under that thread: *"This seed had no embedding; no similar papers could be retrieved."*

### Cross-Thread Highlights

If any paper appeared as similar to **multiple** seeds, highlight it as a cross-thread find — these are often the most interesting recommendations because they sit at the intersection of the author's threads:

- **Title** (paper ID) — surfaced by Seed A *and* Seed C — why this matters

If no cross-thread papers were found, omit this section.

### Suggested Follow-ups

- `/valency:profile <author>` — for any author that appears across multiple recommendations
- `/valency:similar <paper_id>` — to dig deeper into any specific recommendation
- `/valency:fresh-collaborators <author>` — if the user is interested in *who* (not what) to engage with next
