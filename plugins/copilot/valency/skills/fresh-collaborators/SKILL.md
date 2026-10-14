---
name: fresh-collaborators
description: "Use when the user asks who a researcher should be talking to that they aren't already, wants to find new potential collaborators outside an existing network, asks 'who else is doing this work', 'who should X meet', 'who are the new faces in this field', or wants to expand a researcher's collaboration network beyond their current circle. Triggers on requests to find recent, relevant researchers who are NOT in an author's existing coauthor list."
---

# Fresh Collaborators

Find people doing recent work close to the researcher's current themes who are **not** already their coauthors.

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop. If a tool call fails with an error, retry it once before treating it as a real failure.

## Input

An author name (or ORCID / author_id / known paper if the name is ambiguous). Optional: a window in months (default 18).

**Cutoff** = today minus the window, as `YYYY-MM-DD`.

## Tool Chain

### Step 1: Resolve the researcher

Call `get_author_profile` with `author` (plus any hint). Branch on `status`:
- `not_found` / `no_match` / `name_only` → say so, ask for an ORCID or a known paper. Stop.
- `did_you_mean` → show the suggestions, offer to retry. Stop.
- `ambiguous` → if the user gave a hint (a paper, field, institution or collaborator), pick the candidate it matches (`recent_title`, `top_categories`) and say why. Otherwise pick a candidate only if its `corpus_papers` is several times the next *genuinely different* candidate's (compare `works_count` for both instead when either `corpus_papers` is null — never one against the other) (a small same-field entry with the same name is likely a fragment of the same person), and say it's a judgment call. Otherwise list the candidates and ask. Once picked, re-call with that `author_id`.
- `resolved` → keep `person.author_id`, `person.display_name`, `corpus.corpus_papers`, `corpus.top_categories`.

If a response carries `degraded: true` (`next_action: "retry_unchanged"`), part of it was skipped, not empty: retry that call once unchanged, and if it is still degraded, say that part is unavailable rather than reporting zero.

### Step 2: Their recent work

Call `find_papers_by_researcher` with `author_id`, `sort_by: "recency"`, `limit: 40`. Recency follows `dates.first_available`, but an old paper posted late can still come first: use papers from the last ~2 years (by the year rules below) for themes, and **all 40** for the exclusion set. If fewer than 2 papers fall in the last ~2 years, say there is too little recent work to build themes from and stop.

### Step 3: Exclusion set

Call `find_coauthors` with `author_id`, `limit: 100`. Exclude everyone listed there, **plus every author on Step 2's papers with at most 50 authors** (the coauthor list cuts off one-off coauthors, who still aren't "fresh"), plus the researcher.

Step 2's bylines stop at 20 names. For each Step 2 paper with `authors_truncated: true` and `total_authors` ≤ 50, call `get_paper_by_id` with `include_abstract: false`, `max_authors: 50` to get the full list. Papers with more than 50 authors are collaboration rosters; sharing one doesn't make someone a collaborator — say so in the summary.

**Name matching** (papers carry no author IDs): compare surname plus given name; if either side gives only initials, compare surname plus first initial. Show PubMed's "Last, First" as "First Last" before comparing; ignore case, accents, apostrophes and every hyphen variant (records mix ASCII and Unicode hyphens). Don't reduce full names to initials — on common surnames ("J. Wang") that excludes strangers.

### Step 4: Themes

From Step 2's papers, write 2–4 themes, each a 5–12 word phrase usable as a search query ("Bayesian experimental design for cosmological survey forecasting"), each backed by at least two of their papers. If the recent papers are too scattered for that, use the clearest 2 and mention the rest.

### Step 5: Search each theme

For each theme, call `semantic_search_papers` with `query`, `limit: 100`, `include_abstract: false`, `max_authors: 100`. Don't pass `start_date`; Step 6's cutoff filter does the dating. In Step 6, after merging duplicates (an arXiv/PubMed pair keeps its earliest date), drop papers dated before the cutoff: compare `dates.first_available` as a full date when its `precision` is `day`, otherwise the year by the rules below, keeping a paper from the cutoff's own year; and drop any whose `journal_ref` or DOI shows a year before the cutoff's. Drop papers with `total_authors` > 50 too.

### Step 6: Filter and rank

1. Merge duplicate papers (see Displaying papers) **before** filtering, so an arXiv/PubMed pair is judged together.
2. Drop any paper with an excluded author, and any that fails the date checks in Displaying papers (including the PubMed lookup) — before ranking, so old papers don't count toward anyone.
3. The candidate for each surviving paper is its first author; if the byline is alphabetical (common in maths), use the last author instead.
4. Merge candidates who are the same person (name rules above).
5. Rank: people surfaced by more papers or more themes first; then interleave themes so no single theme fills the list.
6. Note each person's role on the surfacing papers (first or last author, how many papers). The results don't show career stage, so don't label anyone early-career or established, and don't add facts about people that the tool results don't show.

## Displaying papers

- Link each title to its `url`; keep the paper ID in parentheses.
- **Year:** the year in `journal_ref` when present, else the year of `dates.first_available.value` (any `precision`: day, month or year; where a row also carries `first_submitted`, it is the same value); if `journal_ref` or the DOI shows an earlier year than the arXiv date (an old paper posted late), use the earlier one. PubMed rows from `semantic_search_papers` carry no `journal_ref`: for every PubMed record left after Step 6's author filter (item 2), including the PubMed half of a merged pair, call `get_paper_by_id` (`include_abstract: false`) and use its `journal_ref` year when present; drop it if its year is before the cutoff, or if it has neither `journal_ref` nor `dates.first_available` (it can't be dated).
- **Duplicates:** same DOI, or same title (ignoring case, punctuation and hyphens) with the same first author.

## Output Format

### Summary
Researcher (name, papers in corpus, main fields), the window and cutoff date, the themes searched. One line: "Excluded: their top 100 coauthors and everyone on the 40 papers fetched in Step 2 (except >50-author collaboration rosters)."

### Fresh Faces
Up to 10:

#### N. Name
- **Surfaced by:** theme(s)
- **Role:** e.g. first author of 2 surfacing papers
- **Paper(s):** title (linked, ID), year
- **Why relevant:** one sentence tying their paper to the researcher's work

### Theme Coverage
Per theme: papers found, papers removed because an existing coauthor is on them, papers removed for other reasons (date, roster, duplicate), and papers left. Only when coauthor removals account for most of the losses, say the theme is mostly inside the existing network.

### Suggested Follow-ups
- Ask for a profile of `<name>` — a closer look at any candidate
- Ask for papers similar to `<paper_id>` — more work like a surfacing paper
