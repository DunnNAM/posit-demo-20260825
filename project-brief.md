# Project Brief — CAQ Posit Connect Cloud Demonstrator

**Status:** Draft v0.1 — awaiting sign-off
**Owner:** Nathan (Reporting & Analysis Co-lead), Cancer Alliance Queensland
**Last updated:** 2026-08-19
**Demo date:** 2026-08-24 (5 days from brief date)

---

## 1. Purpose

Build a small, self-contained set of R content — a Quarto HTML report and a Shiny
dashboard — using **synthetic** cancer indicator data, publish both to **Posit Connect
Cloud** from a public GitHub repository, and demonstrate that workflow live to CAQ
management.

**The subject of the demonstration is the publishing workflow and the platform, not the
clinical findings.** The data is invented. Every design choice below is made to serve the
demonstration, not to produce a defensible clinical product.

### What we are trying to prove

| Claim | How the demo evidences it |
|---|---|
| One-click publishing from Git | Push to GitHub → deploy in Connect Cloud UI, live on screen |
| Connect hosts multiple content types in one place | Quarto report + Shiny app side by side in one Connect dashboard |
| Reproducible environments travel between machines | `renv.lock` committed; deployment restores it |
| Dynamic content answers questions static content cannot | Planted signal S1 (see §6) is invisible in the report, obvious in the app |
| Content can be tailored per viewer | "View as" persona switcher (see §5) |

### Current state being improved on

Static reports deployed to a website, with facility-level reports published individually to
distinct URLs. No accompanying dashboards, and no ability to serve differentiated
content from a single URL based on viewer identity.

---

## 2. Audience

Seven people, presented to by Nathan. Each has a distinct hook — content should give
each of them something.

| Person | World | Hook |
|---|---|---|
| Senior Director | Health informatics, cancer data, clinical improvement (20 yr) | Visibility/impact, reproducible statewide numbers, governance |
| Tech lead 1 | Data warehousing, MSSQL/SSIS, Power BI, Qlik | Package Manager as governed internal CRAN; Connect vs Power BI; pipelines |
| Tech lead 2 | Software dev; standing up off-grid synthetic-data AI/LLM env | Reproducible envs, CI/CD via git, Workbench as a real dev platform |
| Clinical lead A | Cancer content, registry coders, Excel pivots on MSSQL/cubes | Consumer of output; self-service dashboards |
| Clinical lead B | As above | As above |
| Analysis co-lead | Medical writing, **Stata** (no R) | Reassurance: Workbench serves Stata/Python too; nobody loses their tools |
| Nathan | Reporting & Analysis co-lead | Narrator |

**Implication for design:** the report and app must be legible to a non-R audience
(Clinical leads, Analysis co-lead) while the *repository* must look credible to Tech
leads 1 and 2. Code comments, the register files, and `renv.lock` are part of the
deliverable, not overhead.

---

## 3. Deliverables

### Non-negotiable

1. **Quarto HTML report** — facility-level performance across the clinical indicators,
   presented as two five-year periods (2015–19, 2020–24). Static, published to Connect Cloud.
2. **Shiny dashboard** — same data, with filter / stratify / group-by across demographic
   and clinical variables. Published to Connect Cloud.

### Stretch

3. **Persona-based content filtering** — the same app serves different scope depending on
   the selected persona. Implemented as a visible "View as" switcher (D-004), not real
   authentication.

### Out of scope for this phase

- Real or re-identifiable data of any kind
- Any claim of clinical validity or endorsement of indicator definitions
- Live database connectivity (MSSQL/SSIS) — a conversation topic, not a build item
- Package Manager / Workbench / CI-CD pipeline demonstrations
- Real Connect Cloud account provisioning and group-based authorisation
- Reusable template packaging for other CAQ analysts (may be harvested later — D-021)

---

## 4. Indicators

Six indicators. Four core, two build-if-time. Each is stored as a **pre-calculated result
column** on the patient row — we are not modelling the underlying episode structure
(D-006).

