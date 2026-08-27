---
name: profile
description: "Use when the user asks about a researcher's work, papers, research areas, collaborators, or academic profile. Triggers on requests such as 'who is X', 'what does X work on', 'show me X's papers', or 'tell me about X' in a research context."
---

# Researcher Profile

Build a corpus-grounded profile of one resolved researcher.

## Input

The user supplies a researcher name or ORCID and may supply a paper ID as identity context.

## Tool discovery and response discipline

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the matching exposed tools. If the required Valency Bond tools are unavailable, say so and stop.

After every call:

1. Read `warnings` and report any warning that changes identity, coverage, ranking, or interpretation.
2. If `_meta.limit_clamped` is a nonempty array, report each event's `tool`, `requested`, `effective`, and `max` values and use the effective limit for coverage claims.
3. Treat an empty array or zero count as a valid empty result. Follow the empty-result branch below rather than inventing entries.
4. Treat absent or null fields as unavailable. Do not reconstruct or synthesize metadata.
5. If a returned paper has `authors_truncated: true`, treat its visible byline as incomplete and report `total_authors` when present. Visible-list absence is not evidence that an author is absent.
6. Preserve each paper's `categories` list as returned; category labels are source-specific and may be null or empty.
7. Link a paper title with its non-null `url`. Fall back to showing its `id` only when `url` is unavailable.
8. Label `datestamp` as the source record/update date. For arXiv, bioRxiv, and medRxiv, label non-null `first_submitted` as a first-submission estimate. For every other or unknown source, label it as a record-derived month estimate. None of these fields is a publication date.

## Workflow

Execute these steps in order.

### 1. Resolve the researcher

Call `get_author_identity` with exactly one applicable object:

```json
{"author": "<user name>"}
```

```json
{"author": "<user name>", "paper_id": "<user-supplied versioned paper ID>"}
```

```json
{"orcid": "<user-supplied ORCID>"}
```

Prefer the paper-hinted name call when the user supplied a paper. Inspect `warnings`, `career_metrics`, `orcid`, `resolved_name`, and `candidates`.

- If `candidates` is nonempty, present only the candidate evidence the tool returned, such as display name, current institution, and sample recent titles. Ask the user for an ORCID or a paper that identifies the intended researcher, then re-call `get_author_identity` with that public context. Do not continue while candidates remain.
- If no usable identity is returned and the response indicates not found or unverifiable, report that identity-safe profile and paper retrieval cannot be completed. Stop.
- Use `career_metrics.display_name` as the canonical display name when non-null. Otherwise retain the user's display name; `resolved_name` is a corpus matching key, not preferred display text.
- Prefer the resolved ORCID for subsequent identity-aware calls. Without an ORCID, use the canonical author name plus a paper hint when available and retain the returned disambiguation qualification.

Identity resolution is complete only when one researcher has been selected and no unresolved candidate list remains.

### 2. Get the corpus profile

When the identity has an ORCID, call:

```json
{"author": "<canonical display name>", "orcid": "<resolved ORCID>"}
```

Otherwise call:

```json
{"author": "<canonical display name>"}
```

Use `get_author_profile.categories` directly; do not run a separate single-author category aggregation. Record `stats_source` with every summary, category, and timeline claim:

- `orcid_keyed` is an identity-linked corpus aggregate.
- `name_keyed` is a resolved-name-bucket aggregate and can miss or split name variants.

The profile's `summary.total_papers` is a corpus count. Career metrics such as `works_count`, `cited_by_count`, and `h_index` come from the identity profile, not the corpus summary; label their source separately and omit unavailable metrics.

Treat `summary.first_paper`, `summary.last_paper`, and `timeline` as observed paper-activity dates/buckets. Their basis can mix first-submission estimates with source record/update dates. Never call them publication dates or publication years.

### 3. Retrieve citation-ranked papers for that identity

When an ORCID is available, call `find_papers_by_researcher`:

```json
{"orcid": "<resolved ORCID>", "limit": 10, "sort_by": "citations"}
```

Otherwise call `find_papers_by_researcher`:

```json
{"author": "<canonical display name>", "limit": 10, "sort_by": "citations"}
```

Add the user-supplied versioned `paper_id` to the name call when available. Inspect `candidates`, `disambiguation_status`, `warnings`, `returned_count`, each paper's `match_type`, and citation fields. If candidates reappear, request an ORCID or identifying paper and repeat the call only after the ambiguity is resolved.

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
- for arXiv, bioRxiv, or medRxiv, `first_submitted` as “first-submission estimate”; for other or unknown sources, `first_submitted` as “record-derived month estimate”; otherwise `datestamp` as “source record/update date”
- identity `match_type` when it materially qualifies attribution

State `returned_count`, `disambiguation_status`, citation coverage, limit clamping, and any truncated-byline caveat. Do not print a publication year.

### Top Coauthor Name Buckets (up to 10 returned)

| Coauthor display name | Shared papers in returned name-bucket edge |
|---|---:|

Use `coauthor` for display and `shared_papers` for the count. State that name variants can fragment buckets and that these collaborators have not been identity-resolved.

### Completion

The profile is complete when identity selection is settled; profile provenance and warnings are reported; the capped citation-ranked result and its coverage are labeled; categories come from the profile; and the coauthor section is explicitly name-bucket/top-N data.
