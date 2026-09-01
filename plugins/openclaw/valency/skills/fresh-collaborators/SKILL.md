---
name: fresh-collaborators
description: "Use when the user asks who a researcher should meet, who else is doing related recent work, or which relevant researchers do not appear among a focal author's strongest returned coauthor name buckets."
---

# Fresh Collaborators

Find first authors of thematically relevant, recently first-submitted work whose complete returned bylines contain neither the focal author nor anyone in the focal author's returned top-100 coauthor name-bucket list. This is weak-tie discovery, not proof that two people have never collaborated.

## Input

Require a focal author name. Accept an optional recency window in months; default to 18 months. Compute `cutoff = today - window_months` as `YYYY-MM-DD`.

## Tool and metadata discipline

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop.

For every call, inspect `warnings`, empty results, and `_meta.limit_clamped`; report material qualifications rather than silently continuing. For every paper, inspect `authors_truncated`. Preserve non-null `url`, source-specific `categories` lists, and returned display names. Missing metadata stays unknown.

`datestamp` is always a source record/update date. For arXiv, bioRxiv, and medRxiv, `first_submitted` can support a first-submission estimate; for every other or unknown source it is only a record-derived month estimate. None of these fields is a publication date.

Define one local `comparison_key(name)` and apply it to every name being compared, including returned `coauthor_norm` values: Unicode case-fold, transliterate common Latin ligatures, NFKD-fold diacritics, delete apostrophes, trim, and collapse whitespace. Keep original/canonical names for display; comparison keys are never display names or identities.

## Workflow

### 1. Resolve the focal human

Call:

```json
{"author":"<user-supplied name>"}
```

with `get_author_identity`. If the user supplied a paper context, also pass its versioned corpus ID as `paper_id`.

A non-null `resolved_name` alone does not establish a unique person. Inspect `warnings`, `career_metrics`, and `candidates`:

- If `candidates` is non-empty, show their display name, institution, and recent-title evidence. Ask the user for an ORCID or a paper that identifies the intended researcher, then re-call `get_author_identity` with that public context. Do not continue while candidates remain.
- If the response remains unverifiable, explain that an identity-safe collaborator search cannot be completed and stop.
- Prefer the resolved ORCID for researcher calls. Without one, use the canonical author name plus a paper hint when available and retain the returned disambiguation qualification. Use `career_metrics.display_name` when non-null as the focal display name.

Then call `get_author_profile` for corpus context:

```json
{"author":"<canonical focal display name>","orcid":"<resolved ORCID>"}
```

Omit `orcid` only when it is null. Record `resolved_name`, `stats_source`, profile warnings, corpus `summary.total_papers`, and the returned category/count list. Categories are source-specific corpus labels, not a uniform field ontology.

This step is complete only when one focal identity and one corpus name bucket are explicit.

### 2. Build the bounded coauthor exclusion set

Call `find_coauthors`:

```json
{"author":"<profile resolved_name>","limit":100}
```

Display each returned `coauthor`; use `coauthor_norm` only to construct comparison keys. Let the exclusion set contain `comparison_key(coauthor_norm)` for every row plus `comparison_key(profile.resolved_name)` and the keys of other known focal display forms from Step 1.

This endpoint returns at most the strongest 100 coauthor name buckets for one focal normalized-name bucket, with no pagination. It can split name variants and omit weaker prior coauthors. Record the returned count and any limit clamp; never call it a complete identity-resolved network.

### 3. Retrieve identity-specific recent corpus activity

When an ORCID is available, call `find_papers_by_researcher`:

```json
{"orcid":"<resolved ORCID>","limit":10,"sort_by":"recency"}
```

Otherwise call:

```json
{"author":"<canonical focal display name>","limit":10,"sort_by":"recency"}
```

Add the user-supplied versioned `paper_id` to the name call when available. Inspect `candidates`, `disambiguation_status`, each paper's `match_type`, warnings, returned count, and cap. If candidates reappear, request an ORCID or identifying paper before continuing. Stop on `unverifiable`; qualify name-only, potentially incomplete, low-confidence, and capped results. Here recency is record-recency ordering, not publication chronology.

### 4. Derive current themes

From returned titles and substantive abstracts, derive 2–4 natural-language theme queries of 5–12 words. Each theme must be supported by at least two focal papers. Preserve their source-specific category lists as context rather than merging them into a common taxonomy.

