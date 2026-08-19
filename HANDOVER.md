# HANDOVER — CAQ Posit Connect Cloud demonstrator

**Handover date:** 19 August 2026, end of Day 1
**Demo date:** 24 August 2026 (5 days from project start)
**Status:** Day 1 complete, one day ahead of plan. Deployment path proven end to end.

This document hands the work from a browser-based assistant session to Claude Code running
locally against the repository. Read `CLAUDE.md` first for conventions, then this.

---

## 1. Where the project stands

**Day 1 objective was to prove the deployment path before writing any real content.** That is
done. Both content types deploy to Posit Connect Cloud from a single public GitHub repository,
in about ten seconds, sharing one canonical code layer.

### Deployed and working

| Item | Path | Status |
|---|---|---|
| Shiny probe app | `app.R` | Deployed, all diagnostics pass |
| Quarto probe report | `report/facility-report.qmd` | Deployed, all chunks execute |
| Shared layer | `R/smoke_shared.R` | Sourced successfully by both |
| Probe data | `data/smoke_data.csv` | Read successfully by both |
| Manifest | `manifest.json` (root) | Serves both content items |

Both files contain **placeholder content only**. Per D-024 they keep their filenames for the
life of the project — real content replaces placeholder content in place, so the Connect Cloud
deployment records created on Day 1 are reused all week and the push-to-redeploy demonstration
runs against content that has been deploying successfully since the start.

### What Day 1 established (see `issues-register.md` I-001 for the full result table)

All eight verification checks closed. The consequential findings are recorded in `CLAUDE.md`
under "Deployment facts" — read them rather than rediscovering them. In summary: Connect Cloud
needs `manifest.json` and ignores `renv.lock`; subdirectory manifests are ignored; the whole
repo is cloned so a single shared `R/` layer works; the two products run from different
absolute paths but both from the tree root; packages arrive pre-built so the dependency set
needs no pruning.

---

## 2. Registers — read these, they are the project memory

| File | Contains |
|---|---|
| `project-brief.md` | Scope, audience, indicators, **full data specification (§6)**, architecture, timeline |
| `decision-register.md` | 27 decisions (`D-001`–`D-027`). All agreed; none pending. |
| `issues-register.md` | 17 issues (`I-001`–`I-017`). Open items listed below. |

### Open issues carried into Day 2

| ID | Severity | Summary |
|---|---|---|
| I-005 | High (at first push) | Public repo — no real DB/schema names anywhere, including comments |
| I-008 | High | Live demo depends on network, GitHub and Connect Cloud from the presentation room |
| I-009 | Medium | Stage "Unknown" handling undefined — decide in the Day 2 metrics layer and record it |
| I-010 | High | Deploy something every day; the repo should never go 24h without a successful deployment |
| I-015 | Medium | `manifest.json` must be regenerated whenever files or packages change |
| I-016 | Medium | Divergent working directories — apply the `root.dir` mitigation in the Day 3 report |
| I-017 | Low (presentation) | Free-tier content is public; state this explicitly during the demo |
| I-018 | Medium | Two working copies (home, work laptop) — pull `--ff-only` on arrival, push before leaving |
| I-019 | Medium | CSV drops factor ordering — `data_prep.R` must set explicit levels |
| I-020 | Medium | Data generated under R 4.5.2 / user library, not the lockfile environment — re-run on the laptop |
| I-021 | Low | Stage-adjusted S2 gap is a noisy estimator; tolerance widened, no action |

---

## 3. The immediate next task

**DONE 2026-08-19 — `data-raw/generate_synthetic_data.R` is written, run and validated.**
The five CSVs in `data/` are committed. All assertions pass; achieved magnitudes are recorded
in D-030 (amended), D-031, D-032 and D-033.

Achieved signal magnitudes, for narration:

| Signal | What the data shows |
|---|---|
| **S1** | F04 colorectal prolonged LOS: 12.5 / 12.8 / 11.8% (2015–17), rising to **28.4% in 2023**, correcting to **9.8% in 2024**. The report's two periods show only 13.3% → 20.1%. |
| **S2** | Lung surgery rate 22.2% rest of state vs **12.1%** in H5+H6 — a 10.1pp crude gap. |
| **S3** | Stage IV in lung: 44.7% rest of state vs **53.3%** in H5+H6. Explains 44% of the S2 gap; 5.7pp of access residual remains. |

**The next task is the shared `R/` layer** — `data_prep.R`, `metrics.R`, `suppression.R`,
`theme.R`. Two things must be settled as part of it: **I-009** (stage "Unknown" handling —
still open, and the data now carries Unknown at 3.4–5.4% per stream) and **I-019** (factor
levels must be set explicitly on read).

### Specification

The full data specification is **`project-brief.md` §6**. Do not re-derive it. In brief:
~45,000 patient rows, one row per patient, three tumour streams, 2015–2024, 6 HHSs, 15
facilities, five CSVs in a star-ish schema.

### Required properties of the generator

1. **Fixed seed**, so the data is reproducible and the script is itself a demo asset (D-001).
2. **Stage must be drawn BEFORE surgery**, and surgery probability conditioned on stage. This
   ordering is required by signal S3 (D-011).
