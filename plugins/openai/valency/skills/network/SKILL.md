---
name: network
description: "Use when the user asks about a researcher's collaborators, co-authors, research network, wants to map who works with whom, or wants to see how a researcher's focus has diverged from their collaborators. Triggers on questions like 'who does X collaborate with', 'show me X's network', 'find connections between researchers', or 'how has X's work drifted from their coauthors'."
---

# Collaboration Network

Map a researcher's direct collaborators, the people one step further out, and how their closest collaborators' work compares with theirs.

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop. If a tool call fails with an error, retry it once before treating it as a real failure.

## Input

An author name, or an ORCID / author_id / known paper if the name alone is ambiguous.

## Tool Chain

### Step 1: Resolve the researcher

Call `get_author_profile` with `author` (plus any hint). Branch on `status`:
- `not_found` / `no_match` / `name_only` → say so, ask for an ORCID or a known paper. Stop.
- `did_you_mean` → show the suggestions, offer to retry. Stop.
- `ambiguous` → pick a candidate only if its `corpus_papers` is several times the next *genuinely different* candidate (a small same-field entry with the same name is likely a fragment of the same person), and say it's a judgment call. Otherwise list the candidates (name, ORCID, papers, top fields, latest title) and ask. Once picked, re-call with that `author_id`.
- `resolved` → keep `person.author_id`, `person.display_name`, `corpus.corpus_papers`, `corpus.top_categories`.

If a response carries `degraded: true` (`next_action: "retry_unchanged"`), part of it was skipped, not empty: retry that call once unchanged, and if it is still degraded, say that part is unavailable rather than reporting zero.

### Step 2: Direct collaborators

Call `find_coauthors` with `author_id`, `limit: 100`. Every row counts as a direct collaborator in Step 3; the output shows the top 10. Rows are `{coauthor, coauthor_id, shared_papers}`. `count` is rows returned, not a network total. If no rows come back, give the Network Summary, say no collaborators were found, and skip Steps 3–5.

The same person can appear twice (two records, e.g. "Robert M. Califf" and "Robert Califf"). Merge rows whose names match (surname plus given name, or first initial when one side has only initials; ignore case, accents, apostrophes and every hyphen variant, e.g. "Hans‐Walter" with a Unicode hyphen vs "Hans-Walter"). Merge only when the names clearly match, since the rows carry no field to confirm it; when unsure, keep them separate. Keep the larger shared-paper count (the two can overlap, so don't add them) and note the merge. Then take the top 5 (ties: keep the tool's order).

Note the warning's count of excluded >50-author papers. If it's more than about a third of `corpus.corpus_papers`, the researcher's profile is dominated by large-collaboration papers — Step 5's focus, output and trajectory comparisons would mostly measure that, so skip Step 4–5 and the Divergence section, and say why in one line.

### Step 3: Second-degree connections

For each of the top 5, call `find_coauthors` with `author_id` = their `coauthor_id`, `limit: 10`. Drop from these lists: the researcher (they appear under a different ID form — `A5…` here vs `A_…` from Step 1 — so match by name), anyone in Step 2's full list (all rows, not just the top 5), and duplicates of the same person. Count, for each remaining person, how many of the top 5 lead to them; merge the two records of any person merged in Step 2 before counting.

### Step 4: Compare

Call `compare_authors` with `authors`: `{author_id: …}` objects for the researcher plus the top 4 collaborators. `profiles[]` comes back in input order; match each by its `author` field (it echoes the ID you sent).

### Step 5: Divergence (no tool call)

For each compared collaborator, from their profile vs the researcher's:
- **Focus:** only when `top_categories` are arXiv codes. Convert counts to shares of `corpus_papers`, ignore legacy catch-alls (`astro-ph`, `cond-mat`, `hep` without a subcategory — they reflect older papers, not focus), and name the 1–2 categories where the shares differ by ≥10 points. If a category is missing from one profile's top list, say "not in their top categories" rather than inventing a share. For PubMed-heavy researchers, `top_categories` are fine-grained keywords covering a small share of papers — skip this comparison and say so in one line.
- **Output:** collaborator's `corpus_papers` ÷ the researcher's; mention if > 2× or < 0.5×.
- **Trajectory:** from `papers_per_year`, rising / steady / falling over the last 3 complete years (exclude the current year).

One sentence per collaborator, e.g. *"More concentrated on astro-ph.GA (57% vs 41%); twice the output; output rising."*

**Only state what the tool results show.** Don't characterize people (their speciality, career moves, era) from outside knowledge.

## Output Format

### Network Summary
Name, main fields, how many collaborators are shown. If Step 2 said >50-author papers were excluded, say so in one line (large collaborations are left out of these counts). Note any merged duplicate records.

### Direct Collaborators
Top 10 from Step 2: name, shared papers.

### Second-Degree Connections
Up to 10: those reached through more than one collaborator first, then the rest by shared papers with the collaborator who leads to them, spread across the top 5. **Name** — via Collaborator A, Collaborator B.

### Divergence
Lead with the most divergent compared collaborator. The one-sentence summary, then focus, output and trajectory.

### Suggested Follow-ups
- Ask for a profile of `<collaborator>` — a closer look at any collaborator
- Ask for the network of `<collaborator>` — their own network
