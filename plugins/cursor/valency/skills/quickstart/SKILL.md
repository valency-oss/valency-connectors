---
name: quickstart
description: "Quickstart new Valency Bond users and people unsure how Valency fits their work."
---

# Valency Quickstart

Turn the user's research context into a practical guide for using Valency. This file is the complete workflow; execute it directly.

## 1. Recover known context

Inspect any agent memory exposed by the current host before asking questions. If none is available, continue without it. Look only for:

- the user's publishing name, ORCID, or identifying paper
- current research topics, problems, methods, and institution
- team members and existing collaborators
- research tasks or output preferences stated in the current conversation

Treat remembered details as provisional. Current user statements take precedence. Keep this workflow read-only: use memory to avoid repeated questions and retain new answers only in the current conversation.

This step is complete when identity, current work, existing network, and desired uses are each backed by current context or marked missing.

## 2. Ask one compact batch

State relevant remembered details in one sentence so the user can correct stale context. Then ask only for missing fields, in one batch:

1. **Identity:** Whose research should Valency anchor on? Accept a publishing name, ORCID, or identifying paper; a name plus ORCID is best when available. "No author profile" is valid.
2. **Current work:** What topics, problems, methods, or fields are they working on now?
3. **Existing network:** Who do they already work with, or want treated as an existing collaborator? Names, teams, and "none" are valid.
4. **Desired uses:** What should Valency help with: finding literature, following a paper, understanding a field, tracking trends, profiling or comparing researchers, mapping a network, building a reading list, finding new collaborators, exporting results, or another research task? Ask for any date, source, recency, or output constraint that matters.

Desired uses must come from the current conversation. This step is complete when all four fields have an explicit value, including "none" or "no author profile."

## 3. Choose tools internally

Use the Valency Bond MCP tools available in the current host. Tool names may carry an MCP server prefix; discover the matching exposed tools and read their live schemas before using them. If the required Valency Bond tools are unavailable, say so and stop.

The routing below is model-facing. Infer the tool plan from the user's goal; the user should describe their research need in natural language rather than choose or name tools.

Choose the smallest tool plan that satisfies the request:

| User need | Tool plan |
|---|---|
| Discover literature about a concept | Start with `semantic_search_papers`; use `search_by_title` or `search_by_abstract` when literal wording matters. |
| Follow a known paper | Resolve it with `get_paper_by_id` or `search_by_title`, then use `find_similar_papers`, `get_citing_papers`, or `get_paper_versions` according to the question. |
| Understand a researcher | Resolve with `get_author_identity`, then use `get_author_profile`, `find_papers_by_researcher`, and `find_coauthors` for the requested slices. |
| Compare researchers or map a field | Use `compare_authors` or `batch_author_categories`; use `get_keyword_trends`, `get_publication_trends`, `identify_research_domains`, `identify_prolific_authors`, or `analyze_corpus_metrics` for the requested field evidence. |
| Build a reading list | Resolve the researcher when applicable, retrieve a few representative papers, call `find_similar_papers` for each, deduplicate results, and exclude the focal researcher's own papers. |
| Find new collaborators | Resolve the focal researcher, build an exclusion set from `find_coauthors` plus user-named collaborators, derive themes from recent focal papers, search those themes with `semantic_search_papers`, and retain researchers outside the exclusion set. |
| Export a result set | Use the matching `export_papers_json`, `export_papers_csv`, `export_papers_bibtex`, or `export_from_filter` tool after the result set is settled. |

For researcher-anchored work, resolve candidates before making identity claims. Use the user's ORCID or identifying paper when available. Preserve returned paper IDs and URLs, surface warnings that qualify identity, coverage, ranking, or interpretation, and treat null metadata as unavailable rather than zero.

## 4. Teach a personal Valency playbook

Explain how Valency fits the user's work without calling tools yet. Give them:

- **Start here:** the single highest-value use case for their stated goal
- **Use Valency for:** three to five prioritized use cases, each with the input Valency needs and the result it can produce
- **Best anchors:** the names, ORCID, paper IDs, topics, collaborators, dates, and sources that will make their requests precise
- **Request frame:** `anchor + task + scope + output`, explained with their context
- **Limits that matter:** only the identity, corpus-coverage, date, citation, or metadata caveats relevant to their intended uses

Present capabilities and use cases, not tool names. Mention tool names only when the user explicitly asks how a request is implemented.

## 5. Offer tailored examples or a live demonstration

If the user has not already chosen, ask one final question: would they like three paste-ready example prompts, one live Valency demonstration, both, or neither?

For example prompts:

- use the user's real topics, identity, collaborators, and constraints
- cover distinct high-priority use cases from their playbook
- make every prompt runnable as written, without placeholders
- phrase them as natural-language research requests and choose the tools automatically

For a live demonstration, choose and execute the matching tool plan, then return a compact, evidence-backed result with identifiers, links, and material warnings. Report the research result rather than narrating internal tool selection. Use Valency results rather than model memory for literature claims.

Quickstart is complete when the user has a tailored playbook and their choice about examples or a live demonstration has been fulfilled.
