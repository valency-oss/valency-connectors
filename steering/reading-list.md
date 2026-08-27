---
name: reading-list
description: "Use when the user asks what a specific researcher should read next, wants adjacent literature around that person's work, or requests a researcher-anchored curated bibliography."
---

# Researcher Reading List

Build a reading list around one identity-resolved researcher by using separate citation-ranked and record-recent seed pools, then retrieving paper-to-paper semantic neighbors. Preserve evidence per seed and make every identity, citation, date, and byline limitation visible.

## Input

Require a focal author name. Accept an optional versioned corpus paper ID when the user provides paper context; use it as an identity hint.

## Tool and metadata discipline

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop.

For every call, inspect `warnings`, empty results, and `_meta.limit_clamped`. For every paper, inspect `authors_truncated`. Missing metadata stays unknown; never synthesize an abstract, author, category, source, citation count, stable identifier, or date. Prefer a non-null `url`. Preserve each source's `categories` list instead of treating categories as one cross-source taxonomy.

`datestamp` is always a source record/update date and drives record-recency ordering. For arXiv, bioRxiv, and medRxiv, optional `first_submitted` is a first-submission estimate; for every other or unknown source it is a record-derived month estimate. None of these fields is a publication date or year.

Define:

- `paper_key(p)`: `(source, base_id)` when `base_id` is present; otherwise `(source, id)`. Treat a missing source as an explicit unknown-source component. Do not parse version suffixes locally.
- `comparison_key(name)`: one uniform name fold for local self-authorship checks—Unicode case-fold, transliterate common Latin ligatures, NFKD-fold diacritics, delete apostrophes, trim, and collapse whitespace. Keep returned names for display.

## Workflow

### 1. Resolve the focal human

Call `get_author_identity`:

```json
{"author":"<user-supplied name>"}
```

Add `"paper_id":"<versioned corpus paper ID>"` when the user supplied a paper context.

A non-null `resolved_name` alone is not proof of a unique person. Inspect `warnings`, `career_metrics`, and `candidates`:

- If `candidates` is non-empty, show their display name, institution, and recent-title evidence. Ask the user for an ORCID or a paper that identifies the intended researcher, then re-call `get_author_identity` with that public context. Do not continue while candidates remain.
- If the result remains unverifiable, explain that an identity-specific reading list cannot be completed and stop.
- Prefer ORCID in researcher calls. Without one, use the canonical author name plus a paper hint when available and retain the returned disambiguation qualification. Use `career_metrics.display_name` when non-null as the display name.

Call `get_author_profile` for corpus context and known focal name forms:

```json
{"author":"<canonical focal display name>","orcid":"<resolved ORCID>"}
```

Omit `orcid` only when null. Record `resolved_name`, `stats_source`, profile warnings, corpus `summary.total_papers`, and returned category/count entries.

Build a focal alias-key set from the input name, identity `resolved_name`, non-null canonical display names, and profile `resolved_name`. These are comparison aliases, not stable identities.

### 2. Retrieve two identity-specific seed pools

Make separate `find_papers_by_researcher` calls, preferring ORCID when available.

Citation-ranked pool:

```json
{"orcid":"<resolved ORCID>","limit":10,"sort_by":"citations","enrich_citations":true}
```

Record-recent pool:

```json
{"orcid":"<resolved ORCID>","limit":10,"sort_by":"recency"}
```

When ORCID is null, replace it in both objects with `"author":"<canonical focal display name>"` and add the user-supplied versioned `paper_id` when available.

For both responses, inspect `candidates`, `disambiguation_status`, `match_type`, warnings, returned count, and `_meta.limit_clamped`. Resolve candidates before seed selection. Stop on `unverifiable`; explicitly qualify `potentially_incomplete_recent_window`, name-only/linked-unverified rows, and any hard cap. Prefer verified rows for identity-critical seeds.

Citation counts are nullable, enriched best-effort metadata. If citation coverage is thin or warnings qualify the ranking, call the first usable item the **highest citation-ranked result returned**, not the researcher's definitively most-cited paper. The recency call is ordered by record recency, not publication date. Do not call either capped pool a complete oeuvre.

Deduplicate the union by `paper_key`, retaining the most canonical/latest returned record and both pool provenances. Preserve citation nulls and all material warnings.

### 3. Select 3–5 grounded seeds

