---
name: network
description: "Use when the user asks about a researcher's collaborators, coauthors, research network, connections between researchers, or how a researcher's focus differs from close collaborators."
---

# Collaboration Network

Map the name-bucket collaboration network around one identity-resolved researcher, then compare only resolved collaborators.

## Input

The user supplies a focal researcher name or ORCID and may supply a paper ID as identity context.

## Tool discovery and response discipline

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the matching exposed tools. If the required Valency Bond tools are unavailable, say so and stop.

After every call:

1. Read `warnings` and report any warning that changes identity, coverage, or interpretation.
2. If `_meta.limit_clamped` is a nonempty array, report each event's `tool`, `requested`, `effective`, and `max` values and use the effective limit for coverage claims.
3. Treat an empty array or zero count as a valid empty result. Follow the explicit empty-result branch instead of inventing entries.
4. Treat absent or null fields as unavailable. Do not synthesize categories, dates, identities, counts, or affiliations.
5. If a returned paper has `authors_truncated: true`, treat its visible byline as incomplete and report `total_authors` when present. Visible-list absence is not proof that an author is absent.
6. Preserve category lists and labels as returned. They are source-specific vocabularies, may be mixed across profiles, and may be null or empty.
7. Link paper titles with a non-null `url`; use the paper `id` only when no URL is available.
8. Label `datestamp` as the source record/update date. For arXiv, bioRxiv, and medRxiv, label non-null `first_submitted` as a first-submission estimate. For every other or unknown source, label it as a record-derived month estimate. None of these fields is a publication date.

For local bucket equality only, define one `comparison_key(name)`: Unicode case-fold, fold diacritics and common Latin ligatures, delete apostrophes, trim, and collapse whitespace. Apply it to focal, direct, and second-degree normalized names; preserve returned display names in output.

## Workflow

Execute these steps in order.

### 1. Resolve the focal researcher

Call `get_author_identity` with exactly one applicable object:

```json
{"author": "<focal name>"}
```

```json
{"author": "<focal name>", "paper_id": "<user-supplied versioned paper ID>"}
```

```json
{"orcid": "<user-supplied ORCID>"}
```

Inspect `warnings`, `career_metrics`, `orcid`, `resolved_name`, and `candidates`.

- If `candidates` is nonempty, present only returned candidate evidence. Ask the user for an ORCID or a paper that identifies the intended researcher, then re-call `get_author_identity` with that public context. Do not continue as an identity-safe network while candidates remain.
- If no usable identity is returned and the response indicates not found or unverifiable, report that the focal researcher could not be resolved and stop.
- Use non-null `career_metrics.display_name` as the focal display name. Retain `resolved_name` only as a corpus matching key.

This step is complete only when one focal human is selected.

### 2. Get the focal corpus profile

With a resolved ORCID, call `get_author_profile`:

```json
{"author": "<focal display name>", "orcid": "<resolved ORCID>"}
```

Otherwise call:

```json
{"author": "<focal display name>"}
```

Record `stats_source`, profile warnings, `summary`, `categories`, and `timeline`. `orcid_keyed` aggregates are identity-linked; `name_keyed` aggregates cover a resolved name bucket and can fragment variants. Profile category labels are not a universal ontology.

Treat `summary.first_paper`, `summary.last_paper`, and timeline `year` buckets as observed paper activity. Their basis can mix first-submission estimates with source record/update dates.

### 3. Get direct coauthor name buckets

If the profile has a non-null `resolved_name`, call `find_coauthors`:

```json
{"author": "<focal profile resolved_name>", "limit": 20}
```

Otherwise report that the graph cannot be built because no corpus name key was returned and stop.

Each row is a coauthor name bucket linked to one focal normalized-name bucket, ranked by `shared_papers`. The response is top-N data, not a complete identity-resolved graph. Display `coauthor`. Use `coauthor_norm` only for matching, set membership, within-response deduplication, and exact name-bucket chaining.

If `coauthors` is empty, output the focal summary, state that no collaborator buckets were returned, skip second-degree and comparison calls, and stop.

### 4. Resolve collaborators only for person-level comparison

Run this step only when the user asks for identity-level collaborator profiles, category comparisons, or trajectory differences. For a direct/second-degree network request, skip Steps 4, 6, and 7; continue to Step 5 and return the name-bucket graph without forcing collaborator disambiguation.

Track `get_author_identity` calls against its 10-call task budget, including the focal lookup and any focal candidate re-call. From the leading Step 3 rows, resolve at most five collaborators while budget remains. Call separately for each displayed `coauthor`:

```json
{"author": "<coauthor display name>"}
```

If a known shared versioned paper ID came from user context, prefer:

```json
{"author": "<coauthor display name>", "paper_id": "<known shared paper ID>"}
```

`find_coauthors` supplies a count, not shared paper IDs; never invent a paper hint. If a candidate re-call is needed, decrement the remaining budget before making it. Stop resolving collaborators when no call remains; keep each unattempted or unresolved name-bucket edge in the graph and label it unresolved rather than exceeding the tool budget or forcing clarification unrelated to the requested comparison.

Deduplicate substantive collaborator profiles by selected ORCID. Without an ORCID, keep paper-scoped resolutions separate unless the tool unambiguously returns the same researcher. If two graph buckets resolve to one person, retain both graph rows and report the fragmentation; compare that person once. Do not merge unresolved spelling variants.