| ID | Indicator | Measure | Cohort | Facility dims allowed? | Priority |
|---|---|---|---|---|---|
| IND-01 | Surgery rate | Proportion | All diagnosed | **No** | Core |
| IND-02 | Time to surgery | Median + IQR (days) | Surgical | Yes | Core |
| IND-03 | Hospital-acquired complication | Proportion | Surgical | Yes | Core |
| IND-04 | Prolonged length of stay (>21 days) | Proportion | Surgical | Yes | Core |
| IND-05 | 28-day unplanned readmission | Proportion | Surgical | Yes | Build-if-time |
| IND-06 | Stage at diagnosis distribution | Distribution | All diagnosed | **No** | Build-if-time |

### The eligibility rule that drives the architecture

Patients are only attached to a treatment facility **if they had surgery**. Therefore:

- **IND-01 and IND-06** are cohort-wide and can only be analysed by **HHS of residence**.
  Grouping them by treating facility or facility HHS is a category error and must be
  impossible in the UI.
- **IND-02 to IND-05** are surgical-cohort only and are facility-attributable.

This is enforced by metadata, not by convention (D-008): `indicator_definitions.csv`
declares `facility_dims_allowed`, and the Shiny app builds its stratification menu from
that table so invalid combinations never render.

### Why IND-05 and IND-06 were added

- **IND-05** has small denominators at low-volume facilities, which justifies the funnel
  plot with control limits and demonstrates small-cell suppression.
- **IND-06** gives a 100% stacked bar and, via signal S3, becomes the explanatory
  drill-down for the IND-01 signal.

---

## 5. Personas ("View as")

| Persona | Scope served |
|---|---|
| Statewide Director | All HHSs, all facilities |
| HHS Executive | Single HHS — own HHS highlighted, others shown de-identified as peers |
| Facility Director | Single facility — own facility named, others as peers |
| Clinician | Single facility, single tumour stream |

Narration line for the demo: *"in production this comes from the authenticated session,
not a dropdown."*

---

## 6. Data specification

### Scale

- **Years:** 2015–2024 inclusive (10 years)
- **Tumour streams:** Lung, Colorectal, Breast (3)
- **HHSs:** 6 (used for both residence and facility location)
- **Facilities:** 15, distributed unevenly across the 6 HHSs
- **Volume:** 10,000–20,000 records per stream (~45,000 patient rows total)
- **Grain:** one row per patient, one diagnosis per patient

### Schema — star-ish, five CSVs (D-010)

**`patients.csv`** — fact table

| Column | Type | Notes |
|---|---|---|
| `patient_id` | chr | Synthetic key |
| `tumour_stream` | chr | Lung / Colorectal / Breast |
| `diagnosis_date` | date | Drives year; supports finer time views in app |
| `diagnosis_year` | int | 2015–2024 |
| `age` | int | Age at diagnosis |
| `age_group_5yr` | fct | Ordered |
| `age_group_10yr` | fct | Ordered |
| `sex` | fct | |
| `hhs_residence` | fct | Patient's HHS of residence |
| `seifa_quintile` | fct | Q1 (most disadvantaged) – Q5 |
| `stage` | fct | I / II / III / IV / Unknown — IND-06 |
| `had_surgery` | lgl | IND-01 numerator |
| `facility_id` | chr | **NA if no surgery** |
| `days_to_surgery` | int | **NA if no surgery** — IND-02 |
| `hac_flag` | lgl | **NA if no surgery** — IND-03 |
| `los_days` | int | **NA if no surgery** |
| `prolonged_los_flag` | lgl | `los_days > 21`; **NA if no surgery** — IND-04 |
| `readmit_28d_flag` | lgl | **NA if no surgery** — IND-05 |

**`facilities.csv`** — `facility_id`, `facility_name`, `facility_hhs`, `facility_type`,
`volume_band`

**`hhs.csv`** — `hhs_id`, `hhs_name`

**`indicator_definitions.csv`** — `indicator_id`, `label`, `short_label`, `measure_type`,
`cohort`, `result_col`, `facility_dims_allowed`, `direction`, `format`, `definition_text`

**`user_roles.csv`** — `persona_id`, `persona_label`, `scope_type`, `scope_value`,
`tumour_stream_scope`

### Derived, not stored (D-020)

`diagnosis_period` (2015–19 / 2020–24) is derived in the shared prep layer so the report
and app can never disagree on the cut.

### Stratification variables available in the Shiny app

Age group (5-yr and 10-yr), sex, HHS of residence, treatment facility, HHS of treatment
facility, year of diagnosis, stage at diagnosis, SEIFA quintile, tumour stream.

