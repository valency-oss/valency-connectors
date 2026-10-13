---
name: profile
description: "Use when the user asks about a researcher's work, publications, research areas, collaborators, or academic profile. Triggers on questions like 'who is X', 'what does X work on', 'show me X's papers', or 'tell me about X' in a research context."
---

# Researcher Profile

Build a comprehensive profile for the given researcher, resolving their identity as precisely as the available information allows.

Use the Valency Bond MCP tools available in the current host. Tool names may be qualified by an MCP server prefix; call the matching exposed tool. If the required Valency Bond tools are unavailable, say so and stop. If a tool call fails with an error, retry it once before treating it as a real failure.

## Input

Required: an author name (e.g. "Yoshua Bengio", "Y. LeCun", "Sara Walker") — **or** a paper that stands in for one ("who wrote the transformer paper"). If a paper is given with no name at all, see the note at the end of Step 0b before calling `get_author_profile` — a bare `paper_id` isn't the same kind of lookup as a name search.

Optional hints — accept any of these if supplied, and actively invite them when identity is ambiguous or the name search fails:
- **ORCID** — resolves exactly, skip all disambiguation below.
- **author_id** — the corpus's own researcher ID, e.g. from a previous candidates list.
- **A specific paper** — a `paper_id`/DOI, or a title/description to resolve via Step 0b first.
- **Corpus source** ("the biomedical researcher", "the one on arxiv") — the `source` parameter.
- **Institution or affiliation**.
- **Field or subfield** ("the astronomer, not the ML person").
- **A known collaborator's name**.

A bare name is enough to attempt Step 1. But treat a supplied hint as an instruction to *use it* for resolving ambiguity, not just to note in the final output.

## Tool Chain

Execute in order.

### Step 0a — Direct identity, if available

ORCID or author_id given → skip straight to Step 1 with it. No ambiguity to resolve.

### Step 0b — Resolve a paper hint, if given

If the user gave a paper by title/description rather than an ID:

1. Call `search_by_title` (with `author`/`source` too, if either narrows it).
2. It never comes back empty — a weak keyword match silently falls back to semantic search, and fallback results can still show `relevance_score` up to 1.0. Check each result's `_source` field: `"semantic"` means the keyword search found nothing there, regardless of score; a genuine keyword hit has no `_source` field.
3. Take the first keyword hit (non-semantic) when its title matches the user's title or starts with it and no other keyword hit matches equally well; use its `id` as `paper_id`.
4. Otherwise, ask the user to confirm which paper, or for the ID/DOI directly. Don't guess.

