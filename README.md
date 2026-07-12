# YouTube Video Production Pipeline

Mission Control hub for a three-channel YouTube production pipeline: **Drone Technology**, **Military Bases**, and **Family**.

## Quick Start

Open `index.html` in a browser (or serve locally):

```bash
python3 -m http.server 8080
# Visit http://localhost:8080
```

## Structure

| Page | Purpose |
|------|---------|
| `index.html` | Main hub — channels + Section 1 pipeline links |
| `mission-control.html` | Team dashboard — grades, phase status, CTR targets |
| `channels/` | Per-channel hubs with video queue and phase links |
| `phases/` | 9 phase sub-pages with checklists, scores, feedback |

## Pipeline Phases (Section 1)

1. **Trends & Research** — Scrape leaders, analyze thumbnails, hooks, A/B-roll
2. **Automation & Drafts** — Scripts, screenshots every 3–5 sec
3. **Avatar Narrative** — Sentinel 1 Tactical Operations Officer (faceless)
4. **Strategy Session** — War planning, cost, warriors strategy
5. **AI Review & Testing** — Human-in-loop validation
6. **Mission Control Submit** — 2–3 min video (under 3 min)
7. **Analytics & Scoring** — YouTube analytics, AI triggers, final review
8. **Week One Evaluation** — CTR pass ≥ 6%, edit if low
9. **Pipeline Tracking** — Views, comments, continuous prompts

## Team Features

- **Checklists** — Per-phase tasks (saved in browser localStorage)
- **Score system** — 70% pass threshold; low scores trigger edit workflow
- **Feedback** — Team comments on each phase page
- **Continuous prompts** — Rotating AI prompts (tweet each cycle)
- **Mission Control** — Cross-channel grade overview

## Grading

- Composite score ≥ **70%** = PASS
- Week-one **CTR ≥ 6%** = PASS
- Video length: **2–3 minutes** (hard cap under 3 min)
