---
name: fact-check-driven-revision
description: "Enforce CLAIM-CHECK-REVISE cycle: make claim, verify source, revise if needed. Every assertion must be sourced or marked as inference before proceeding."
---

# Fact-Check-Driven Revision

## Overview

Just as test-driven development ensures code works, fact-check-driven revision ensures claims hold up. Write claims, check sources, revise before moving on.

**Announce when active:** "I'm using fact-check-driven revision to verify claims."

## The Cycle: CLAIM → CHECK → REVISE

### 1. CLAIM (Draft assertion)

Write the claim you want to make:

```markdown
Between 2020 and 2022, rents in West Oakland increased by 35%, displacing hundreds of families.
```

### 2. CHECK (Verify against sources)

Ask:
- Do I have a source for "35%"?
- Do I have evidence for "hundreds of families"?
- Is causation clear ("displacing") or is this correlation?

Check sources:
- Census/rental data for the 35% figure
- Eviction records or tenant interviews for displacement numbers
- Research on rent increases → displacement link

### 3. REVISE (Strengthen or qualify)

**If fully sourced:**
```markdown
Between 2020 and 2022, median rents in West Oakland increased by 37%, according to Zillow rental data^[Zillow Observed Rent Index, West Oakland, 2020-2022, accessed 2024-01-15]. Eviction records show 412 no-fault evictions in the same period^[Alameda County Superior Court records, case types Ellis Act and Owner Move-In, 2020-2022], though exact displacement numbers are difficult to verify as many families left before formal eviction.
```

**If partially sourced:**
```markdown
Between 2020 and 2022, median rents in West Oakland increased by 37%^[Zillow], though the exact number of displaced families is unclear—eviction records show 412 no-fault evictions^[County records], but this likely undercounts informal displacement.
```

**If unsourced - mark as inference:**
```markdown
[INFERENCE - NEEDS VERIFICATION] Between 2020 and 2022, rents in West Oakland appear to have spiked dramatically. I'm seeing anecdotal reports of displacement but haven't yet found comprehensive data.

[Research gap: Need rental price index for West Oakland 2020-2022; need eviction/displacement statistics]
```

## Standards

See @fact-checking-standards for:
- What counts as a source (primary vs. secondary)
- How to cite (inline citations with footnotes)
- When to use "appears," "suggests," "may" (uncertainty language)
- Common fact-checking pitfalls (correlation ≠ causation, misleading statistics, quote mining)

## Workflow Integration

**During drafting:**
- Write sentence → check source → cite or flag
- NEVER move to next paragraph until current claims are verified or flagged

**During revision:**
- Review all [INFERENCE] flags
- Track down sources or qualify claims
- Run through fact-checker agent for independent review

## Key Principle

**No unsourced claims in published drafts.** Everything is either:
1. Sourced with citation
2. Marked as inference/speculation with [INFERENCE] flag
3. Qualified with uncertainty language ("appears," "may," "according to")

This isn't pedantry—it's accountability.