If fewer than two usable focal papers remain, report that current themes cannot be grounded and stop. If only two defensible themes exist, use two.

### 5. Search each theme, then enforce first-submission recency

For each theme call `semantic_search_papers`:

```json
{"query":"<theme>","start_date":"<cutoff YYYY-MM-DD>","limit":25,"sort_by":"relevance","include_abstract":true,"max_authors":500}
```

`start_date` is only a server-side `datestamp` prefilter. It does not prove that a paper was first submitted in the window. From each response:

1. Inspect `warnings`, `hints`, `confidence`, `_meta.limit_clamped`, and empty results.
2. Keep strict first-submission candidates only from arXiv, bioRxiv, or medRxiv with a usable `first_submitted` satisfying `cutoff <= first_submitted <= today`. Exclude other/unknown sources and missing or out-of-window values from this workflow's first-submission freshness claim.
3. Reject a paper when `authors` is empty.
4. If `authors_truncated` remains true after requesting 500 authors, reject it as unverifiable for byline exclusion.
5. For a complete returned byline, compute a key for every author and reject the paper if any key intersects the Step 2 exclusion set.

The remaining paper evidence supports only this statement: no displayed byline author matches the focal/top-100 returned name buckets under the uniform comparison fold. It does not establish no prior collaboration.

### 6. Shortlist, identity-resolve, and rank first authors

The first element of a non-empty returned `authors` array is the byline first author. Create provisional author-paper pairs without merging people by name. Use `final_score`, not `semantic_score`, as the thematic search rank.

Track the focal author's `get_author_identity` calls, including a candidate-selection re-call. The tool allows 10 invocations per task, so the shortlist may contain at most `10 - focal_identity_calls` pairs: at most nine after a one-call focal resolution or eight after a focal re-call.

Build that bounded shortlist deterministically: take the highest-`final_score` remaining pair from each theme in theme order, then fill remaining slots by `final_score` across all themes. Do not merge provisional pairs by name. The eventual candidate ranking is explicitly limited to this preselected evidence.

Process shortlisted pairs in order while identity-call budget remains. Resolve each first author with its actual, preferably versioned, surfacing paper ID:

```json
{"author":"<paper authors[0]>","paper_id":"<surfacing paper id>"}
```

Inspect warnings and candidates. If another identity call with an ORCID or stronger paper hint is needed, make it only when budget remains; otherwise keep that pair unresolved. Treat an author as stably resolved only when the response uniquely establishes an ORCID. Keep other paper-scoped resolutions separate and never merge them by display string.

Deduplicate resolved entries by ORCID. Merge themes, papers, and each paper's `final_score` only after this stable-identity match. Rank the processed shortlist by:

1. number of distinct themes represented;
2. highest `final_score` among retained papers;
3. remaining `final_score` values in descending order.

Do not infer or report career stage from this evidence.

## Output

### Focal author and search bounds

Report:

- canonical focal display name and stable identifier type;
- corpus paper count, `stats_source`, and source-specific top category/count entries;
- researcher disambiguation status and material warnings;
- returned coauthor bucket count and the exact top-100/name-bucket limitation;
- recency window as “first-submission estimate on or after `<cutoff>`,” plus the record-date prefilter;
- the grounded themes.

### Candidates

Show the resolved or explicitly unresolved candidates produced within the remaining identity-call budget. For each, include:

- canonical display name when resolved; otherwise the observed first-author name plus **identity unresolved**;
- identity basis: ORCID, paper-scoped resolution, or unresolved paper-scoped evidence;
- themes and surfacing papers with each paper's `final_score`;
- title, source, complete category list, and **first-submission estimate** from the supported preprint source when present, plus non-null `url`;
- **Top-100 exclusion evidence**: complete returned byline checked at `max_authors:500`; no author key matched the returned focal/top-coauthor bucket keys;
- one abstract-grounded sentence connecting the paper to the focal themes.

If fewer candidates survive date, byline, exclusion, shortlist, and identity handling than the available budget, return fewer and state why.

### Coverage and qualifications

For each theme, report counts for: returned by the record-date-prefiltered search; supported-source `first_submitted` in-window; verifiable complete byline; and surviving top-100 exclusion. An empty or sparse theme means only that this query/window produced little usable evidence, not that nobody works on the theme.
