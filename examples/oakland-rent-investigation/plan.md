# West Oakland Rent Investigation - Research & Drafting Plan

> **For Claude:** REQUIRED SUB-SKILL: Use narrative:evidence-driven-drafting to implement this plan task-by-task.

**Investigation Goal:** Trace financial flows behind West Oakland rent spikes

**Narrative Approach:** Hybrid investigation (personal entry, systemic analysis)

**Key Actors:** REITs, Delaware LLCs, displaced tenants, organizers

**Ethical Considerations:** Protect vulnerable people, center Black resident voices, acknowledge resistance

---

## Task 1: Baseline Rent Data Research

**Resources:**
- Search: "West Oakland median rent 2019-2023 Zillow Census"
- Documents: `writing/source-notes/rent-data.md`

**Step 1: Research rent trends**

WebSearch: "West Oakland Oakland CA median rent 2019 2020 2021 2022 2023 Zillow rental index"
Expected: Time series data showing increases

**Step 2: Document findings with sources**

Create: `writing/source-notes/rent-data.md`

```markdown
## West Oakland Rent Trends 2019-2023

**Source:** Zillow Observed Rent Index (ZORI), West Oakland zip code 94607
**URL:** [Zillow data portal]
**Date accessed:** 2024-01-15

**Key findings:**
- 2019 median: $1,842/month
- 2020 median: $1,791/month (slight decrease during pandemic)
- 2021 median: $2,107/month (+17.6% year-over-year)
- 2022 median: $2,456/month (+16.6% year-over-year)
- 2023 median: $2,512/month (+2.3% year-over-year)

**Total increase 2020-2022:** 37.1%

**Confidence:** High (authoritative source, publicly available)

**Follow-up:** Compare to Oakland citywide and Bay Area regional trends to assess if West Oakland spike was anomalous
```

**Step 3: Fact-check claims**

Review checklist:
- [x] Source cited with URL and date accessed
- [x] Figures match source data
- [x] Percentage calculations verified
- [x] Context noted (comparison to broader trends)

**Step 4: Save with methodology note**

```bash
git add writing/source-notes/rent-data.md
git commit -m "research: document West Oakland rent trends 2019-2023"
```

---

## Task 2: Property Ownership Records

**Resources:**
- Search: Alameda County Assessor property records
- Documents: `writing/source-notes/property-ownership.md`

**Step 1: Research Telegraph Ave properties**

[Dispatch Archivist agent]

**Prompt:**
You are an Archivist researching property ownership in West Oakland.

**Task:** Find ownership records for buildings on Telegraph Avenue between 40th St and 52nd St that experienced evictions in 2021-2022.

**Sources:** Alameda County Assessor's Office public records (search by address or parcel ID)

**Output:** Create `writing/source-notes/property-ownership.md` with:
- Property addresses
- Parcel IDs
- Current owner names
- Purchase dates and amounts
- Previous owner names
- Full citations (county records, parcel numbers, access date)

**Step 2: Trace corporate ownership**

[If Archivist finds Delaware LLC, dispatch Analyst agent]

**Prompt:**
You are an Analyst tracing corporate ownership.

**Task:** Research the Delaware LLC(s) found in property records. Find:
- Corporate registry information
- Parent company or REIT affiliation
- Other properties owned in Oakland or California
- Any public financial disclosures or investor materials

**Sources:** Delaware Division of Corporations, SEC EDGAR database, commercial property databases

**Output:** Add to `writing/source-notes/property-ownership.md` with corporate structure diagram if complex

**Step 3: Fact-check ownership claims**

[Dispatch Fact-Checker agent to verify property records and corporate traces]

**Step 4: Save with sources**

```bash
git add writing/source-notes/property-ownership.md
git commit -m "research: trace Telegraph Ave property ownership to Delaware LLC"
```

---

## Task 3: Eviction Records Analysis

**Resources:**
- Search: Alameda County Superior Court eviction records
- Documents: `writing/source-notes/eviction-data.md`

