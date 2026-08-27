---
name: network
description: "Use when the user asks about a researcher's collaborators, co-authors, research network, wants to map who works with whom, or wants to see how a researcher's focus has diverged from their collaborators. Triggers on questions like 'who does X collaborate with', 'show me X's network', 'find connections between researchers', or 'how has X's work drifted from their coauthors'."
---

# Collaboration Network

Map the coauthor name-bucket graph associated with a researcher.

## Input

The user provides an author name (e.g., "Yoshua Bengio").

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

For each call below, distinguish a tool error from a successful empty result,
read and report material top-level and profile `warnings`, and, when
`_meta.limit_clamped` is present, report its `requested`, `effective`, and `max`
values rather than claiming the requested limit was searched.

### Step 1: Get author baseline

First call `get_author_identity` with:
- `author` (string): the focal author name provided by the user

If `candidates` are returned, ask the user to select one before continuing. Do
not proceed while candidates remain unresolved. If the identity is
unverifiable or not found, say so and stop.

Then call `get_author_profile` with:
- `author` (string): the selected canonical display name
- `orcid` (string, when returned by identity resolution): the resolved ORCID

Use the profile's `resolved_name` for corpus chaining. Read its `categories`,
`summary`, `timeline`, and `stats_source`: `orcid_keyed` statistics are
identity-linked, while `name_keyed` statistics are aggregates for a
resolved-name bucket. Categories are source-specific corpus labels. The
first/last values and timeline are observed record/submission-based paper
activity, not publication chronology.

### Step 2: Get direct collaborators

Call `find_coauthors` with:
- `author` (string): the focal profile's `resolved_name`
- `limit` (integer): 20

This returns top-N coauthor name buckets for the focal normalized-name bucket,
ranked by `shared_papers`. Display `coauthor` and retain `coauthor_norm` as the
server matching and chaining key. Note the top 5 returned buckets for the next
step. A successful empty `coauthors` array is a valid terminal graph result.

### Step 3: Get second-degree connections

For each of the top 5 direct buckets from Step 2, call `find_coauthors` with:
- `author` (string): the direct bucket's `coauthor_norm`
- `limit` (integer): 10

Collect second-degree name-bucket paths. Exclude focal and direct buckets by
their exact returned normalized keys while preserving returned display names.
These paths do not establish person-level identity or confirmed person-level
edges. A successful empty result is valid.

### Step 4: Compare focal author with top collaborator buckets

Call `compare_authors` with:
- `authors` (array of strings): the focal profile's `resolved_name` and up to 4
  direct `coauthor_norm` values (max 5 total; the tool accepts 2–10 names)

The tool accepts names only and returns name-keyed corpus profiles plus
`shared_categories`; it does not return collaboration-edge counts or
identity-safe profiles of people. Read each profile's `categories`, `summary`,
`timeline`, `stats_source`, and warnings. The shared-paper count for every
direct edge must come from Step 2's `shared_papers`.

### Step 5: Compare returned corpus profiles (no tool call)

For each compared direct bucket, compute a descriptive characterization from
the `compare_authors` result:

- **Concentration delta**: divide each exact returned category count by the sum
  of that profile's returned category counts. Identify the top 1–2 exact labels
  where either returned share exceeds the other by at least 10 percentage
  points.
- **Paper-count ratio**: collaborator-bucket `summary.total_papers` divided by
  focal `summary.total_papers`, stating both profiles' `stats_source`.
- **Record-activity comparison**: compare only overlapping returned `timeline`
  buckets and describe the observed differences. Do not infer publication
  chronology, career phase, pivots, acceleration, cooling, or collaboration
  change.

Synthesize these into a one-sentence description of differences between the
returned corpus profiles, qualified by their provenance.

## Output Format

### Network Summary

A brief paragraph:
- Selected canonical author name and the count of direct name buckets returned
  by Step 2, together with its effective cap
- Profile `summary.unique_coauthors` only as a separate, provenance-qualified
  corpus name count with `stats_source`
- Primary source-specific corpus category labels returned in Step 1

### Direct Coauthor Name Buckets

A table of name buckets from Step 2 (up to 10 of the returned top-N):

| Coauthor name bucket | Shared papers | Leading returned category |
|----------------------|---------------|---------------------------|
| Name                 | 15            | cs.LG                     |
| ...                  | ...           | ...                       |

Take `shared_papers` from the focal Step 2 edge. The category column comes from
the name-keyed Step 4 comparison profile and must be qualified as such. For
buckets not compared, omit the category or mark it as "—".

### Second-Degree Connections

A list of up to 10 notable second-degree name-bucket paths from Step 3, drawn
from the up-to-10 result for each queried direct bucket. These are buckets not
returned as direct buckets and not the focal bucket:

- **Returned display name** (paths through: Direct bucket A, Direct bucket B)
  — leading returned category if known

Prioritizing buckets with multiple paths is allowed, but multiple paths do not
prove that the bucket represents one person.

### Cross-Category Comparison

Highlight direct buckets in the compared subset whose returned leading category
label differs from the focal profile's returned leading label:

- **Returned display name** (leading label: q-bio.BM)

These are differences between source-specific labels in the compared
name-bucket profiles; they do not establish interdisciplinarity or describe the
whole network. If none are found, report only that no such difference appeared
in the compared subset.

### Returned Profile Differences

For each direct bucket compared in Step 4, present the characterization computed
in Step 5. Use this format:

**Coauthor name bucket** (N shared papers from the focal Step 2 edge)
- *Characterization*: the one-sentence, provenance-qualified description
- *Concentration delta*: differences between exact returned category labels,
  in percentage points of each profile's returned category-count total
- *Paper-count ratio*: `summary.total_papers` ratio with both `stats_source`
  values
- *Record activity*: descriptive differences across overlapping returned
  `timeline` buckets

Do not call these identity-resolved people, closest collaborators, publication
trajectories, or intellectual drift. Do not infer collaboration change or
whole-network homogeneity. Order the displayed subset by the strongest
supported profile difference.

### Suggested Follow-ups

- Ask for a profile of `<returned coauthor name>` for an interesting bucket.
- Ask for `<returned coauthor name>`'s network to resolve and explore it.
- Ask for papers similar to `<paper_id>` for a paper of interest.
