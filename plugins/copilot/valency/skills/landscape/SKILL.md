---
name: landscape
description: "Use when the user asks for an overview or landscape of a research field, what's happening in it, or who its most prolific authors are. Triggers on field summaries, top authors in a category, and field activity over time."
---

# Field Landscape

Build a scoped, evidence-backed overview of a research field or topic.

## Input routing

Classify the input before calling tools:

1. A dotted code such as `cs.LG`, `q-bio.BM`, or `astro-ph.CO` takes the arXiv-category route. This syntax recognizes arXiv codes only; pass `source: "arxiv"`.
2. A category explicitly tied to another source takes the category route with that exact category and source. Other sources use their own vocabularies, including plain-language labels, MeSH terms, and bepress disciplines.
3. Everything else takes the free-text route. Do not reinterpret free text as a category merely because it resembles one.

Categories remain source-specific lists throughout the report; they are not a shared ontology.

## Tool chain

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the tools matching the short names below. If the required Valency Bond tools are unavailable, say so and stop.
In the call templates, replace angle-bracket placeholders and omit `source` when it is unknown.

### 1. Retrieve citation-ranked anchors

For a category, call:

```json
{"category":"<category>","source":"<source when known>","limit":10,"sort_by":"citations"}
```

with `search_by_category`.

For free text, call:

```json
{"query":"<user input>","limit":10,"sort_by":"citations"}
```

with `semantic_search_papers`. This citation order applies only to the retrieved semantic candidates; it is not a corpus-wide most-cited ranking. Record the response `ranking`, warnings, and returned `count`.

A successful empty result completes this step with no anchors. Continue the independent analytics steps rather than treating it as a tool failure.

### 2. Measure record activity

For a category, call `get_publication_trends`:

```json
{"category":"<category>","source":"<source when known>","granularity":"year","format":"compact"}
```

For free text, call `get_keyword_trends`:

```json
{"query":"<user input>","granularity":"year","format":"compact"}
```

Category trends count latest records in the resolved hierarchical category. Keyword trends count records whose abstract full-text index lexically matches the query. Both group by `datestamp`, so label them **record activity**, not publication counts.

If a category response is `CATEGORY_TOO_BROAD`, show its direct-subcategory drill-downs and leave that series unavailable. For `UNKNOWN_CATEGORY`, show the warning and suggestions. Never silently substitute another category.

### 3. Measure the correct field scope

For a category, call `analyze_corpus_metrics`:

```json
{"category":"<category>","source":"<source when known>"}
```

Use `total_papers` and `date_range` only as category-scoped corpus metrics, confirming the echoed `category_filter`. Label the range as source record/update dates.

For free text, do not call unfiltered corpus metrics a field total. Use only the sum of Step 2's annual counts and label it **abstract-keyword matches in the corpus**. Step 1's `count` is returned top-N candidates, never a field total.

### 4. Identify prolific author-name aggregates

Run this step only for an arXiv category:

```json
{"category":"<category>","limit":10}
```

with `identify_prolific_authors`. Do not pass `source` with `category`: category takes precedence and the tool cannot enforce both filters. For a category explicitly tied to another source, omit this section and state that source-isolated category author ranking is unavailable.

These rows aggregate by author name, not resolved human identity. Apply `disambiguation_status` to every row:

- Present `unambiguous` normally.
- Present `mostly_single` with its candidate/fragmentation context.
- Label `ambiguous` and `unresolved` as unverified name aggregates, including the row warning and candidate evidence.
- Omit `likely_aggregation` and `severe_aggregation` from person rankings; state how many rows were excluded.

For free text, omit this section because the tool cannot produce a free-text-topic author ranking.

### 5. Add corpus category context

Call `identify_research_domains`:

```json
{"limit":10,"source":"<source when known>"}
```

Pass the category source when known. These are highest-volume categories in that source or the whole corpus, not subdomains of the requested topic. If `source` is omitted, label the result as heterogeneous corpus context and preserve each returned vocabulary/source warning.

### 6. Validate responses and finish

After every call:

- Inspect `warnings`, echoed scope, ranking, and date range. Surface anything that changes interpretation or leaves a section partial.
- Treat a true tool error as affecting only that section and continue independent sections.
- Prefer a non-null paper `url`; otherwise show the paper ID without constructing a link.
- Show the first three byline authors in order. Add “et al.” whenever more are known or `authors_truncated` is true, and report `total_authors` when supplied.
- For arXiv, bioRxiv, or medRxiv, label non-null `first_submitted` **first-submission estimate**. For every other or unknown source, label it **record-derived month estimate**. Otherwise label `datestamp` **source record/update date**. None is a publication date.
- Treat null citation counts as unavailable and qualify citation ordering whenever coverage warnings are present.

The landscape is complete when every requested section is either populated from its stated scope or explicitly marked empty, partial, or unavailable with the relevant warning.

## Output

### Field Summary

State the route and scope first. Give the category corpus total or abstract-keyword-match volume, the record/update date range available for that same scope, and the trajectory supported by Step 2. Use abstracts only when making content claims.

### Record Activity by Year

Show `Year | Matching records`. Identify the series as hierarchical-category activity or lexical abstract-keyword activity.

### Prolific Author-Name Aggregates

For category input, list the retained rows with paper count, `disambiguation_status`, candidate evidence, and material warnings. Do not call an aggregate a verified person.

### Corpus Category Context

List the source-scoped or heterogeneous corpus category ranking, its category vocabulary, paper count, and percentage. Keep it separate from the topic summary.

### Citation-Ranked Papers

Show up to five anchors. Name the panel **Category citation ranking** for category input or **Citation-ranked semantic candidates** for free text. For each paper show linked title or ID, byline head, labeled date, source when present, exact category list, and citation count when available.

### Observations

Give two or three concise observations whose wording retains category, keyword-match, semantic-candidate, or corpus-context scope — e.g. *"Matching cs.LG record activity has doubled since 2021."* Keep observations to record activity and corpus context.

### Suggested Follow-ups

- Ask for a profile of a retained author after resolving which human is intended.
- Ask for a drill-down into one returned category.
- Ask for papers similar to a listed paper ID.