3. **Three planted signals**, all documented as designed artefacts:
   - **S1** — Colorectal, one facility, prolonged LOS (IND-04): tracks the overall rate
     2015–17, deteriorates progressively 2018–2023, corrects sharply in 2024. Must be shaped
     so that the 2015–19 vs 2020–24 aggregation **under-calls it** — the static report shows a
     mild deterioration, the app reveals the rise, peak and recovery. This contrast is the
     central argument of the whole demonstration.
   - **S2** — Lung, two HHSs of residence, materially lower surgery rate (IND-01).
   - **S3** — Lung, same two HHSs, stage skewed later (IND-06), **sized so stage explains
     approximately half the S2 gap**, leaving a service-access residual.
4. **Two or three deliberately low-volume facilities**, to widen funnel-plot control limits and
   give small-cell suppression something to act on.
5. **Eligibility expressed as `NA`** (D-007): patients without surgery carry `NA` in
   `facility_id`, `days_to_surgery`, `hac_flag`, `los_days`, `prolonged_los_flag` and
   `readmit_28d_flag`.
6. **A validation block that ASSERTS each signal landed at its intended magnitude** rather than
   trusting the RNG. Include the crude S2 gap, the stage-adjusted S2 gap (must be roughly half
   the crude gap), and the S1 by-year series versus its two-period aggregation.

### Two questions — both ANSWERED 2026-08-19, no longer blocking

**Q1 — Sex and tumour stream.** Answered: **breast is female-only**, no male cohort. Recorded
as **D-028**.

**Q2 — Surgery rate baselines by stream.** Answered: **plausible-but-invented is acceptable**
under D-002. The specific stage distributions and stage-conditioned surgery probabilities are
now fixed in **D-029**, and the S2/S3 sizing that sits on top of them in **D-030**. Read those
rather than re-deriving numbers — they are the single reference for the generator, and the
validation block asserts against them.

---

## 4. Remaining schedule

| Day | Date | Milestone |
|---|---|---|
| 2 | 21 Aug | Generator written and validated. Shared layer: `data_prep.R`, `metrics.R`, `suppression.R`, `theme.R`. Resolve I-009. |
| 3 | 22 Aug | Quarto report replaces the probe content. Apply the I-016 `root.dir` mitigation. |
| 4 | 23 Aug | Shiny app replaces the probe content. Metadata-driven stratifier menu (D-008). |
| 5 | 24 Aug | Persona switcher (D-004), polish, **full dress rehearsal on the demo machine**. |

Deploy at least once every day (I-010).

---

## 5. Design notes worth carrying forward

**The indicator eligibility rule drives the architecture.** Patients attach to a facility only
if they had surgery. So IND-01 (surgery rate) and IND-06 (stage distribution) are cohort-wide
and can only be analysed by **HHS of residence** — grouping them by facility is a category
error. `indicator_definitions.csv` declares `facility_dims_allowed`, and the Shiny app must
build its stratification menu from that table so the invalid option never renders (D-008).
This is a governance talking point for the data-warehousing lead in the audience, not just a
guardrail.

**Suppression order** (D-023): aggregate across all facilities first, then suppress. Tabular
output suppresses the count; funnel plots retain the point but suppress the identifying label.
Never remove a facility before computing the pooled mean and control limits — the low-volume
facilities are what the widening limits exist to show.

**`plotly` for funnel plots only** (D-014). Everything else is static `ggplot2`. Note
`ggplotly()` drops `subtitle` and `caption`, so funnel-plot footnotes must be separate
`htmltools` text (I-004).

**UI scope** (D-013): stock `bslib::page_sidebar()`. The earlier CAQ prototype's custom filter
rail, overlay drawer, chip strip and 736-line stylesheet are **not** being reproduced. Its
`theme.R` palette and `bs_theme()` block are adopted; the chrome is not. Revisit only if Day 4
finishes early.

**The `root.dir` mitigation for Day 3** (I-016) — walk up until the shared layer is visible,
rather than assuming a fixed relative depth:

```r
# Connect Cloud renders the report from the root of a temporary repository copy,
# while the Shiny app runs from /cloud/project — different absolute paths, same
# tree structure (D-017, I-016). This is correct under both, and under a local
# render from report/.
.root <- base::normalizePath(".")
while (!base::file.exists(base::file.path(.root, "R", "smoke_shared.R")) &&
       base::dirname(.root) != .root) {
  .root <- base::dirname(.root)
}
knitr::opts_knit$set(root.dir = .root)
```

Replace `smoke_shared.R` with whichever shared file exists by then.

---

## 6. Applying this bundle

1. Copy `CLAUDE.md` and `HANDOVER.md` to the repository root.
2. **Overwrite** `project-brief.md`, `decision-register.md` and `issues-register.md` — the
   copies currently in the repository predate the Day 1 findings and are stale.
3. **Overwrite** `README.md` — the version in the repository still describes the abandoned
   flat-root layout and the now-completed Day 1 checklist.
4. Delete `report/manifest.json` if present. It is ignored by Connect Cloud and its presence
   is misleading (D-017).
5. Commit, push, and confirm both content items still deploy — that is the I-010 daily
   deployment for the day.