**No title, just a description of one specific paper** (not their general field — that's a Step 1 hint, not this): one `semantic_search_papers` attempt is worth it. Trust the top result only if its `title_trgm_score` clearly leads the runner-up (roughly double, not just ahead) — `confidence`/`semantic_score` stay high regardless of match quality, so they're not usable signals. This works for a specific, less-known paper described in its own distinctive terms; it reliably fails for a famous one, since its terminology gets echoed by everything that cites it. One attempt only — if it doesn't clearly resolve, ask for a title fragment instead of iterating on the description.

**No author name given at all** ("who wrote X"): don't call `get_author_profile` with just `paper_id` and expect a clean result — a multi-author byline comes back `ambiguous` with every candidate's stats `null`, leaving nothing for Step 1's hint-match or dominance checks to work with. Answer the question first: name the paper (linked) and its byline — first few authors plus how many more. Then profile the first-listed author by calling `get_author_profile` with `author` (their name as on the byline) plus the `paper_id`, say so explicitly, and offer to switch if they meant a co-author. Skip this entirely if the paper has one author.

### Step 1 — Resolve the researcher

Call `get_author_profile` with:
- `author`: the name as given
- plus whichever of `orcid`, `author_id`, `paper_id`, or `doi` you have from Step 0a/0b
- `source`: if the user's hints clearly point to one corpus source

These stack by priority — `orcid` > `author_id` > `doi` > `paper_id` > `author` — highest supplied wins, rest ignored (except `author` narrows a `doi`/`paper_id` byline to one of its authors). Safe to pass `author` alongside a correct ID; never a conflict. The real risk is cross-turn: if the user's latest message gives different evidence — a new paper, a new name — drop any `author_id` resolved earlier before this call, or it silently outranks the new hint and re-resolves to the previous person.

`source` restricts the search itself, not just which candidates get shown — a wrong source guess can produce a false `no_match` for someone genuinely in the corpus. If a `source`-narrowed call comes back `no_match` or with a suspiciously small corpus count, retry once without `source` before concluding the name isn't there. It also narrows `corpus.*` figures only, never `career.*`.

Branch on the response's `status`. There are five possible values, not three — two look similar but need different handling:

**`not_found`** — Only occurs when you supplied an `orcid`/`author_id`/`doi`/`paper_id` and it didn't resolve (stale or mistyped). Tell the user that identifier didn't match anything, and fall back to resolving by name.

**`no_match`** — A plain name search found nothing, and the corpus couldn't generate near-miss suggestions either. Tell the user the name wasn't found; suggest a partial name, an ORCID, or a known paper. Exception: with `author` + `paper_id`/`doi`, `no_match` plus a non-empty `candidates[]` means the paper resolved but the name isn't on its byline — the candidates are that byline. Say so, and ask whether the paper or the name is off (show the byline names if a variant spelling might be the person).

**`did_you_mean`** — Name search found nothing, but `suggestions[]` gives near-miss surnames with similarity scores and paper counts. Show the top few and offer to retry with a corrected name — more helpful than a bare "not found," use it whenever available.

**`ambiguous`** — The common case for anything but a distinctive name. Don't skip it and don't silently proceed with the bare name into later steps. `candidates[]` (often 10–15; `candidates_truncated: true` means more exist than shown. Each has `author_id`, `orcid`, `corpus_papers`, `works_count`, `active_years`, `top_categories`, `recent_title`, `match`) plus a `warnings[]` note on total match count. A candidate with `corpus_papers`/`match` as `null` doesn't mean no papers — just that stats weren't computed for a lower-ranked entry; don't dismiss it on that basis. Work through this before anything else:

1. **Check if a hint already picks a winner.** A paper hint (Step 0b): a candidate whose corpus contains it, or whose `recent_title`/field matches, is your answer — use its `author_id`, no need to ask. A field/institution hint: check against `top_categories`; if that doesn't cleanly discriminate and the hint is institutional, it's fine to resolve the top 2-3 candidates individually and check `career.affiliations`.

   **If none of the shown candidates match the hint at all**, don't force-fit one or give up — re-call with a `source` matching the hint (physics/CS → arxiv, biomedical → pubmed). `source` changes which population gets ranked, so the right person can surface in a filtered list despite never appearing in the unfiltered top 10. If more than one same-field candidate turns up in that filtered list, match the hint's specific content against `recent_title`, not just the shared field label — two candidates can share a field while working on entirely different things.

2. **No hint? Look for an obvious winner anyway.** A candidate with `corpus_papers` several times the runner-up, and no comparable-size candidate in another field, is usually the intended person — use it, but say so explicitly as a judgment call ("I'm using the corpus's dominant match — let me know if you meant someone else"). Don't auto-pick when the top candidates are within ~2x of each other (the norm for common names) — unless the user's exact spelling (hyphens, initials, accents) matches only one candidate's `display_name` and the others are in unrelated fields; then pick it, as a disclosed judgment call. When computing this ratio, skip any candidate you separately recognize as a likely same-person fragment (item 5) — comparing against your own fragment to argue dominance is circular; compare against the next genuinely different candidate instead, even if the ratio looks less dramatic.
3. **Otherwise, ask the user.** Present candidates compactly — name, ORCID (linked, truncated display: `...1430-1360` → `https://orcid.org/<full id>`), corpus papers, active years, top categories, most recent title as plain unlinked text — and ask which one. Mention that a paper, institution, ORCID, or field would narrow it further, especially since the list is capped and a common name may have far more matches than shown. If disambiguating from a paper's byline rather than a name search, candidates have no corpus stats — list names/ORCIDs only, don't show null fields as real data.
4. Once a candidate is chosen (by you or the user), re-call `get_author_profile` with `author_id` set to it and continue.
5. **Optional: surface a same-person fragment — only if it's already free.** If the `candidates[]` you already saw includes another small, same-subfield entry that's clearly the same person under a name variant (not just a coincidentally-similar different person — genuinely harder to rule out), fetch its `find_papers_by_researcher`/`find_coauthors` and show the result as a separate, labeled addendum ("also published under [variant]: [papers]") — never blend its numbers into the primary totals. The flagging warning says "not ruled in or out," not confirmed identical; merging would trade a disclosed undercount for an undisclosed overcount. Only applies when the fragment's `author_id` was already in that same `candidates[]` array — don't launch a fresh search just because a `resolved` profile's own warning mentions a variant might exist. If multiple fragments look plausible, fetch only the largest; name the rest without fetching them.

**`resolved`** — Continue to Step 2. Read `warnings[]`:
- Near-duplicate name variants excluded (e.g. "Y. Bengio") → one-line mention; counts are a slight undercount.
- "Affiliations across N distinct countries… may belong to more than one person" → a possible over-merge. One-line caveat in Summary, and say in Top Papers that some listed papers may belong to namesakes in the same field (which the misattribution scan can't catch); flag any that clearly don't fit their work.
- "Some of this researcher's records could not be classified…" → routine on almost every profile; don't mention it.

**Sanity-check a paper-resolved identity.** If you resolved through `paper_id`/`doi` (`byline_confirmed: true`) but got a tiny corpus (single digits) with scattered, unrelated `top_categories` or the multi-country warning, the paper's byline points at a thin upstream stub — common for very recent papers — not the person's real record. Don't present it as their profile. Re-call with the name alone and match the hint (field, institution, coauthors from that paper) against `candidates[]` per the `ambiguous` steps above, telling the user why in one line.

`person.author_id` may be in a different format from the candidate ID you passed (e.g. `A_…` vs `A5…`), and the resolved profile's figures can differ from that candidate's list-row figures, sometimes by a lot. Both are expected: use the resolved `person.author_id` and the resolved figures from here on.

Either way, use the confirmed `author_id` — not the raw name — for every remaining step. `search_by_author`/`batch_author_categories` do no identity resolution and will blend in other people's papers even after all this disambiguation work.

### Step 2 — Get top papers

Call `find_papers_by_researcher` with `author_id` (resolved ID), `sort_by: "citations"`, `limit: 25`. The sort covers the researcher's whole corpus, so the top 10 are right at any limit; the extra 15 just give the misattribution scan in Top Papers something to work with. Display the top 10.

Identity-aware (unlike `search_by_author`) — returns only this person's papers.

### Step 3 — Research domains

Skip a separate categories call — `get_author_profile`'s own `corpus.top_categories` (Step 1) already covers this, and more accurately than `batch_author_categories` would: that tool matches by exact name string and can pull in a different person's papers even for an otherwise-resolved name.

### Step 4 — Top collaborators

Call `find_coauthors` with `author_id` (resolved ID) and `limit: 10`. Passing `author_id` means this step can't independently land back in `ambiguous` — that only happens with a bare name.

### Retry-once, on any error, or on an unavailable "did you mean"

`get_author_profile`, `find_coauthors`, `find_papers_by_researcher`, and comparison calls can fail on first attempt for large or high-match requests, then succeed on retry — sometimes as `REQUEST_TIMEOUT`, sometimes as a plain connector error with no timeout involved. Retry once on any error from these calls, not just the `REQUEST_TIMEOUT` code specifically, before treating it as a real failure.

Separately, a `no_match`/`did_you_mean` response can note that near-miss suggestions "were unavailable." Retry once — sometimes that resolves it, sometimes it doesn't (a genuine one-character typo stayed unavailable twice in testing). If still unavailable after one retry, stop: tell the user the name wasn't found and ask for a partial name, ORCID, or known paper — that failure is upstream, not something more retries fix.

## Output Format

Every caveat below is a known, already-diagnosed data characteristic — not something to sound puzzled by. State it as fact, say what to trust instead, in one line, and move on: *"citation counts below can undercount older papers due to an upstream data-linkage issue — the h-index above is the more reliable signal"* helps; *"something seems off here"* doesn't. You already know why; say so.

Stop at Suggested Follow-ups — never append a closing note about the skill's own execution (call counts, retries, which parameter "mattered"), clean run or rough. This doesn't relax the rule above: the line is the researcher vs. the tool chain, not good news vs. bad. A caveat about trusting a number (an undercount, a cap, an unconfirmed pick) is content and belongs in the answer; a detail about how the answer was assembled is plumbing and never does.

Link every paper title you name (Top Papers, the fragment addendum, a flagged misattribution) to its own `url` field — every `find_papers_by_researcher`/`search_by_title` paper object carries one. Keep the paper ID visible in parentheses too, since Suggested Follow-ups references it.

Exception: the ambiguous-candidates table (item 3 above). Those candidates only carry `recent_paper_id`/`recent_source`, no real `url` — hand-building one risks the wrong template for a less-common source (bioRxiv/medRxiv use DOI-based URLs, unlike arXiv/PubMed) — and a long linked title reads badly in a narrow table cell regardless. Keep that column short, plain, unlinked. ORCID is different: it always resolves to the same template (`https://orcid.org/<id>`), so it stays a link — just truncate the *display* text (`...1430-1360`) rather than showing the full string, which wraps badly. The `orcid` field comes back either bare (`0000-…`) or already as a full URL, inconsistently even for the same person — strip any `https://orcid.org/` prefix before building the link so it isn't doubled.

### Summary
- **Name**: `person.display_name`
- **ORCID**: if present, linked (normalized as above)
- **Institution**: top entry from `career.affiliations` by `work_count`. Don't present `current_institution` as where they are now — it is often stale.
- **Total papers**: `corpus.corpus_papers` (mention `career.career_works` if notably larger)
- **Career impact**: `career.h_index` and `career.career_citations`. If `h_index` is null, show citations only — don't remark on the missing h-index.
- **Active years**: from the earlier of `corpus.first_paper` and the oldest paper year in Step 2, to `corpus.last_paper` (`first_paper` follows record dates and can start years too late).
- **Primary domains**: top 3 from `corpus.top_categories`
- If identity was ambiguous and you picked a candidate yourself, say so here in one line.
- If `corpus.papers_per_year` has one sharp, plausibly-caused spike (a project launch, a mega-collaboration paper), a one-line text mention belongs here; a fuller visual treatment belongs after Top Papers instead.

### Research Domains
Table of top 5 from `corpus.top_categories`.

### Top Papers
Numbered list of up to 10 papers from Step 2: title linked per above (plus ID in parentheses), year, categories, citation count. **Year:** the year in `journal_ref` when present, else `first_submitted` — for PubMed rows `first_submitted` is often a record-update date, so with no `journal_ref` leave the year off. **Categories:** arXiv codes only; PubMed `categories` are free keywords — omit them. If most of the top 10 have `total_authors` > 50, add one line: the list reflects large-collaboration membership more than their own lead work.

The ranking is reliable; an individual paper's own count may not be. If `h_index` is present, check the list against it and `career.career_citations`; if the numbers look small for that h-index (a known failure mode: citations split across duplicate upstream records, with the corpus linked to the lower-cited one), say so rather than presenting the ranking as the definitive greatest hits — the person-level aggregate is the more trustworthy signal.

Scan all fetched papers, not just the displayed 10, for a paper from a different discipline entirely (a lone materials-science paper in an all-astrophysics career — not a methods, software or science-policy paper, which people genuinely write outside their field) — that's a likely misattribution from someone else, not a real outside interest. Flag it rather than presenting it as their work.

### Publication Trajectory (optional)
If a charting tool is available and the active span is long enough to show a real trajectory (double-digit years, not 2-3), render `corpus.papers_per_year` as a bar or line chart here — a slow ramp, a plateau, a late surge often says more than the single spike mentioned in Summary. Skip it for a short career; four nonzero years isn't worth a widget. Call the chart tool only after writing the Summary and Top Papers text: tool calls render where they're actually called, not where this instruction sits, so calling it early puts the chart at the top instead of here.

### Top Collaborators
Table of up to 5 from Step 4: name, shared papers. Each row carries a `coauthor_id` you don't display — enriching every row (ORCID, affiliation) would cost one extra call per collaborator, and that's the network skill's job, not this skill's. Hold onto the `coauthor_id` instead: if the user later asks about a named collaborator, resolve them with that ID directly rather than a fresh, possibly-ambiguous name search — you already have their exact identity.

### Also Published As [name variant] (conditional)
Only if Step 1's item 5 surfaced and fetched a fragment. Up to 5 of its papers (linked title, year, citations), plus a shared coauthor or two if notable — kept short; the point is visibility, not a second profile. State plainly these figures sit outside the totals above.

### Suggested Follow-ups
- Ask for the network of `<author_name>` — map their collaboration network
- Ask for papers similar to `<paper_id>` — find papers similar to their top work
