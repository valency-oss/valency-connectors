---
name: landscape
description: "Use when the user asks for an overview of a research field, wants to understand a domain's key players, or asks 'what's happening in X' or 'give me a landscape of X'. Triggers on requests for field summaries, top authors in an area, or subdomain breakdowns."
---

# Field Landscape

An overview of a research field: size, growth, most-cited papers, most prolific authors, neighbouring fields.

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop. If a tool call fails with an error, retry it once before treating it as a real failure.

## Input

- **arXiv category code** (`cs.LG`, `q-bio.NC`, `astro-ph.HE`) → category path.
- **Anything else** (free text, a PubMed topic, a bioRxiv label) → topic path. Only arXiv codes get the category path; other sources' labels go through free text.

A category call that returns an empty series with an `UNKNOWN_CATEGORY` warning means the code isn't recognised: show the suggested codes and ask which one was meant, never report a field with no activity. A `CATEGORY_TOO_BROAD` error lists the subcategories to use instead: show them and ask.

## Tool Chain — category path

1. **Most-cited papers:** `search_by_category` with `category`, `sort_by: "citations"`, `limit: 100`, `include_abstract: false`, `max_authors: 3`. The sort covers the whole category. Results include papers cross-listed into it; a paper's first-listed category is its primary one.
2. **Volume over time:** `get_publication_trends` with `category`, `granularity: "year"`, `format: "compact"`.
3. **Prolific authors:** `identify_prolific_authors` with `category`, `limit: 10`. Rows are keyed by name; use each row's identity fields:
   - `unambiguous`, `mostly_single`, or `ambiguous` with `top_candidate_coverage` ≥ 0.85 → one person.
   - other `ambiguous` → "may combine a few people with this name".
   - `likely_aggregation` / `severe_aggregation` → several people share this name; don't present the count as one person's.
   - `unresolved` → not enough signal to tell.
   Drop rows that are clearly not a person (a country, institution or collaboration name).
   Keep `top_candidate_id` for follow-ups. If the call times out, retry once, then skip the section and say author ranking wasn't available.
4. **Size:** `analyze_corpus_metrics` with `category`.
5. **Neighbouring fields (no call):** count the other categories listed on Step 1's papers.

## Tool Chain — topic path

1. **Most-cited papers:** `semantic_search_papers` with `query`, `sort_by: "citations"`, `limit: 100`, `include_abstract: false`, `max_authors: 3`. This takes the 100 papers closest in meaning and orders those by citations, so it's "the most-cited of the closest matches", not the field's all-time list. Phrase the query the way the field describes itself.
2. **Volume over time:** `get_keyword_trends` with the short topic term (e.g. "base editing" — not the descriptive sentence from step 1), `granularity: "year"`, `format: "compact"`. It matches the words, not the exact phrase, so years before the topic existed can hold unrelated hits.
3. No author ranking, corpus metrics or neighbouring fields on this path — they need a category. Say so in one line.

## Reading the numbers

- **Missing years:** years with no papers are left out of a trend series, not returned as 0. Fill them with 0 between the first and last year shown before building the table or comparing years.
- **Trends** count papers by record-update date for most sources: revised old papers land in later years, and the earliest years look thinner than they were. Base the trajectory on complete years. Mark the current year as partial; if it already exceeds last year's full count, say it may be inflated by record updates or may be real growth — a monthly trend check can tell them apart — rather than asserting either. An earlier year at least double its neighbours' average, with no known field event, is likely an ingestion artifact — say so in one line rather than calling it growth.
- **Topic-path totals:** sum the keyword-trend counts from the year the topic took off (when counts start rising steadily), labelled "papers mentioning the term since <year>"; mention the earlier stray matches in one line.
- **Duplicates:** the same work can appear as an arXiv and a PubMed record. Treat rows as one paper when the DOI matches, or the title matches (ignoring case, punctuation and hyphens) **and** the first author matches. Keep the higher citation count.

## Displaying papers

Link each title to its `url`; keep the ID in parentheses. Year: the year in `journal_ref` when present, else `first_submitted` (for PubMed rows, `first_submitted` is often a record-update date; with no `journal_ref`, leave the year off). Category: arXiv codes only — PubMed `categories` are free keywords. Authors: all if three or fewer, else first three + "et al."; a collaboration name ("The LIGO Scientific Collaboration") counts as an author.

## Output Format

### Field Summary
Total papers (category: `analyze_corpus_metrics`; topic: trend sum), years covered, growth in one or two sentences.

### Publication Trends
Year-by-year table, current year marked partial, artifacts flagged. For long series, group the sparse early years into one row.

### Most-Cited Papers
Top 10 (after merging duplicates): title (linked, ID), authors, year, citations. Category path: if cross-listed papers dominate the top 10, list the top papers whose primary category *is* the input first, then a short "also highly cited, cross-listed from other fields" line. Topic path: label the list "most-cited among the 100 closest matches".

### Top Authors (category path only)
Up to 10: name, paper count, with the identity note from Step 3 where one applies.

### Neighbouring Fields (category path only)
Most frequent co-listed categories with counts, labelled "co-listed on the field's 100 most-cited papers".

### Observations
2–3 points drawn only from the data above.

### Suggested Follow-ups
- Ask for a profile of `<author>` — for a listed author (pass that row's `top_candidate_id` as the author_id)
- Ask for trends for `<category or topic>` — finer trend analysis
- Ask for papers similar to `<paper_id>` — around any listed paper
