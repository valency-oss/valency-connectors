---
name: similar
description: "Use when the user wants to find papers similar to a specific paper, asks 'what's related to this paper', 'find me more like this', or wants to explore the neighborhood around a known paper. Triggers on paper IDs, arXiv IDs, DOIs, or paper titles followed by a similarity request."
---

# Similar Papers

Find papers semantically similar to a given paper.

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop. If a tool call fails with an error, retry it once before treating it as a real failure.

## Input

- An arXiv ID (`2301.07041`, `2301.07041v3`, `astro-ph/9805201`), a bare PubMed ID (`26017442`), a `PMC` ID, or an OSF short ID — resolve directly.
- A DOI (`10.xxxx/...`) — usually not an ID; see Step 1.
- A title or title fragment — resolve via search.

## Tool Chain

### Step 1: Resolve the paper

**ID:** call `get_paper_by_id` with `paper_id` as given. If `found: false`, say the ID wasn't recognized and ask for the title. Stop.

**DOI:** `get_paper_by_id` doesn't accept most DOIs. Exceptions: bioRxiv/medRxiv DOIs (`10.1101/…`) are corpus IDs, so pass them as given; OSF DOIs (`10.31223/` EarthArXiv, `10.31234/` PsyArXiv, `10.31235/` SocArXiv) — strip the prefix and any `osf.io/`; the rest is the corpus ID. Otherwise, if you know the paper's title and an author with confidence, call `search_by_title` with both `query` and `author` (a generic title like "Deep learning" is unfindable without the author filter) and accept the hit whose `doi` equals the DOI given. If you don't know the paper, ask the user for its title or arXiv/PubMed ID.

**Title:** call `search_by_title` with `query`, `limit: 5`. A result with `_source: "semantic"` is a fallback guess, not a title match; a real keyword hit has no `_source` field. Ignore `relevance_score`, `match_quality` and "No strong matches found" — they appear even on exact hits.
- Take the paper without asking when the first keyword hit's title matches the query, or starts with it, and no other keyword hit is an equally good match.
- Otherwise list the candidates (title, first author, year) and ask which one. If nothing matches at all, say so and ask for more of the title or an ID.

### Step 2: Find similar papers

Call `find_similar_papers` with `paper_id` (resolved), `limit: 12`, `max_authors: 4`. If it returns nothing or says the paper has no embedding, say so and offer `semantic_search_papers` on its title instead. If it still errors after the retry, say similarity search is unavailable right now rather than blaming the paper. Stop.

Merge duplicates (see Displaying papers), drop the source paper and any other version of it (its arXiv/PubMed twin — mention the twin under Source Paper), and keep the top 10.

## Displaying papers

- Link each title to its `url`; keep the paper ID in parentheses.
- **Year:** the year in `journal_ref` when present, else the year of `dates.first_available` (its `value`; for a range, show `start`–`end` and use the `start` year wherever a single year is needed), else `first_submitted` for a preprint; if the DOI shows an earlier year (an old paper posted late), use that. With none of these, leave the year off.
- **Category:** show arXiv codes (`cs.CL`) only. PubMed `categories` are free keywords — omit them.
- **Authors:** all of them if three or fewer, else the first three + "et al." Show PubMed's "Last, First" as "First Last".
- **Duplicates:** the same work can appear as an arXiv and a PubMed record. Treat rows as the same paper when the DOI matches, or the title matches ignoring case, punctuation and hyphens and the first author matches. Keep the arXiv record.

## Output Format

### Source Paper
Title (linked), authors, year, first 2–3 sentences of the abstract.

### Similar Papers
Numbered, in similarity order. Per paper: title (linked, ID), authors, year, category, citations (`citation_count`, if not null), similarity (`similarity_score`, two decimals), and one sentence on what it does, from its abstract.

### Suggested Follow-ups
- Ask for papers similar to `<paper_id>` — continue from any listed paper
- Ask for a profile of `<author>` — only if one author appears on several of the listed papers (count them after merging duplicates); name them
