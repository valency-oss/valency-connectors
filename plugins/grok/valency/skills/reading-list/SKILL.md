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

For every call, inspect `warnings` and distinguish successful empty results from tool errors; for every paper, inspect `authors_truncated`. Preserve each source's `categories` list instead of treating categories as one cross-source taxonomy.

Date fields carry the **source-aware date label**: `datestamp` is always a source record/update date and drives record-recency ordering; for arXiv, bioRxiv, and medRxiv, optional `first_submitted` is a first-submission estimate, and for every other or unknown source it is a record-derived month estimate. None of these fields is a publication date or year.

Define:

- `paper_key(p)`: `(source, base_id ?? id)` — versions share a family without conflating identifiers across sources.
- `comparison_key(name)`: one uniform name fold for local self-authorship checks—Unicode case-fold, transliterate common Latin ligatures, NFKD-fold diacritics, delete apostrophes, trim, and collapse whitespace. Keep returned names for display.

## Workflow

### 1. Resolve the focal human

Call `get_author_identity`:

```json
{"author":"<user-supplied name>"}
```

Add `"paper_id":"<versioned corpus paper ID>"` when the user supplied a paper context.

A non-null `resolved_name` alone is not proof of a unique person. Inspect `warnings`, `career_metrics`, and `candidates`:

- If `candidates` is non-empty, show the returned display name, institution, and recent-title evidence, ask the user to pick, and re-call with the chosen candidate's returned stable author identifier — or an ORCID or identifying paper when it is null. When a re-call carrying an ORCID returns a single collision candidate with `confidence` >= 0.95, select it without prompting again. Do not continue while candidates remain unresolved.
- If the result remains unverifiable, explain that an identity-specific reading list cannot be completed and stop.
- In researcher calls, use the strongest resolved key: ORCID, then the stable author identifier returned in `career_metrics`, then the canonical author name plus a paper hint, retaining the returned disambiguation qualification. Use `career_metrics.display_name` when non-null as the display name.

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
{"orcid":"<resolved ORCID>","limit":10,"sort_by":"citations"}
```

Record-recent pool:

```json
{"orcid":"<resolved ORCID>","limit":10,"sort_by":"recency"}
```

When ORCID is null, replace it in both objects with the stable author-identifier parameter, set to the value returned in `career_metrics`, when present, otherwise with `"author":"<canonical focal display name>"` plus the user-supplied versioned `paper_id` when available.

For both responses, resolve `candidates` before seed selection and stop on `unverifiable`; explicitly qualify `potentially_incomplete_recent_window`, name-only/linked-unverified rows, and any hard cap. Prefer verified rows for identity-critical seeds.

Citation counts are nullable, enriched best-effort metadata. If citation coverage is thin or warnings qualify the ranking, call the first usable item the **highest citation-ranked result returned**, not the researcher's definitively most-cited paper. The recency call is ordered by record recency, not publication date. Do not call either capped pool a complete oeuvre.

Deduplicate the union by `paper_key`, retaining both pool provenances. Preserve citation nulls and all material warnings.

### 3. Select 3–5 grounded seeds

Choose 3–5 distinct paper families when available:

1. Include the highest usable citation-ranked returned result, with the citation qualification from Step 2.
2. Include the first record-recent result with a substantive returned abstract.
3. Fill remaining slots with papers whose titles, abstracts, and source-specific category lists establish distinct intellectual threads.

A seed's thread must be supported by its title and abstract; source-specific category-list differences alone do not establish distinct threads. If only 1–2 usable seeds exist, proceed with a shorter list and explain why; if none has enough metadata to ground a thread, stop.

### 4. Retrieve semantic neighbors with enough metadata

For each seed, call `find_similar_papers`:

```json
{"paper_id":"<seed paper id>","limit":10,"include_abstract":true,"max_authors":500}
```

Omit `source` so discovery can cross sources. Each result is ranked by cosine `similarity_score` to the seed paper's stored embedding.

A seed without an embedding returns a successful empty result with a warning. Mark that seed as skipped and continue. Treat a genuine tool error separately.

### 5. Deduplicate and filter conservatively

Process all similarity responses together:

1. Attach `{seed_key, seed_title, similarity_score}` to every occurrence before deduplication.
2. Deduplicate by `paper_key`, retaining a separate score and provenance entry for every seed that surfaced the paper.
3. Exclude any recommendation whose `paper_key` is a selected seed or appears in either returned focal-researcher pool.
4. **Self-authorship filter:** exclude a paper if any author in its complete returned byline has a key in the focal alias-key set.
5. If `authors` is empty, exclude the paper because self-authorship cannot be checked. If `authors_truncated` remains true after requesting 500, exclude it as unverifiable rather than claiming the focal author is absent.

Passing this filter proves only that no known focal alias occurs in the complete returned byline and that the paper is not in the capped focal pools. Label the result that way; do not claim exhaustive identity-level non-authorship.

Group remaining papers by seed provenance. Within each thread, order by that seed's own `similarity_score`. A paper surfaced by multiple seeds appears once in the cross-thread section with every seed-specific score retained.

### 6. Ground explanations

Use the seed and recommendation titles, substantive abstracts, and source-specific category lists to explain the connection. If a recommendation's abstract is missing or empty despite the explicit request, either ground the explanation only in the available title/categories and label that basis, or omit the explanation.

## Output

### Researcher and retrieval summary

Report:

- canonical focal display name and stable identifier type;
- corpus paper count, `stats_source`, and source-specific top category/count entries;
- the citation-ranked and record-recent pool sizes, limits, disambiguation statuses, and material warnings;
- citation coverage/null qualifications;
- skipped seeds and empty-result reasons;
- recommendations excluded because their bylines were empty or still truncated.

### Reading list by thread

For each seed, give a one-line abstract-grounded thread description and a seed card containing:

- title and paper ID;
- source and complete category list when available;
- citation count when non-null, with its returned-ranking label;
- the source-aware date label;
- non-null `url`.

Then show up to 8 surviving recommendations for that thread—fewer, including zero, is valid after deduplication and self-authorship checks. For each recommendation include:

- title, paper ID, and non-null `url`;
- visible author names; because truncated bylines were excluded, this is the complete returned byline;
- source and complete category list when available;
- the source-aware date label;
- that thread's `similarity_score`;
- one grounded sentence explaining the connection;
- **Self-authorship check**: no known focal alias appeared in the complete returned byline.

### Cross-thread results

For every recommendation surfaced by multiple seeds, list all seed names and their separate `similarity_score` values, plus a grounded explanation of the intersection. Omit this section when none survive.
