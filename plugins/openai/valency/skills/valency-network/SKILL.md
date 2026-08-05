---
name: valency-network
description: "Use when the user asks about a researcher's collaborators, co-authors, research network, wants to map who works with whom, or wants to see how a researcher's focus has diverged from their collaborators. Triggers on questions like 'who does X collaborate with', 'show me X's network', 'find connections between researchers', or 'how has X's work drifted from their coauthors'."
---

# Collaboration Network

Map a researcher's collaboration network using the Valency research corpus.

## Tool conventions

- Use the Valency Bond MCP tools available in the current agent (e.g., `find_coauthors`). Tool names may be qualified with an MCP server prefix; call the matching exposed tool.
- Never fabricate paper titles, authors, abstracts, or metadata. All data must come from tool results.
- If a tool returns no results, say so plainly and suggest a different spelling or query.
- Produce clean, scannable output with consistent markdown formatting.

## Input

The user provides an author name (e.g., "Yoshua Bengio").

## Tool chain

### Step 1: Get author baseline

Call `get_author_profile` with:
- `author` (string): the author name

If no results are found, tell the user the author was not found and suggest checking the spelling. Stop here.

Note the author's top categories from this result — you'll need them to identify cross-domain bridges.

### Step 2: Get direct collaborators

Call `find_coauthors` with:
- `author` (string): the author name
- `limit` (integer): 20

This returns collaborators ranked by co-publication count. Note the top 5 collaborators for the next step. Use the `coauthor_norm` field (normalized name) when passing names to subsequent tool calls.

### Step 3: Get second-degree connections

For each of the top 5 collaborators from Step 2, call `find_coauthors` with:
- `author` (string): the collaborator's normalized name (`coauthor_norm`)
- `limit` (integer): 10

Collect all second-degree collaborators. Remove any that are already direct collaborators of the focal author (from Step 2) or the focal author themselves.

### Step 4: Compare focal author with top collaborators

Call `compare_authors` with:
- `authors` (array of strings): a JSON array containing the focal author name and up to 4 of their top collaborators (max 5 total, tool requires 2-10), e.g. `["Yoshua Bengio", "Ian Goodfellow", "Aaron Courville"]`

This returns side-by-side profiles with category overlap information. The result also gives you everything you need to compute divergence: each author's category distribution as a list of `{category, count}` pairs, plus a `shared_categories` array.

### Step 5: Compute divergence (no tool call)

For each top collaborator from Step 4, compute a **divergence characterization** from the `compare_authors` result. For each collaborator, determine:

- **Concentration delta**: convert each author's category counts to percentages of their total, then identify the top 1–2 categories where the collaborator's percentage exceeds the focal author's by ≥ 10 percentage points (collaborator is *more concentrated* there) and the top 1–2 categories where the focal author's percentage exceeds the collaborator's by ≥ 10 points (focal author is *more concentrated* there).
- **Productivity ratio**: collaborator's total papers ÷ focal author's total papers. Note when this is dramatically above (>2x) or below (<0.5x) parity.
- **Career-phase signal**: compare the publication timelines. Note when the collaborator's output has accelerated, decelerated, or shifted (pivoted to a new dominant category) relative to the focal author over the last 3 years.

Synthesize these into a one-sentence characterization per collaborator. Examples:
- *"More concentrated on astro-ph.GA (57% vs 41%); 2× the productivity; output accelerating in the Gaia era while focal author's has held steady."*
- *"Pivoted toward cs.CL after 2022; less methodological output than focal author; collaboration appears to have cooled since the pivot."*

## Output format

### Network summary

A brief paragraph:
- Author name and total direct collaborators count
- Primary research domains (from Step 1)

### Direct collaborators

A table of collaborators from Step 2 (top 10):

| Collaborator | Co-authored papers | Primary domain |
|--------------|-------------------|----------------|
| Name         | 15                | cs.LG          |
| ...          | ...               | ...            |

The "Primary domain" column comes from Step 4 comparison data for the top collaborators. For collaborators not included in the comparison, omit the domain or mark as "—".

### Second-degree connections

A list of notable second-degree connections from Step 3 — people who collaborate with the focal author's collaborators but not directly with the focal author. Show up to 10, prioritizing those who appear via multiple collaborators:

- **Name** (connected through: Collaborator A, Collaborator B) — primary domain if known

### Cross-domain bridges

Highlight collaborators from Step 2 whose primary domain (from Step 4) differs from the focal author's primary domain. These represent interdisciplinary connections:

- **Name** (domain: q-bio.BM) — bridges to computational biology

If no cross-domain collaborators are found, note that the author's network is concentrated within their primary domain.

### Divergence analysis

For each top collaborator compared in Step 4, present the divergence characterization computed in Step 5. Use this format:

**Collaborator Name** (N shared papers)
- *Characterization*: the one-sentence synthesis from Step 5
- *Concentration delta*: which categories each is more concentrated in (numbers in percentage points)
- *Productivity*: papers ratio vs focal author
- *Trajectory*: career-phase signal over the last ~3 years

If all top collaborators have nearly-identical category distributions and timelines, note that the network is intellectually homogeneous and divergence analysis is uninformative — but still show the table for completeness.

The point of this section is to make visible *how the focal author's intellectual position has drifted relative to their closest collaborators*. Lead with the most divergent collaborator, not the most-collaborated-with one.

### Suggested follow-ups

- "Profile `<collaborator>`" — for any interesting collaborator
- "Network for `<collaborator>`" — to explore a collaborator's own network
- "Papers similar to `<paper_id>`" — for co-authored papers of interest