Choose 3–5 distinct paper families when available:

1. Include the highest usable citation-ranked returned result, with the citation qualification from Step 2.
2. Include the first record-recent result with a substantive returned abstract.
3. Fill remaining slots with papers whose titles, abstracts, and source-specific category lists establish distinct intellectual threads.

Do not use category difference alone across sources as proof of thematic difference. A seed explanation must be supported by its title and abstract. If only 1–2 usable seeds exist, proceed with a shorter list and explain why; if none has enough metadata to ground a thread, stop.

### 4. Retrieve semantic neighbors with enough metadata

For each seed, call `find_similar_papers`:

```json
{"paper_id":"<seed paper id>","limit":10,"include_abstract":true,"max_authors":500}
```

Omit `source` so discovery can cross sources. Each result is ranked by cosine `similarity_score` to the seed paper's stored embedding.

A seed without an embedding returns a successful empty result with a warning. Mark that seed as skipped and continue. Treat a genuine tool error separately. Inspect warnings, empty results, `_meta.limit_clamped`, and every paper's truncation fields.

### 5. Deduplicate and filter conservatively

Process all similarity responses together:

1. Attach `{seed_key, seed_title, similarity_score}` to every occurrence before deduplication.
2. Deduplicate by `paper_key`. Prefer the canonical/latest returned record, but retain a separate score and provenance entry for every seed that surfaced the paper. Never replace all per-seed scores with one global maximum.
3. Exclude any recommendation whose `paper_key` is a selected seed or appears in either returned focal-researcher pool.
4. **Self-authorship filter:** exclude a paper if any author in its complete returned byline has a key in the focal alias-key set.
5. If `authors` is empty, exclude the paper because self-authorship cannot be checked. If `authors_truncated` remains true after requesting 500, exclude it as unverifiable rather than claiming the focal author is absent.

Passing this filter proves only that no known focal alias occurs in the complete returned byline and that the paper is not in the capped focal pools. Label the result that way; do not claim exhaustive identity-level non-authorship.

Group remaining papers by seed provenance. Within each thread, order by that seed's own `similarity_score`. A paper surfaced by multiple seeds appears once in the cross-thread section with every seed-specific score retained.

### 6. Ground explanations

Use the seed and recommendation titles, substantive abstracts, and source-specific category lists to explain the connection. If a recommendation's abstract is missing or empty despite the explicit request, either ground the explanation only in the available title/categories and label that basis, or omit the explanation; never invent content.

## Output

### Researcher and retrieval summary

Report:

- canonical focal display name and stable identifier type;
- corpus paper count, `stats_source`, and source-specific top category/count entries;
- the citation-ranked and record-recent pool sizes, limits, disambiguation statuses, and material warnings;
- citation coverage/null qualifications;
- skipped seeds and empty-result reasons.

### Reading list by thread

For each seed, give a one-line abstract-grounded thread description and a seed card containing:

- title and paper ID;
- source and complete category list when available;
- citation count when non-null, with its returned-ranking label;
- for arXiv, bioRxiv, or medRxiv, `first_submitted` as **first-submission estimate**; for other or unknown sources, `first_submitted` as **record-derived month estimate**; otherwise `datestamp` as **record/update date**;
- non-null `url`.

Then show up to 8 surviving recommendations for that thread—fewer, including zero, is valid after deduplication and self-authorship checks. For each recommendation include:

- title, paper ID, and non-null `url`;
- visible author names; because truncated bylines were excluded, this is the complete returned byline;
- source and complete category list when available;
- source-aware **first-submission estimate**, **record-derived month estimate**, or **record/update date**, using the same rule as the seed card;
- that thread's `similarity_score`;
- one grounded sentence explaining the connection;
- **Self-authorship check**: no known focal alias appeared in the complete returned byline. Do not call this a self-citation check.

### Cross-thread results

For every recommendation surfaced by multiple seeds, list all seed names and their separate `similarity_score` values, plus a grounded explanation of the intersection. Omit this section when none survive.

### Limitations

State any candidate ambiguity, disambiguation status, caps or clamps, citation warnings/nulls, missing abstracts, empty similarity responses, and recommendations excluded because their bylines remained empty or truncated. Dates remain source-aware first-submission estimates, record-derived month estimates, or source record/update dates—never publication dates.
