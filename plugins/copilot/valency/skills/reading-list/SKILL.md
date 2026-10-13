---
name: reading-list
description: "Use when the user asks what a researcher should be reading, wants a curated bibliography for a researcher's interests, asks 'what should X read', 'find me adjacent work to X's research', or wants to know what literature surrounds an author's body of work. Triggers on reading-list, bibliography, or 'what should I read next' style requests anchored on a specific researcher."
---

# Researcher Reading List

Build a reading list for a researcher, organized into threads, each seeded by one of their own representative papers.

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop. If a tool call fails with an error, retry it once before treating it as a real failure.

## Input

An author name, or an ORCID / author_id / known paper if the name alone is ambiguous.

## Tool Chain

### Step 1: Resolve the author

Call `get_author_profile` with `author` (plus any hint given). Branch on `status`:
- `not_found` / `no_match` / `name_only` → say so, ask for an ORCID or a known paper. Stop.
- `did_you_mean` → show the suggestions, offer to retry. Stop.
- `ambiguous` → if the user gave a hint (a paper, field, institution or collaborator), pick the candidate it matches (`recent_title`, `top_categories`) and say why. Otherwise pick a candidate only if its `corpus_papers` is several times the next *genuinely different* candidate's (compare `works_count` for both instead when either `corpus_papers` is null — never one against the other) (a small same-field entry with the same name is likely a fragment of the same person), and say it's a judgment call. Otherwise list the candidates and ask. Once picked, re-call with that `author_id`.
- `resolved` → keep `person.author_id`, `person.display_name`, `corpus.corpus_papers`, `corpus.top_categories`. If `warnings[]` says the record's affiliations span several countries and may combine people, mention it in one line — and the seed rule in Step 4 keeps a namesake's paper from becoming a thread.

If a response carries `degraded: true` (`next_action: "retry_unchanged"`), part of it was skipped, not empty: retry that call once unchanged, and if it is still degraded, say that part is unavailable rather than reporting zero.

Use `person.author_id` for every later call.

### Step 2: Career anchors

Call `find_papers_by_researcher` with `author_id`, `sort_by: "citations"`, `limit: 15`. The sort covers their whole corpus. Skip papers with `total_authors` > 50 (a collaboration roster says little about the person's own interests); the top 5 of what's left are the anchors.

### Step 3: Current direction

Call `find_papers_by_researcher` with `author_id`, `sort_by: "recency"`, `limit: 40`. Recency follows the record-update date, so many re-stamped old papers come first: keep only papers from the last two years (by the year rules in Displaying papers), up to 5.

### Step 4: Pick 3–5 seeds

From Steps 2–3, pick 3–5 papers on clearly different topics. Every seed must be on a topic that recurs across their other fetched papers — a one-off collaboration (a paper from another lab's line of work) makes a thread that isn't about them. Among papers that pass, prefer ones where the researcher is first, second or last author. Take: the most-cited such anchor, the most recent such paper with a real abstract, then others that add a new topic (judge by title and abstract, not category codes — PubMed papers often have none).

### Step 5: Similar papers per seed

For each seed, call `find_similar_papers` with `paper_id`, `limit: 12`, `max_authors: 100`. Abstracts stay on: each recommendation's one-line reason must come from its abstract, not be guessed from the title. If a seed returns nothing, skip it and note it.

### Step 6: Clean up

1. Merge duplicates (see Displaying papers). If a paper surfaces under several seeds, keep it once with all its seeds.
2. Drop the researcher's own papers: any result whose `id`/`base_id` appeared in Steps 2–3, and any whose authors include the researcher. Match names on surname plus given name; when either side gives only initials, surname plus first initial; ignore case, accents, apostrophes and every hyphen variant. If a result's byline is still truncated (`authors_truncated: true`), the researcher may be in the hidden part, so drop it. Display names vary across records ("D. Huppenkothen", "Huppenkothen, Daniela").
3. Each seed's survivors form one thread.

## Displaying papers

- Link each title to its `url`; keep the paper ID in parentheses.
- **Year:** the year in `journal_ref` when present, else `first_submitted`. If `journal_ref` or the DOI shows an earlier publication year than the arXiv date (an old paper posted late), use the earlier year. For PubMed rows `first_submitted` is often a record-update date — with no `journal_ref` (similar-paper results don't carry it), leave the year off rather than show a wrong one.
- **Category:** show arXiv codes only; PubMed `categories` are free keywords — omit them.
- **Authors:** all if three or fewer, else first three + "et al." Show PubMed's "Last, First" as "First Last".
- **Duplicates:** same DOI, or same title (ignoring case, punctuation and hyphens) with the same first author. Keep the arXiv record.

## Output Format

### Researcher Summary
Name, papers in the corpus (`corpus.corpus_papers`), main fields (top 3 of `corpus.top_categories`). One line on how the seeds were chosen.

### Reading List by Thread
#### Thread N: <short description of the topic>
**Seed:** title (linked, ID), year

5–8 recommendations, in similarity order:
1. **Title** (linked, ID) — authors, year, citations — one sentence on why it's relevant to this thread

If a thread has fewer than 3 recommendations left after cleanup, merge it into the nearest thread or drop it, and say so.

### Cross-Thread Highlights
Papers that surfaced under several seeds. Omit if none.

### Suggested Follow-ups
- Ask for papers similar to `<paper_id>` — go deeper on any recommendation
- Ask for fresh collaborators for `<author>` — the *who* to meet, alongside the *what* to read
