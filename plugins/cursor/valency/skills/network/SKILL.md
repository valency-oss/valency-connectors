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

For each call below, distinguish a tool error from a successful empty result
and surface material top-level and profile `warnings`.

### Step 1: Get author baseline

Call `get_author_profile` with:
- `author` (string): the author name

If no profile result is found, tell the user the author was not found and
suggest checking the spelling. Stop here.

Treat the result as a corpus name-bucket profile, labeling counts with the
returned `stats_source` (`orcid_keyed` means the server unified fragmented name
variants). Note its returned source-specific category labels for the comparison
below. Its first/last values and timeline describe observed
record/submission-based paper activity, not publication chronology.

### Step 2: Get direct collaborators

Call `find_coauthors` with:
- `author` (string): the author name
- `limit` (integer): 20

This returns top-N coauthor name buckets for the focal normalized-name bucket,
ranked by `shared_papers`. Note the top 5 returned buckets for the next step.
Display `coauthor`; retain `coauthor_norm` only as the matching and chaining key.
A successful empty `coauthors` result is a valid terminal graph result.

### Step 3: Get second-degree connections

For each of the top 5 direct buckets from Step 2, call `find_coauthors` with:
- `author` (string): the direct bucket's matching key (`coauthor_norm`)
- `limit` (integer): 10

Collect second-degree name-bucket paths. Remove focal and direct buckets by
their exact returned normalized keys while preserving `coauthor` for display.

### Step 4: Compare focal author with top collaborator buckets

Call `compare_authors` with:
- `authors` (array of strings): a JSON array containing the focal author name
  and up to 4 direct `coauthor_norm` values (max 5 total; the tool requires
  2–10 names), e.g. `["Yoshua Bengio", "Ian Goodfellow", "Aaron Courville"]`

This returns name-keyed corpus profiles with source-specific category counts
and a `shared_categories` array. Every requested name comes back with a
profile: unresolved names return placeholder profiles with `resolved_name:
null`, zero counts, and a warning — exclude those from the comparison and say
they were not found.

### Step 5: Compare returned corpus profiles (no tool call)

For each direct bucket represented in Step 4, compute a descriptive
characterization of the returned name-keyed corpus profiles:

- **Concentration delta**: divide each exact returned category count by the sum
  of that profile's returned category counts. Identify the top 1–2 exact labels
  where either returned share exceeds the other by at least 10 percentage
  points.
- **Paper-count ratio**: collaborator-bucket total papers divided by focal total
  papers; both are name-keyed corpus counts (`compare_authors` reports every
  profile as `name_keyed`).
- **Record-activity comparison**: compare only overlapping returned timeline
  buckets and describe the observed differences; timeline buckets are record
  activity, not career chronology.

Synthesize these into a one-sentence, provenance-qualified description of
differences between the returned corpus profiles. For example:
- *"The returned collaborator bucket is more concentrated on astro-ph.GA (57%
  vs 41%) and has 2× the corpus paper count; its overlapping record-activity
  buckets contain more records in the latest returned periods."*

## Output Format

### Network Summary

A brief paragraph:
- Author name and the count of direct collaborators returned in Step 2 (a
  capped top-N result, not the total)
- The Step 1 `unique_coauthors` total only as a separate corpus-wide name count
- Primary source-specific corpus category labels returned in Step 1

### Direct Collaborators

A table of entries from Step 2 (up to 10 of the returned top-N). These are
name-matched coauthor entries, not identity-resolved people:

| Coauthor display name | Shared papers | Leading returned category |
|-----------------------|---------------|---------------------------|
| Name                  | 15            | cs.LG                     |
| ...                   | ...           | ...                       |

Take every `shared_papers` value from the focal Step 2 edge. The category column
comes from the name-keyed Step 4 comparison profile and must be qualified as
such. For entries not compared, omit the category or mark it as "—".

### Second-Degree Connections

A list of up to 10 notable second-degree name-bucket paths from Step 3. These
are buckets not returned as direct buckets and not the focal bucket; they are
not confirmed people or proof of no person-level direct relationship. Preserve
returned display names and prioritize buckets with multiple paths:

- **Coauthor display name** (paths through: Collaborator A, Collaborator B)
  — leading returned category if known

### Cross-Category Comparison

Highlight direct collaborators in the compared subset whose returned leading
category label differs from the focal profile's returned leading label:

- **Coauthor display name** (leading label: q-bio.BM)

These are differences between source-specific labels in name-keyed corpus
profiles, scoped to the compared subset. If none are found, report only that no
such difference appeared in the compared subset.

### Returned Profile Differences

For each direct bucket compared in Step 4, present the characterization computed
in Step 5. Use this format:

**Coauthor display name** (N `shared_papers` from the focal Step 2 edge)
- *Characterization*: the one-sentence, provenance-qualified description
- *Concentration delta*: differences between exact returned category labels,
  in percentage points of each profile's returned category-count total
- *Paper-count ratio*: corpus paper-count ratio with each profile's provenance
- *Record activity*: descriptive differences across overlapping returned
  timeline buckets

If the compared profiles have nearly identical returned category distributions
and timeline buckets, report that no material difference appeared in this
subset — a statement about the compared subset, not the whole network. Lead
with the strongest supported profile difference.

### Suggested Follow-ups

- Ask for a profile of `<returned coauthor name>` for an interesting
  collaborator.
- Ask for `<returned coauthor name>`'s network to explore that neighborhood.
- Ask for papers similar to `<paper_id>` for co-authored papers of interest.
