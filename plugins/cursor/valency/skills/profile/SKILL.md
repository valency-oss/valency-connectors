---
name: profile
description: "Use when the user asks about a researcher's work, publications, research areas, collaborators, or academic profile. Triggers on questions like 'who is X', 'what does X work on', 'show me X's papers', or 'tell me about X' in a research context."
---

# Researcher Profile

Build a corpus-grounded profile for the supplied author name.

## Input

The user provides an author name (e.g., "Yoshua Bengio", "Y. LeCun", "Sara Walker").

## Tool Chain

Use the Valency Bond MCP tools available in the current host. Tool names may be
qualified by an MCP server prefix; call the matching exposed tool. If the
required Valency Bond tools are unavailable, say so and stop.

Execute these steps in order.

For each call below, distinguish a tool error from a successful empty result
and surface material `warnings`.

### Step 1: Get author profile

Call `get_author_profile` with:
- `author` (string): the author name provided by the user

This returns corpus summary statistics, source-specific category labels, an
observed paper-activity timeline, and coauthor counts for the matched author-name
bucket. Label the counts with the returned `stats_source` (`orcid_keyed` means
the server unified fragmented name variants, explained in `warnings`); they are
corpus aggregates, not an identity-resolved researcher profile, and the
timeline is not publication chronology.

If no profile result is found, tell the user the author was not found and
suggest checking the spelling or trying a partial name. Stop here.

### Step 2: Get citation-ranked paper result

Call `search_by_author` with:
- `author` (string): the author name
- `limit` (integer): 10
- `sort_by` (string): "citations"
- `strict_mode` (string): "fuzzy"

This returns up to 10 corpus papers matched by the fuzzy author-name search,
ordered by the available citation data. It is not a full publication list.
Note how many returned papers have a non-null `citation_count` rather than
implying the returned order is a complete citation ranking.

### Step 3: Get research domain distribution

Call `batch_author_categories` with:
- `authors` (array of strings): a JSON array containing the author name, e.g. `["David W. Hogg"]`
- `max_categories` (integer): 10

This returns source-specific corpus category counts for the supplied author-name
bucket, not an identity-resolved researcher's complete publication distribution.

### Step 4: Get top collaborators

Call `find_coauthors` with:
- `author` (string): the author name
- `limit` (integer): 10

This returns top-N coauthor name buckets for the focal normalized-name bucket,
ranked by `shared_papers`. Display `coauthor`; use `coauthor_norm` only for
matching.

## Output Format

Present the results in this structure:

### Summary

A brief block with:
- **Name**: returned author-name bucket
- **Total papers**: corpus count from Step 1, labeled with its returned
  `stats_source`
- **Observed paper activity**: first to last returned activity date from Step 1
  (source-aware record dates, not publication years)
- **Primary domains**: top 3 returned source-specific corpus category labels
  from the name-bucket aggregation in Step 3

### Research Domains

A table of up to 5 source-specific corpus categories from the name-bucket
aggregation in Step 3:

| Category | Papers |
|----------|--------|
| cs.LG    | 42     |
| ...      | ...    |

### Top Papers

A numbered list of up to 10 papers from Step 2. For each paper show:
- Title (with paper ID)
- The source-aware date: label a non-null `first_submitted` as a
  **First-submission estimate** for arXiv, bioRxiv, or medRxiv records and a
  **Record-derived month estimate** for other sources; absent that, use
  `datestamp` labeled **Source record/update date**. Neither is a publication
  date.
- Categories

### Top Collaborators

A table of up to 5 returned coauthor name buckets from Step 4. These are the
displayed portion of a capped name-bucket result, not identity-resolved people
or a complete collaboration network:

| Coauthor display name (`coauthor`) | Shared papers (`shared_papers`) |
|------------------------------------|---------------------------------|
| Name                               | 15                              |
| ...                                | ...                             |

### Suggested Follow-ups

- Ask for `<author_name>`'s network to map their collaborators.
- Ask for papers similar to `<paper_id>` to explore a returned paper (use the
  ID of the first citation-ranked result).
