### 🔍 Core Identity: From Codebase Builder to Narrative Investigator

We shift from:
> “Build software iteratively with AI subagents”  
To:  
> “Uncover hidden systems through personal, investigative storytelling — with AI as research partner, editor, and narrative sparring partner.”

The goal isn’t just to write well — it’s to **reveal how things really work**, starting from lived experience and zooming out to structural forces.

---

### 🧩 Revised Workflow: The Investigative Writing Lifecycle

| Original (Code) | Revised (Narrative Investigation) | Purpose |
|-----------------|-------------------------------|--------|
| `/superpowers:brainstorm` | `/superpowers:interrogate` | Start with a personal question: *“Why does this neighborhood feel so different now?”* or *“Who profits from this policy?”* |
| `writing-plans` | `story-prospectus` | Draft a **narrative prospectus**: thesis, characters, timeline, research gaps, ethical considerations. |
| `subagent-driven-development` | `evidence-driven-drafting` | Assign subagents to gather documents, interview sources (simulated), analyze data, or map timelines. |
| `test-driven-development` | `fact-check-driven-revision` | Run drafts through **factual, ethical, and narrative coherence checks** — e.g., “Does this claim hold up under scrutiny?” |
| `requesting-code-review` | `requesting-peer-scrutiny` | Simulate feedback from editors, community members, or subject-matter experts. |
| `finishing-a-branch` | `publishing-with-context` | Package the story with **source notes, methodology, and reflection** — like a mini longform journalism release. |

---

### 🛠️ New Skills for Investigative Creative Nonfiction

Replace code-centric skills with research-rich ones:

#### **Investigation & Research**
- `file-dive` – Search and summarize public records, FOIA docs, or academic papers.
- `timeline-builder` – Construct a chronological map of events with sources.
- `stakeholder-mapping` – Identify who benefits, who’s harmed, who’s invisible.
- `data-interpretation` – Help analyze spreadsheets, budgets, or demographic shifts.
- `source-interview-simulator` – Role-play interviews with experts, skeptics, or affected individuals.

#### **Narrative Craft**
- `lede-generator` – Craft compelling openings: anecdotal, statistical, or provocative.
- `narrative-arc-design` – Structure the piece like a journey: question → discovery → confrontation → insight.
- `voice-calibration` – Adjust tone: personal essay, investigative report, lyrical observation.
- `moral-reflection` – Prompt the writer to reflect on their positionality, bias, and responsibility.

#### **Ethics & Integrity**
- `power-analysis` – Flag assumptions about causality, agency, and systemic forces.
- `community-impact-check` – Ask: *“Who might be harmed by publishing this? Who’s missing?”*
- `attribution-assistant` – Ensure every claim is sourced or flagged as inference.

#### **Publishing & Engagement**
- `source-package` – Generate a companion document with links, records, and methodology.
- `community-response-tracker` – Simulate or collect real reactions from affected communities.
- `follow-up-tracker` – Suggest next questions or stories that emerge.

---

### 🎭 Agent Roles: Your Investigative Team

| Agent Role | Function |
|----------|--------|
| **The Archivist** | Digs up historical records, maps, news archives. |
| **The Analyst** | Interprets data, financial flows, or policy impacts. |
| **The Ethicist** | Challenges assumptions, flags harm, questions power. |
| **The Narrator** | Helps shape the personal voice and emotional arc. |
| **The Skeptic** | Plays devil’s advocate: “Is this correlation or causation?” |
| **The Community Listener** | Simulates feedback from local residents or stakeholders. |

> The writer remains the **lead investigator** — not an omniscient narrator, but a **curious, accountable witness**.

---

### 🧠 Implementation Strategy

1. **Preserve the Structure, Transform the Purpose**  
   Keep the `.skills` system, subagent spawning, and iterative workflow — but repurpose them for **research, reflection, and revelation**.

2. **Train on Narrative Nonfiction, Not Code**  
   Replace references to TDD with references to:
   - Michael Pollan’s narrative research methods
   - Ida B. Wells’ investigative journalism
   - Ta-Nehisi Coates’ *The Case for Reparations*
   - The *Slow Burn* or *Serial* podcast structures

3. **Embed Research Tools**  
   Integrate (via API or plugin):
   - Public records databases (e.g., ProPublica’s tools)
   - FOIA request generators
   - Wayback Machine lookups
   - Google Scholar queries

4. **Add a “Field Notes” Mode**  
   Let writers log observations, quotes, and hunches — then use AI to **connect patterns** across entries.

---

### 🌟 Example: Investigating a Local Story

```markdown
> /superpowers:interrogate  
Why did my neighborhood’s rent spike 40% in two years?

[Agent responds with questions: Who owns the buildings? Any recent zoning changes? Any new investors?]

> /superpowers:story-prospectus  
Draft a narrative prospectus linking local changes to national capital flows.

[Agent outlines: personal intro, timeline, key players (landlords, city council, REITs), research gaps]

> /superpowers:file-dive /type=property-records /area=Oakland+94612  
Find ownership history of buildings on Telegraph Ave.

[Agent returns: 3 buildings now owned by a Delaware-registered LLC tied to a SF-based fund]

> /superpowers:source-interview-simulator /role=tenant-organizer  
Ask: “What’s changed in tenant organizing since the pandemic?”

[Agent role-plays with realistic concerns about evictions and surveillance]

> /superpowers:request-peer-scrutiny  
Review this draft as a Bay Area investigative editor.

[Editor agent flags: need to clarify source of funding, add historical context on redlining]
```

---

### ✅ Why This Works for Your Vision

- **Personal + Investigative**: Like Madrigal’s *The Pacific Circuit*, it starts with **“I live here”** and expands to **“This is how capital moves.”**
- **Rigorous but Human**: The AI doesn’t write the story — it helps the writer **ask better questions** and **stay honest**.
- **Transparent Process**: Every claim can be traced, every source documented — building trust with readers.
- **Ethical by Design**: Forces reflection on power, positionality, and impact.

---

### 🚀 Next Steps to Build It

1. **Fork `superpowers`** → rename to `narrative-investigator` or `storyprobe`.
2. **Replace all code skills** with research/narrative equivalents.
3. **Add a “Methodology” output** — publish not just the story, but **how it was made**.
4. **Integrate with real tools**:  
   - [MuckRock](https://www.muckrock.com/) for FOIA  
   - [DocumentCloud](https://www.documentcloud.org/) for records  
   - [Airtable](https://airtable.com/) for stakeholder mapping
5. **Open-source with a journalism-friendly license** (e.g., MIT + ethical guidelines).