**Step 1: Research eviction filings**

[Dispatch Analyst agent for quantitative analysis]

**Prompt:**
You are an Analyst researching eviction patterns in West Oakland.

**Task:** Analyze eviction filings in West Oakland (zip code 94607) from 2019-2023.

**Sources:** Alameda County Superior Court records (case types: Ellis Act, Owner Move-In, no-fault evictions)

**Output:** Create `writing/source-notes/eviction-data.md` with:
- Total evictions by year and type
- Buildings with multiple evictions
- Temporal patterns (before/during/after eviction moratorium)
- Confidence assessment and data limitations

**Step 2: Fact-check statistical claims**

**Step 3: Save with sources**

---

## Task 4: Draft Opening (Maria's Story)

**Resources:**
- Draft: `writing/drafts/opening-marias-story.md`
- Interview notes: `writing/field-notes/2024-01-12-maria-rodriguez-interview.md`

**Step 1: Draft personal anecdote opening**

[Dispatch Narrator agent]

**Prompt:**
You are a Narrator drafting the opening of an investigative feature.

**Task:** Draft 400-500 word opening using Maria Rodriguez's eviction story as entry point. Balance personal detail with broader pattern.

**Sources:** Interview notes (anonymize as needed), eviction notice details (with consent)

**Tone:** Personal but not melodramatic; specific sensory details; hint at systemic forces

**Step 2: Ethical review**

[Dispatch Ethicist agent]

**Review checklist:**
- [ ] Consent obtained for all details
- [ ] Trauma handled responsibly (not gratuitous)
- [ ] Maria portrayed with dignity and agency
- [ ] No identifying details that could enable harm

**Step 3: Fact-check quotes and details**

**Step 4: Save draft**

```bash
git add writing/drafts/opening-marias-story.md
git commit -m "draft: opening section with Maria Rodriguez story"
```

---

## Task 5: Tenant Organizer Interviews

**Resources:**
- Questions: `writing/field-notes/organizer-interview-questions.md`
- Notes: `writing/field-notes/YYYY-MM-DD-organizer-name-interview.md`

**Step 1: Prepare interview questions**

[Dispatch Community Listener agent to suggest questions that center affected voices]

**Step 2: Conduct interviews (outside Claude)**

**Step 3: Document findings with consent**

---

## Task 6: Investigative Synthesis

**Resources:**
- Draft: `writing/drafts/financial-flows-section.md`

**Step 1: Connect property ownership to investor patterns**

[Dispatch Analyst agent to synthesize property records, corporate ownership, and financial context]

**Step 2: Challenge causal claims**

[Dispatch Skeptic agent to test logic: Is this coordinated or opportunistic? What alternative explanations exist?]

**Step 3: Draft section with inline citations**

**Step 4: Fact-check and save**

---

## Task 7: Final Ethical Review

**Before publication:**

**Step 1: Full draft ethical review**

[Dispatch Ethicist + Community Listener agents]

Review:
- Harm assessment (who could be hurt?)
- Missing voices (who should have been consulted?)
- Representation (dignified portrayal?)
- Actionable information (does this help organizing?)

**Step 2: Address feedback**

**Step 3: Final fact-check**

[Dispatch Skeptic agent for independent verification of all claims]

---

## Execution Strategy

**Estimated timeline:** 4-6 weeks (research-intensive)

**Specialist agents needed:**
- Archivist (property records, news archives)
- Analyst (rent data, eviction statistics, financial analysis)
- Ethicist (harm assessment, representation review)
- Narrator (voice calibration, emotional arc)
- Skeptic (challenge causal claims, test logic)
- Community Listener (anticipate affected community response)

**Fact-checking milestones:**
- After each research task: verify sources
- After drafting each section: check claims
- Before final publication: independent fact-check by Skeptic agent

**Ethical review checkpoints:**
- Before interviewing: consent and anonymization plan
- After drafting: representation and harm review
- Before publication: community consultation (if feasible)
