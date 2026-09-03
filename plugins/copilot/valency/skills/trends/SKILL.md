---
name: trends
description: "Use when the user asks how a research topic has changed over time, wants publication volume trends, whether its activity is growing, when it first appears in the corpus, or how category and keyword trajectories compare. Triggers on trend, growth, and timeline questions about research areas."
---

# Research Record Trends

Show how category records or abstract-keyword matches change over time.

## Input routing

Split comma- or `vs`-separated comparisons into ordered inputs. Run at most five keyword or mixed inputs per comparison — when more arrive, ask the user to choose up to five or split the comparison. A same-source category-only comparison may instead carry up to 20 categories in one batch call; when it exceeds five, retrieve representative matches for at most five user-chosen inputs — `search_by_abstract` is bounded at ten invocations per task — rather than refusing the comparison. Then classify each input:

1. Dotted codes such as `cs.LG` take the arXiv-category route with `source: "arxiv"`.
2. Categories explicitly tied to another source take the category route with that exact category and source. Other sources use source-specific vocabularies rather than arXiv-code syntax.
3. All other inputs are keywords or phrases.

Mixed category/keyword comparisons are supported.

## Tool chain

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; discover and call the tools matching the short names below. If the required Valency Bond tools are unavailable, say so and stop.
In the call templates, replace angle-bracket placeholders and omit `source` when it is unknown.

### 1. Retrieve annual trend series

For one category, call `get_publication_trends`:

```json
{"category":"<category>","source":"<source when known>","granularity":"year","format":"compact"}
```

For 2–20 categories sharing the same source, make one `get_publication_trends_batch` call:

```json
{"categories":["<category 1>","<category 2>"],"source":"<shared source when known>","granularity":"year","format":"compact"}
```
The batch tool deduplicates categories while preserving input order. For categories from different sources, group by source and use one batch call per group of at least two; use the single-category call for a group of one.

For every keyword or phrase, call `get_keyword_trends` once:

```json
{"query":"<keyword or phrase>","granularity":"year","format":"compact"}
```
When the user supplies a date window, include its `start_date` and `end_date` in every category, batch, and keyword trend call so the series share the same bound.

In a mixed comparison, route category inputs through the category calls and keyword inputs through their individual keyword calls. Category series count latest records in a resolved hierarchical category. Keyword series count records whose abstract full-text index lexically matches the query. Both are grouped by `datestamp`; neither is a formal publication-count series.

Normalize every response into one year → count series per input before comparison; batch responses carry one series per category in `data`. Record each series' scope and warnings. Sum counts only within one scoped series when a matching-record total is useful.

### 2. Resolve category partials

Inspect batch `too_broad_categories` and every entry in `data`. A `CATEGORY_TOO_BROAD` entry is an in-place drill-down, not a failed batch: show `direct_subcategories`, leave that requested series unavailable, and retain successful siblings. Surface unknown-category warnings and suggestions without substituting a category.

A successful empty series means no matching record activity in that exact scope. A true tool error affects only its input or source group; retain every independently successful series. If no series succeeds, report the errors or empty scopes and stop before interpretation.

### 3. Align periods

Convert returned annual periods to the same year keys while retaining each series label and semantics. Use an explicit user-requested date range when supplied; otherwise use the earliest through latest observed year across the non-empty successful series. Fill omitted years with zero only inside that common observed or explicit range.

For a completely empty but otherwise successful series, label it **no matching corpus records**. Show zeros only when an explicit or shared comparison range exists; without one, do not invent a first year or trajectory. Compute growth rates only between nonzero baselines.

The aligned table is complete when every requested input is represented by a scoped series, a drill-down, an empty-result label, or an error.

### 4. Retrieve representative matches in a recent record window

Compute one ISO cutoff date for the run: the user-supplied `start_date` when given, otherwise the start of the latest three observed years of the aligned Step 3 range — so a historical topic gets matches from its actual active period rather than an empty recent window — falling back to three calendar years before today when no series returned data. Then make exactly one `search_by_abstract` call per representative-match input, at most five, including `end_date` when supplied.

For a category:

```json
{"query":"<user wording or authoritative category label>","category":"<category>","source":"<source when known>","start_date":"<cutoff YYYY-MM-DD>","limit":5,"sort_by":"relevance"}
```

For a keyword:

```json
{"query":"<keyword or phrase>","start_date":"<cutoff YYYY-MM-DD>","limit":5,"sort_by":"relevance"}
```

If no authoritative human-readable category label is available, use the user's exact category input as the nonempty query rather than inventing an expansion. Skip an unresolved too-broad or unknown category until a drill-down is selected.

`start_date` filters source record/update `datestamp`. Relevance is abstract-text match strength, with any fallback disclosed by warnings; describe results as the best textual matches inside the record-date window, not as the newest papers. Keep each input's results separate rather than concatenating concepts into one search.

### 5. Validate paper metadata

For every representative-search response, inspect warnings, ranking, and the date-range echo. A successful empty result leaves only that input's panel empty; a true error leaves that panel unavailable.

Prefer a non-null `url`; otherwise show the ID without constructing a link. Show the first three byline authors and add “et al.” whenever more are known or `authors_truncated` is true; report `total_authors` when supplied. Render the returned source-specific `categories` list, or “unavailable” when empty. Dates carry the source-aware date label: for arXiv, bioRxiv, or medRxiv, non-null `first_submitted` is a **first-submission estimate**; for every other or unknown source it is a **record-derived month estimate**; otherwise `datestamp` is the **source record/update date**. None is a publication date.

## Output

### Record Activity

For one input, show `Year | Matching records`. For comparisons, show one column per input in original order. Label each column **hierarchical category records** or **lexical abstract-keyword matches**. Add a note above every mixed table that the columns use different inclusion semantics.

### Narrative

In three to five sentences, describe:

- The first observed matching record in this corpus, never the topic's invention or first publication.
- Inflection points and the current record-activity trajectory, only where the non-empty series supports them.
- For comparisons, the observed divergence in matching-record activity, preserving each column's inclusion semantics.
- Empty, partial, drill-down, and warning-qualified series that limit the comparison.

### Representative Matches in the Record-Date Window

Group up to five papers under each searched input and state the cutoff. Inputs beyond the five searched show their series only; say so rather than leaving an unexplained gap. For each, show linked title or ID, byline head, labeled date, source when present, and exact category list. State that relevance selected textual matches within the window.

### Suggested Follow-ups

- Select a returned category drill-down and rerun the trend.
- Ask for a landscape of a resolved category.
- Add a related keyword or category for another explicitly scoped comparison.
