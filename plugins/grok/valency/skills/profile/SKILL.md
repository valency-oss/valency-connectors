---
name: profile
description: "Use when the user asks about a researcher's work, papers, research areas, or academic profile. Triggers on requests such as 'who is X', 'what does X work on', 'show me X's papers', or 'tell me about X' in a research context."
---

# Researcher Profile

Build a corpus-grounded profile of one resolved researcher.

## Input

The user supplies a researcher name or ORCID and may supply a paper ID as identity context.

## Tool discovery and response discipline

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the matching exposed tools. If the required Valency Bond tools are unavailable, say so and stop.

After every call, surface any warning that changes identity, coverage, ranking, or interpretation, and preserve each paper's `categories` list as returned — category labels are source-specific vocabularies. Date fields carry the **source-aware date label**: `datestamp` is the source record/update date; non-null `first_submitted` is a first-submission estimate for arXiv, bioRxiv, and medRxiv records and a record-derived month estimate for other sources. None is a publication date.

## Workflow

Execute these steps in order.

### 1. Resolve the researcher

Call `get_author_identity` with `author` (adding `paper_id` when the user supplied a paper as identity context). When the user supplied an ORCID, pass it together with the name so the server cross-validates that the ORCID belongs to the named researcher; pass `orcid` alone only when no name was given. Inspect `warnings`, `career_metrics`, `orcid`, `resolved_name`, and `candidates`.

- If `candidates` is nonempty and a single ORCID-collision candidate has `confidence` >= 0.95, select it and re-call with its returned stable author identifier. Otherwise present the returned candidate evidence (display name, current institution, sample recent titles), ask the user to pick, and re-call with the chosen candidate's returned stable author identifier — or an ORCID or identifying paper when it is null. Do not continue while candidates remain unresolved.
- If `resolved_name` is null and `candidates` is empty, the researcher is not in the corpus; say so and stop. If a name resolves without a unique identity, continue with the name-keyed path below and label the whole profile with the returned disambiguation qualification.
- Use `career_metrics.display_name` as the canonical display name when non-null. Otherwise retain the user's display name; `resolved_name` is a corpus matching key, not preferred display text.
- For `find_papers_by_researcher` and any `get_author_identity` re-call, use the strongest resolved key: ORCID, then the stable author identifier returned in `career_metrics`, then the canonical name plus a paper hint when available. `get_author_profile` accepts only `author` and `orcid`.

Identity resolution is complete only when one researcher has been selected and no unresolved candidate list remains.

### 2. Get the corpus profile

Call `get_author_profile` with `orcid` when one was resolved and `author` set to the canonical display name. Without an ORCID, set `author` to the identity `resolved_name` so the profile keys the same corpus bucket.

Use `get_author_profile.categories` directly instead of a separate single-author category aggregation. Record `stats_source` with every summary, category, and timeline claim:

- `orcid_keyed` is an identity-linked corpus aggregate.
- `name_keyed` is a resolved-name-bucket aggregate and can miss or split name variants.

The profile's `summary.total_papers` is a corpus count. Career metrics such as `works_count`, `cited_by_count`, and `h_index` come from the identity profile, not the corpus summary; label their source separately and omit unavailable metrics.

Treat `summary.first_paper`, `summary.last_paper`, and `timeline` as observed paper-activity dates/buckets; their basis can mix first-submission estimates with source record/update dates.

### 3. Retrieve citation-ranked papers for that identity

Call `find_papers_by_researcher`:

```json
{"orcid": "<resolved ORCID>", "limit": 10, "sort_by": "citations"}
```

Without an ORCID, keep `limit` and `sort_by` and identify the researcher by the strongest available key instead: the stable author identifier returned in `career_metrics` when present, otherwise `author` (the canonical display name) plus the user-supplied versioned `paper_id` when available. Inspect `candidates`, `disambiguation_status`, `warnings`, `returned_count`, each paper's `match_type`, and citation fields. If `candidates` reappear (an ORCID collision), resolve them with the chosen candidate's stable author identifier as in step 1.

This is an identity-attributed, citation-ranked result capped at 10, not a full publication list. Citation enrichment is nullable upstream data. Report citation coverage as “citation counts available for X of Y returned papers,” preserve null counts as unavailable, and qualify the ranking with any coverage warning. If no papers are returned, say that no identity-attributed corpus papers were returned.

### 4. Get top coauthor name buckets

If the profile returned a non-null `resolved_name`, call `find_coauthors` with:

```json
{"author": "<profile resolved_name>", "limit": 10}
```

Otherwise skip this step and state that no corpus name key was available.

`find_coauthors` ranks coauthor name buckets for one focal normalized-name bucket. It is not an identity-resolved or necessarily complete collaboration graph, and the returned list is top-N. Display `coauthor`; use `coauthor_norm` only for local matching or a later exact name-bucket chain. Use `shared_papers` as the count for that returned edge. If no coauthors are returned, state that none were found for the focal name bucket.

## Output

### Summary

- **Name:** canonical display name
- **Identity:** ORCID when present; otherwise the returned disambiguation status
- **Corpus papers:** `summary.total_papers`, labeled with `stats_source`
- **Observed paper activity:** `summary.first_paper` to `summary.last_paper`, with the mixed first-submission/record-date caveat
- **Corpus coauthor names:** `summary.unique_coauthors` when present, qualified by `stats_source`
- **Identity-provider career metrics:** only non-null returned metrics, clearly separated from corpus statistics

Include material warnings beside the claims they qualify.

### Research Categories

Show up to five non-null entries from `get_author_profile.categories` as returned:

| Category label | Corpus paper count |
|---|---:|

If categories are empty or null, say category metadata is unavailable. Describe these as source-specific category labels, not a universal ontology.

### Citation-Ranked Corpus Papers (up to 10 returned)

For each returned paper show:

- linked title using `url`, or title plus `id` when no URL is available
- `citation_count`, or “unavailable”
- full `categories` list, or “unavailable”
- the source-aware date label
- identity `match_type` when it materially qualifies attribution

State `returned_count`, `disambiguation_status`, and citation coverage.

### Top Coauthor Name Buckets (up to 10 returned)

| Coauthor display name | Shared papers in returned name-bucket edge |
|---|---:|

Use `coauthor` for display and `shared_papers` for the count. State that name variants can fragment buckets and that these collaborators have not been identity-resolved.

### Completion

The profile is complete when one researcher is selected with no unresolved candidates and every section above is populated from its stated source or explicitly marked unavailable.