**Deliberately excluded:** First Nations status and remoteness (D-019). Both are realistic
and CAQ-relevant, but a synthetic "gap" appearing in a chart in front of this audience
invites a reaction to a finding that does not exist.

### Planted signals (D-011)

These are **designed artefacts**, documented so nobody mistakes them for findings.

| ID | Signal | Purpose |
|---|---|---|
| **S1** | **Colorectal, one facility, IND-04.** Tracks the overall rate 2015–17, deteriorates progressively 2018–2023, corrects sharply in 2024. | The money moment. Aggregated into 2015–19 vs 2020–24 this reads as a mild deterioration; the app reveals the shape and the recovery. |
| **S2** | **Lung, two HHSs, IND-01.** Materially lower surgery rates by HHS of residence. | Demonstrates residence-based analysis and prompts the "why?" question. |
| **S3** | **Lung, same two HHSs, IND-06.** Stage distribution skewed later. *(proposed — see I-006)* | Answers the S2 "why?" — partially. Sized so stage explains roughly half the gap, leaving a service-access residual. |

### Realism

A small number of facilities with genuinely low caseloads, to widen funnel-plot control
limits and to give small-cell suppression something to act on. No other deliberate
messiness.

---

## 7. Architecture

### Repository layout — flat root (D-017)

Both Connect Cloud deployments resolve paths from the repository root, which removes an
entire class of "works locally, breaks deployed" path failures.

```
caq-posit-demo/
├── renv.lock                    # Reproducible environment
├── .Rprofile
├── project-brief.md             # ← this file
├── decision-register.md
├── issues-register.md
├── app.R                        # Shiny entry point (Connect Cloud primary file)
├── facility-report.qmd          # Quarto entry point (Connect Cloud primary file)
├── data-raw/
│   └── generate_synthetic_data.R   # Seeded generator; run once, output committed
├── data/                        # Committed CSVs (~3–6 MB)
├── R/                           # SHARED — sourced by BOTH report and app
│   ├── theme.R                  # Adopted verbatim from existing prototype
│   ├── data_prep.R              # Load, join, derive
│   ├── metrics.R                # Indicator calculation
│   ├── plots.R                  # Plot functions
│   └── suppression.R            # Small-cell rules
├── R/modules/                   # Shiny modules only
└── www/style.css                # Trimmed subset of prototype CSS
```

The `R/` layer is the single source of truth for indicator logic. If the report and the
app ever disagree on a number in front of this audience, the demo is over — so neither
one calculates anything itself.

### Conventions inherited from the existing prototype

- `D-###` / `I-###` register ID scheme, referenced inline in code comments
- CAQ palette and `ggplot2` theme via `R/theme.R`
- `bslib::bs_theme()` with `flatly` preset, Lato, CAQ semantic colours

### Conventions changed for this project

- **Explicit `library()` calls, not `pacman::p_load()`** (D-015) — `renv` cannot detect
  dependencies inside `p_load()`
- **All function calls namespaced** (D-016)
- **`bslib::page_sidebar()`, not the custom rail/drawer/chips** (D-013)

---

## 8. Timeline

| Day | Date | Milestone | Risk retired |
|---|---|---|---|
| 1 | 20 Aug | Registers signed off. Data generator written, data validated. **Trivial Quarto doc deployed to Connect Cloud end-to-end.** | The entire deployment path |
| 2 | 21 Aug | Shared `R/` layer: prep, metrics, suppression. Smoke-tested against data. | Numbers agreeing between products |
| 3 | 22 Aug | Quarto report complete and deployed. | Deliverable 1 |
| 4 | 23 Aug | Shiny app complete and deployed. | Deliverable 2 |
| 5 | 24 Aug | Persona switcher, polish, **full dress rehearsal on the demo machine**. | Live failure |

**Day 1 deployment test is the single most important item in this plan.** Everything else
can be descoped; an unproven deployment path cannot.

---

## 9. Success criteria

1. Both content types live on Connect Cloud, published from the public GitHub repo.
2. A code change can be pushed and redeployed live, on screen, in under two minutes.
3. The report under-calls signal S1; the app reveals it. Nathan can narrate the contrast.
4. Report and app never show different numbers for the same measure.
5. No stratification of IND-01 or IND-06 by any facility dimension is reachable in the UI.
6. Every claim about clinical meaning is visibly captioned as synthetic.
