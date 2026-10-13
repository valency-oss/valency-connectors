---
name: trends
description: "Use when the user asks how a research topic has changed over time, wants publication volume trends, asks 'is X growing', 'when did X take off', or wants to compare the trajectories of two fields. Triggers on trend, growth, or timeline questions about research areas."
---

# Publication Trends

Show how a topic or category has grown over time.

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop. If a tool call fails with an error, retry it once before treating it as a real failure.

## Input

One or more arXiv category codes and/or keywords. Several inputs ("A vs B", comma-separated) → a comparison.

A category call that returns an empty series with an `UNKNOWN_CATEGORY` warning means the code isn't recognised: show the suggested codes and ask which one was meant, never report a field with no activity. A `CATEGORY_TOO_BROAD` error lists the subcategories to use instead: show them and ask.

## Tool Chain

### Step 1: Trend data

- **Category:** `get_publication_trends` with `category`, `granularity: "year"`, `format: "compact"`.
- **Keyword:** `get_keyword_trends` with `query`, same `granularity`/`format`. It matches the words, not the exact phrase. If the term has a common variant or spelled-out form ("CAR-T" / "chimeric antigen receptor", "LLM" / "large language model"), run that too and report both — they can differ by 2× or more.
- **Several inputs:** one call per input, combined into one table.

### Step 2: Current-year check

The current year is partial: don't compare it with last year's full count. To say whether it's on track, call the same trend tool with `granularity: "month"` and compare its completed months with the same months last year; if they're ahead, say the current year is on track to exceed last year, as a projection rather than a fact — unless the monthly response's `excluded.coarser_than_bucket` is a sizeable share of its total (year-only dates aren't in monthly counts), in which case don't project. Monthly results may list months out of order; sort them before comparing.

### Step 3: Representative recent papers

Cutoff = today minus 2 years. Recent work that's already being cited:
- **Keyword:** `semantic_search_papers` with `query`, `start_date` (cutoff), `limit: 30`, `include_abstract: false`, `max_authors: 3`.
- **Category:** `filter_by_date_range` with `category`, `start_date` (cutoff), `end_date` (today), `sort_by: "citations"`, `limit: 50`, `include_abstract: false`, `max_authors: 1`.

Both filter on the date a record first went public, so an old paper posted late can pass: first merge duplicates (an arXiv/PubMed pair keeps the earliest `journal_ref`/DOI year of either record), then drop papers whose `journal_ref` or DOI year is before the cutoff's, plus any whose record otherwise shows older work (a past conference or edition named in the title or comments). If fewer than 3 genuinely recent papers remain for an input, show those and say the rest couldn't be dated reliably — don't pad the list. Take the 3–5 most-cited of what's left, then verify each before showing it: call `get_paper_by_id` (`include_abstract: false`) on every record of a merged pair, not just the one you display — search results omit `comments` — and drop any whose `journal_ref`, DOI or `comments` show older work (e.g. "NeurIPS 2014"); move down the list to replace it. For a comparison, do this per input.

## Reading the numbers

- **Missing years:** years with no papers are left out of a trend series, not returned as 0. Fill them with 0 between the first and last year shown before building the table, comparing inputs or checking for spikes.
- **What's counted:** papers are counted by the date they first went public. Papers dated more coarsely than the bucket (a year-only date in a monthly series) are totalled in `excluded.coarser_than_bucket` rather than counted — mention it when it's a sizeable share. Say "in this corpus" for any "first appeared" claim, and date it from when counts become sustained, not from the first non-zero year (loose word matching puts stray hits in early years).
- **Current year:** partial — read it per Step 2.
- **Spikes:** a single year at least double its neighbours' average, with no known field event, is likely an ingestion artifact — flag it in one line.

## Displaying papers

Link each title to its `url`; keep the ID in parentheses. Year: the year in `journal_ref` when present, else the year of `dates.first_available` (its `value`; for a range, show `start`–`end` and use the `start` year wherever a single year is needed), else `first_submitted` for a preprint; if the DOI shows an earlier year (an old paper posted late), use that and treat it as old. Never show a year later than the current one (a journal volume can be dated ahead) — use the `dates.first_available` year instead, else leave the year off. Authors: all if three or fewer, else first three + "et al." Duplicates: same DOI, or same title (ignoring case, punctuation and hyphens) with the same first author — keep the arXiv record.

## Output Format

### Trend Data
Year-by-year table (one column per input when comparing), current year marked partial. For long series, group the sparse early years into one row.

### Summary
3–5 sentences: when it took off in this corpus, inflection points, trajectory over complete years (accelerating / plateauing / declining), and for comparisons, which grows faster and when they diverged. Include the caveats above only where they change the reading.

### Representative Recent Papers
3–5 per input: title (linked, ID), authors, year.

### Suggested Follow-ups
Only lines you can fill with a real value:
- Ask for a landscape of `<category>` — when the input was an arXiv category
- Ask for trends for `<related term>` — a named related term worth comparing
- Ask for papers similar to `<paper_id>` — around one of the listed papers
