---
name: network
description: "Use when the user asks about a researcher's collaborators, co-authors, research network, wants to map who works with whom, or wants to see how a researcher's focus has diverged from their collaborators. Triggers on questions like 'who does X collaborate with', 'show me X's network', 'find connections between researchers', or 'how has X's work drifted from their coauthors'. Also invokable as /valency:network <author_name>."
---

# Collaboration Network

Map a researcher's collaboration network.

## Input

The user provides an author name (e.g., "Yoshua Bengio").

## Tool Chain

### Step 1: Get author baseline

Call `get_author_profile` with:
- `author` (string): the author name

If no results are found, tell the user the author was not found and suggest checking the spelling. Stop here.

Store the returned `resolved_name` and use it for every subsequent focal-author call and identity comparison. Note the author's top categories from this result — you'll need them to identify cross-domain bridges.

### Step 2: Get direct collaborators

Call `find_coauthors` with:
- `author` (string): the `resolved_name` from Step 1
- `limit` (integer): 100

This returns up to the maximum 100 collaborators ranked by co-publication count. Use the full returned set to exclude known direct collaborators in Step 3. Note the top 5 collaborators for subsequent searches and comparisons. Retain each collaborator's stable author identifier when returned; `coauthor_norm` is only a fallback lookup hint, not proof of identity.

### Step 3: Get second-degree connections

For each of the top 5 collaborators from Step 2, first establish an unambiguous lookup identity. Pass the collaborator's stable author identifier when the tool's `author` field accepts it. Otherwise, resolve `coauthor_norm` with `get_author_profile` and verify that the returned identity matches the Step 2 collaborator using a returned stable identifier or other available identity metadata. If a name-only lookup has multiple plausible matches or cannot be verified, skip that collaborator and disclose the ambiguity rather than traversing a potentially different person's network.

For each verified collaborator, call `find_coauthors` with:
- `author` (string): the stable identifier when supported, otherwise the verified `resolved_name`
- `limit` (integer): 10

Collect second-degree candidates in a map keyed by stable author identifier whenever available, otherwise by a server-resolved canonical identity. Record which direct collaborator's search found each identity. Use a normalized name only as a fallback lookup hint: if two records share a name but lack evidence that they are the same person, keep them separate and do not count them as one multi-collaborator connection. Remove identities that appear in the focal author's returned top-100 coauthor set (from Step 2) or resolve to the focal author. Do not claim that remaining candidates have never collaborated directly; they are only unobserved in the capped top-100 set.

### Step 4: Compare focal author with top collaborators

Call `compare_authors` with:
- `authors` (array of strings): a JSON array containing the focal author's `resolved_name` and up to 4 unambiguously resolved collaborator identities from Step 3 (max 5 total, tool requires 2-10), e.g. `["Yoshua Bengio", "Ian Goodfellow", "Aaron Courville"]`. Use stable identifiers when accepted; otherwise use each verified `resolved_name`.

Only call `compare_authors` when Step 3 produced at least one unambiguously resolved collaborator, so the array contains at least two authors. If all collaborators were skipped as ambiguous, skip Steps 4 and 5 and omit comparison-dependent output sections.

This returns side-by-side profiles with category overlap information. The result also gives you everything you need to compute divergence: each author's category distribution as a list of `{category, count}` pairs, plus a `shared_categories` array.

### Step 5: Compute divergence (no tool call)

For each top collaborator from Step 4, compute a **divergence characterization** from the `compare_authors` result. For each collaborator, determine:

- **Concentration delta**: convert each author's category counts to percentages of their total, then identify the top 1–2 categories where the collaborator's percentage exceeds the focal author's by ≥ 10 percentage points (collaborator is *more concentrated* there) and the top 1–2 categories where the focal author's percentage exceeds the collaborator's by ≥ 10 points (focal author is *more concentrated* there).
- **Productivity ratio**: collaborator's total papers ÷ focal author's total papers. Note when this is dramatically above (>2x) or below (<0.5x) parity.
- **Career-phase signal**: compare the overall publication timelines. Note only whether each author's total output has accelerated or decelerated relative to the other over the last 3 completed years. Do not claim a category pivot or that a collaboration cooled without time-resolved category or shared-publication data.

Synthesize these into a one-sentence characterization per collaborator. Examples:
- *"More concentrated on astro-ph.GA (57% vs 41%); 2× the productivity; output accelerating in the Gaia era while focal author's has held steady."*
- *"Overall publication output accelerated over the last 3 completed years while the focal author's held steady; category timing and collaboration timing are not available."*

## Output Format

### Network Summary

A brief paragraph:
- Author name and total direct collaborators count
- Primary research domains (from Step 1)

### Direct Collaborators

A table of collaborators from Step 2 (top 10):

| Collaborator | Co-authored papers | Primary domain |
|--------------|-------------------|----------------|
| Name         | 15                | cs.LG          |
| ...          | ...               | ...            |

The "Primary domain" column comes from Step 4 comparison data for the top collaborators. For collaborators not included in the comparison, omit the domain or mark as "—".

### Second-Degree Connections

A list of notable second-degree candidates from Step 3 — people who collaborate with the focal author's collaborators and do not appear in the focal author's top-100 coauthor set. Show up to 10, prioritizing those who appear via multiple collaborators:

- **Name** (connected through: Collaborator A, Collaborator B) — primary domain if known

### Cross-Domain Bridges

Highlight collaborators from Step 2 whose primary domain (from Step 4) differs from the focal author's primary domain. These represent interdisciplinary connections:

- **Name** (domain: q-bio.BM) — bridges to computational biology

If no cross-domain collaborators are found among the Step 4 comparison set, note only that the **compared collaborators** are concentrated within the focal author's primary domain. Do not generalize this result to collaborators whose domains were not retrieved.

### Divergence Analysis

For each top collaborator compared in Step 4, present the divergence characterization computed in Step 5. Use this format:

**Collaborator Name** (N shared papers)
- *Characterization*: the one-sentence synthesis from Step 5
- *Concentration delta*: which categories each is more concentrated in (numbers in percentage points)
- *Productivity*: papers ratio vs focal author
- *Trajectory*: career-phase signal over the last ~3 years

If all collaborators in the Step 4 comparison subset have nearly identical category distributions and timelines, note that the **compared subset** is intellectually homogeneous and its differentiation analysis is uninformative — but still show the table for completeness. Do not generalize this result to the full network.

The point of this section is to make visible *how the focal author's current intellectual position differs from their closest collaborators*. Lead with the most differentiated collaborator, not the most-collaborated-with one. Do not describe static category differences as temporal drift.

### Suggested Follow-ups

- `/valency:profile <collaborator>` — for any interesting collaborator
- `/valency:network <collaborator>` — to explore a collaborator's own network
- `/valency:similar <paper_id>` — for co-authored papers of interest
