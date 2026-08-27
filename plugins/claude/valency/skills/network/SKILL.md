---
name: network
description: "Use when the user asks about a researcher's collaborators, coauthors, research network, connections between researchers, or how a researcher's focus differs from close collaborators."
---

# Collaboration Network

Map the name-bucket collaboration network around a researcher; for person-level comparison requests, resolve the focal identity and compare only resolved collaborators.

## Input

The user supplies a focal researcher name or ORCID and may supply a paper ID as identity context.

## Tool discovery and response discipline

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the matching exposed tools. If the required Valency Bond tools are unavailable, say so and stop.

After every call, surface any warning that changes identity, coverage, or interpretation, and preserve category lists and labels as returned — they are source-specific vocabularies, may be mixed across profiles, and may be null or empty.

For local bucket equality only, define one `comparison_key(name)`: Unicode case-fold, transliterate common Latin ligatures, NFKD-fold diacritics, delete apostrophes, trim, and collapse whitespace. Apply it to focal, direct, and second-degree normalized names; preserve returned display names in output.

## Workflow

Route the request before calling anything. A **network-map** request — coauthor lists, second-degree connections, "who does X collaborate with" — runs Steps 2–4 with the user-supplied name and returns the name-bucket graph without identity clarification; if the name looks ambiguous, deliver the graph with an ambiguity note instead of stopping. A **person-level comparison** request — identity-level collaborator profiles, category comparisons, trajectory differences — runs all steps in order, starting with focal identity resolution.

### 1. Resolve the focal researcher (comparison branch only)

Call `get_author_identity` with `author` (adding `paper_id` when the user supplied a paper as identity context), with both `author` and `orcid` when the user supplied both, or with `orcid` alone when only an ORCID was given.

Inspect `warnings`, `career_metrics`, `orcid`, `resolved_name`, and `candidates`.

- If `candidates` is nonempty and a single ORCID-collision candidate has `confidence` >= 0.95, select it and re-call with its returned stable author identifier. Otherwise present the returned candidate evidence, ask the user to pick, and re-call with the chosen candidate's returned stable author identifier — or an ORCID or identifying paper when it is null. Do not continue the comparison while candidates remain unresolved.
- If no usable identity is returned and the response indicates not found or unverifiable, report that the focal researcher could not be resolved and offer the network-map branch instead.
- Use non-null `career_metrics.display_name` as the focal display name. Retain `resolved_name` only as a corpus matching key.

This step is complete only when one focal human is selected.

### 2. Get the focal corpus profile

Call `get_author_profile` with `author` set to the identity `resolved_name` (comparison branch) or the user-supplied name (network-map branch), adding `orcid` when resolved.

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

### 4. Get second-degree name buckets

For each of the up to five leading Step 3 rows, call `find_coauthors` using the server-returned matching key:

```json
{"author": "<coauthor_norm>", "limit": 10}
```

Create a direct-bucket set by applying `comparison_key` to every Step 3 `coauthor_norm`; apply the same key to the focal `resolved_name` and every second-degree `coauthor_norm`. Exclude keys already direct or equal to the focal key. Combine paths only when these comparison keys are identical; display the associated `coauthor` form. Label all such nodes as second-degree name buckets.

If every second-degree call is empty after exclusions, state that no second-degree buckets were returned. This ends the network-map branch.

### 5. Resolve collaborators for comparison (comparison branch only)

Budget about 10 `get_author_identity` calls per task — the server's recommended per-task limit at the default tier — including the focal lookup and any candidate re-call. From the leading Step 3 rows, resolve at most five collaborators while budget remains. Call separately for each displayed `coauthor`:

```json
{"author": "<coauthor display name>"}
```

If a known shared versioned paper ID came from user context, prefer the same call with `paper_id` added (`find_coauthors` supplies a count, not shared paper IDs, so there is no returned paper hint to reuse). Stop resolving collaborators when no call remains; keep each unattempted or unresolved name-bucket edge in the graph and label it unresolved rather than exceeding the budget or forcing clarification unrelated to the requested comparison.

Deduplicate substantive collaborator profiles by ORCID or the returned stable author identifier; keep resolutions with neither separate unless the tool unambiguously returns the same researcher. If two graph buckets resolve to one person, retain both graph rows and report the fragmentation; compare that person once.

### 6. Obtain comparison profiles

`compare_authors` accepts names only. Use it only for a comparison set whose focal and collaborator name buckets are unambiguous: identity resolution selected one stable researcher, no candidate or collision/fragmentation warning remains, and the resolved normalized name aligns with the graph bucket.

When at least two such buckets are available, call:

```json
{"authors": ["<focal resolved name>", "<unambiguous collaborator coauthor_norm>", "<another unambiguous collaborator coauthor_norm>"]}
```

The array may contain 2–10 names. Every requested name comes back with a profile: names that could not be resolved return placeholders with `resolved_name: null`, zero counts, and a warning — exclude placeholders from the comparison and say those names were not found. Every found profile is a name-keyed aggregate (`stats_source` is always `name_keyed` here).

For every collaborator not safe for a name-only compare call—but successfully identity-resolved—call `get_author_profile` individually with `author` set to the collaborator's canonical display name, adding `orcid` when resolved. Qualify a no-ORCID profile by its returned `stats_source`; a paper-scoped identity resolution does not turn a name-keyed aggregate into an identity-keyed one. `compare_authors` returns profiles and `shared_categories`; source every displayed shared-paper count from the focal `find_coauthors` row in Step 3.

### 7. Characterize differences

For each resolved collaborator with a usable profile:

1. **Category concentration:** Retain non-null category labels. If both profiles have nonempty labels from the same source vocabulary and positive category-count sums, compute each label's share of the returned category assignments as `count / sum(category counts)`. Report the largest differences of at least 10 percentage points, comparing only exact labels. If labels are missing or the vocabularies come from different source namespaces, show each profile's returned labels separately and state that concentration was not compared.
2. **Corpus paper-count ratio:** Use each profile's `summary.total_papers` and name both `stats_source` values. Divide collaborator by focal only when the focal total is greater than zero; report the ratio as unavailable otherwise.
3. **Record-activity trajectory:** Compare the latest up to three overlapping timeline years available. Call these record-activity buckets, not publications. With fewer than three comparable years, missing timelines, or sparse nonoverlapping data, give only a descriptive sparse-data note.

Lead with the strongest supported difference. If none is supported, say the available profiles are insufficiently comparable rather than asserting similarity.

## Output

### Network Summary

- focal canonical display name and stable identifier when present
- corpus paper count and profile-reported unique coauthor-name count, each labeled with `stats_source`
- returned direct-collaborator count (a capped top-N result, not the total)
- focal category labels as returned, or “unavailable”
- material identity and fragmentation warnings

### Direct Collaborators

| Coauthor display name | Shared papers in name-bucket edge | Resolution | Leading category label |
|---|---:|---|---|

Use `coauthor` and the Step 3 `shared_papers` value. Fill the Resolution and category columns only from the comparison branch's resolved profiles; otherwise show “—”.

### Second-Degree Connections

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

The output is complete when every section of the requested branch is populated from its stated source or explicitly marked unavailable.