### 5. Get second-degree name buckets

For each of the up to five Step 3 rows, call `find_coauthors` using the server-returned matching key:

```json
{"author": "<coauthor_norm>", "limit": 10}
```

Create a direct-bucket set by applying `comparison_key` to every Step 3 `coauthor_norm`; apply the same key to the focal `resolved_name` and every second-degree `coauthor_norm`. Exclude keys already direct or equal to the focal key. Combine paths only when these comparison keys are identical; display the associated `coauthor` form. Label all such nodes as second-degree name buckets. Do not silently merge merely similar unresolved names.

If every second-degree call is empty after exclusions, state that no second-degree buckets were returned.

If the user did not request person-level comparison, skip Steps 6 and 7.

### 6. Obtain comparison profiles

`compare_authors` accepts names only. Use it only for a comparison set whose focal and collaborator name buckets are unambiguous: identity resolution selected one stable researcher, no candidate or collision/fragmentation warning remains, and the resolved normalized name aligns with the graph bucket.

When at least two such buckets are available, call:

```json
{"authors": ["<focal resolved name>", "<unambiguous collaborator coauthor_norm>", "<another unambiguous collaborator coauthor_norm>"]}
```

The array may contain 2–10 names. Inspect top-level `warnings` and every returned profile's `warnings` and `stats_source`. If the result reveals ambiguity, fragmentation, or an unacceptable name-keyed conflation, discard it for substantive comparison and use resolved profile calls instead.

For every collaborator not safe for a name-only compare call—but successfully identity-resolved—call `get_author_profile` individually. Prefer:

```json
{"author": "<collaborator canonical display name>", "orcid": "<resolved ORCID>"}
```

When no ORCID exists, call:

```json
{"author": "<collaborator canonical display name>"}
```

Qualify the latter by its returned `stats_source`; a paper-scoped identity resolution does not turn a name-keyed aggregate into an identity-keyed one. `compare_authors` returns profiles and `shared_categories`; it does not return collaboration-edge counts. Source every displayed shared-paper count from the focal `find_coauthors` row in Step 3.

### 7. Characterize differences

For each resolved collaborator with a usable profile:

1. **Category concentration:** Retain non-null category labels. If both profiles have nonempty, clearly comparable vocabularies and positive category-count sums, compute each label's share of the returned category assignments as `count / sum(category counts)`. Report the largest differences of at least 10 percentage points. Compare only exact labels from the same vocabulary. If labels are missing or vocabularies are mixed/incompatible, show each profile's returned labels separately and state that concentration was not compared.
2. **Corpus paper-count ratio:** Use each profile's `summary.total_papers` and name both `stats_source` values. Divide collaborator by focal only when the focal total is greater than zero. If the focal total is zero, report the ratio as unavailable; never divide by zero.
3. **Record-activity trajectory:** Compare the latest up to three overlapping timeline years available. Call these record-activity buckets, not publications. With fewer than three comparable years, missing timelines, or sparse nonoverlapping data, give only a descriptive sparse-data note; do not infer acceleration, a career phase, a research pivot, or collaboration cooling.

Lead with the strongest supported difference. If none is supported, say the available profiles are insufficiently comparable rather than asserting similarity.

## Output

### Network Summary

- focal canonical display name and stable identifier when present
- corpus paper count and profile-reported unique coauthor-name count, each labeled with `stats_source`
- returned direct-bucket count and effective cap
- focal category labels as returned, or “unavailable”
- material identity, fragmentation, and limit warnings

Do not call the returned direct list the researcher's total collaborators.

### Direct Coauthor Name Buckets

| Coauthor display name | Shared papers in name-bucket edge | Resolution | Leading category label |
|---|---:|---|---|

Use `coauthor` and the Step 3 `shared_papers` value. Fill the category column only from a usable resolved comparison profile; otherwise show “unavailable.”

### Second-Degree Name Buckets

Show up to ten buckets, prioritizing exact `coauthor_norm` buckets reached through multiple direct buckets:

- **displayed `coauthor`** — connected through: direct coauthor display names

State that these are name-bucket paths, not confirmed person-level edges.

### Cross-Category Connections

Assess this section only when focal and collaborator categories are nonempty and use comparable vocabularies. Describe differing leading labels as a possible cross-category connection, not proof of interdisciplinarity. For missing or mixed vocabularies, state that cross-category connections could not be assessed. If comparable profiles have no differing leading labels, say none were identified in the compared subset; do not generalize to the full network.

### Collaborator Differences

For each compared collaborator show:

**Collaborator display name** (`shared_papers` from Step 3)

- **Category concentration:** supported percentage-point differences, or why unavailable
- **Corpus paper-count ratio:** value and both `stats_source` labels, or “unavailable”
- **Record-activity trajectory:** comparison over the available overlapping buckets, explicitly labeled as record activity

Order by strongest supported difference, not by an invented divergence score. If no collaborators resolved or no profiles are comparable, say so and omit numerical characterizations.

### Completion

The network is complete when the focal person is resolved; direct and second-degree edges are labeled as name-bucket/top-N data; selected collaborators are resolved before comparison; shared-paper counts come only from `find_coauthors`; category, zero-total, and sparse-timeline branches are handled; and every trajectory claim is about record activity rather than publication.
