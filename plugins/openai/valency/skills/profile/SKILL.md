---
name: profile
description: "Use when the user asks about a researcher's work, publications, research areas, collaborators, or academic profile. Triggers on questions like 'who is X', 'what does X work on', 'show me X's papers', or 'tell me about X' in a research context."
---

# Researcher Profile

Build a comprehensive profile for the given researcher.

## Input

The user provides an author name (e.g., "Yoshua Bengio", "Y. LeCun", "Sara Walker").

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

Execute these steps in order.

For each call below, distinguish a tool error from a successful empty result,
read and report material `warnings`, and, when `_meta.limit_clamped` is present,
report its `requested`, `effective`, and `max` values rather than claiming the
requested limit was searched.

### Step 1: Resolve the author

Call `get_author_identity` with:
- `author` (string): the author name provided by the user

If `candidates` are returned, ask the user to select one before continuing. If
the identity is unverifiable or not found, say so and stop. Carry forward the
selected canonical display name, `resolved_name`, and ORCID when returned.

### Step 2: Get author profile

Call `get_author_profile` with:
- `author` (string): the selected canonical display name
- `orcid` (string, when returned by Step 1): the resolved ORCID

Read `resolved_name`, `summary`, `categories`, `timeline`, `stats_source`, and
warnings. `orcid_keyed` statistics are identity-linked; `name_keyed` statistics
are aggregates for the resolved-name bucket. Categories are returned
source-specific corpus labels. The first/last paper values and timeline
describe observed corpus paper activity, not publication chronology.

### Step 3: Get citation-ranked papers

Call `find_papers_by_researcher` with:
- `orcid` (string): the resolved ORCID, when Step 1 returned one
- otherwise `author` (string): the selected canonical display name
- `limit` (integer): 10
- `sort_by` (string): `"citations"`

This returns up to 10 identity-attributed, citation-ranked corpus papers. Check
`candidates`, `disambiguation_status`, `returned_count`, each paper's
`match_type`, and warnings. Citations are nullable enrichment: report citation
coverage as X/Y returned papers and preserve ranking warnings rather than
claiming every returned paper has a citation count. A successful empty paper
list is a valid empty result, not evidence that the selected author does not
exist.

### Step 4: Get top collaborators

Call `find_coauthors` with:
- `author` (string): the profile's `resolved_name`
- `limit` (integer): 10

This returns top-N coauthor name buckets for the focal normalized-name bucket,
ranked by `shared_papers`. Display `coauthor`; use `coauthor_norm` only as the
matching key. A successful empty `coauthors` list is valid.

## Output Format

Present the results in this structure:

### Summary

A brief block with:
- **Name**: the selected canonical display name
- **Total papers**: corpus `summary.total_papers`, with `stats_source`
- **Observed paper activity**: `summary.first_paper` to `summary.last_paper`,
  explicitly not publication years
- **Primary domains**: up to 3 returned source-specific labels from profile
  `categories`

### Research Domains

A table of up to 5 source-specific corpus categories and their returned paper
counts from the profile:

| Category | Papers |
|----------|--------|
| cs.LG    | 42     |
| ...      | ...    |

### Top Papers

A numbered list of up to 10 papers from Step 3. For each paper show:
- Title (with paper ID)
- Record activity date: for arXiv, bioRxiv, or medRxiv records, label a
  non-null `first_submitted` as a **First-submission estimate**; for other
  sources, label it a **Record-derived month estimate**. If it is absent, use
  `datestamp` labeled **Source record/update date**. Preserve null values rather
  than inventing a year.
- Categories

### Top Collaborators

A table of up to 5 coauthor name buckets from Step 4. These are name-bucket
edges, not identity-resolved people or a complete collaboration network:

| Coauthor name bucket | Shared papers |
|--------------|-------------------|
| Name         | 15                |
| ...          | ...               |

### Suggested Follow-ups

- Ask for `<author_name>`'s network to map their collaborators.
- Ask for papers similar to `<paper_id>` to explore a returned paper.
