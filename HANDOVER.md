# HANDOVER — CAQ Posit Connect Cloud demonstrator

**Handover date:** 19 August 2026, end of the second working session
**Demo date:** 24 August 2026
**Status:** Days 1, 2 and 3 of the plan are complete. **Two days ahead of schedule.**

Read `CLAUDE.md` first for conventions, then this. The registers
(`decision-register.md`, `issues-register.md`) are the project memory — 39 decisions
(`D-001`–`D-039`) and 24 issues (`I-001`–`I-024`). If it is not written down, it did not
happen.

---

## 1. Start here, tomorrow

You will most likely be on the **work laptop** (`D:/Development/posit-demo-20260825`), which
has not been touched since this morning and is several commits behind. Do this first:

```
cd /d D:\Development\posit-demo-20260825
git config pull.ff only          # not yet set on that clone (I-018)
git rev-parse --show-toplevel     # must return the demo folder, not D:/Development (I-005)
git status                        # anything uncommitted from before RStudio was closed?
git pull --ff-only
```

Nineteen commits went up today. If the pull refuses because of local commits, **do not merge
blindly** — see I-018; the registers are the files most likely to conflict, and a register
conflict almost always means two additions rather than a contradiction, so keep both sides.

---

## 2. What exists now

| Area | State |
|---|---|
| **Data** | `data-raw/generate_synthetic_data.R` + five committed CSVs. 45,000 patients. Byte-reproducible from seed 20260824, verified across two package environments. |
| **Shared layer** | `R/data_prep.R`, `R/metrics.R`, `R/suppression.R`, `R/plots.R`, `R/theme.R`. Verified by `tests/verify_shared_layer.R`. |
| **Report** | `facility-report.qmd` — written, rendered, every figure checked against the shared layer. Replaces the probe in place (D-024). |
| **App** | `app.R` — **still the Day 1 probe.** This is tomorrow's work. |
| **Deployment** | Both content items bound to root primary files. Last deployed content is the probe app + the new report. |

### Entry points into the shared layer

```r
caq_load_data()                 # -> list(patients, facilities, hhs, indicators, personas)
caq_calculate_indicator(dat, indicators, id, group_by = character())
caq_valid_stratifiers(indicators, id)     # drives the app's menu (D-008)
caq_suppress(res, mode = c("table","funnel"))
caq_suppression_caption(res, mode)
caq_stratifiers()                          # display label -> column name
```

Plot functions in `R/plots.R`: `caq_plot_indicator_bar()`, `caq_plot_distribution()`,
`caq_plot_funnel()`, `caq_plot_trend()`, `caq_funnel_limits()`, `caq_format_value()`.

### Verify everything still works

```
Rscript --vanilla tests/verify_shared_layer.R          # exits 0, 22 checks
Rscript --vanilla data-raw/generate_synthetic_data.R   # regenerates, all assertions pass
```

---

## 3. Tomorrow's task — the Shiny app (Day 4)

`app.R` currently holds Day 1 probe content. Replace it **in place** — never rename it, or the
Connect Cloud deployment record is lost (D-024).

### What it must do

1. **Stock `bslib::page_sidebar()`** (D-013). The old CAQ prototype's filter rail, overlay
   drawer, chip strip and 736-line stylesheet are explicitly not being reproduced.
2. **Build the group-by menu from `caq_valid_stratifiers()`** (D-008) so IND-01 and IND-06 can
   never be grouped by a facility dimension. The calculation layer also refuses it, but the
   menu is where the audience sees the guardrail.
3. **Reveal S1.** This is the payoff. `caq_plot_trend()` exists and the report deliberately
   never calls it (D-038). The app plots Ironbark Southbank's colorectal prolonged-LOS rate by
   year: baseline ~12%, **peak 28.4% in 2023**, corrected to **9.8% in 2024**. The report could
   only show 13.3% → 20.1% across two periods.
4. **Show suppression actually firing** (D-039). At facility × year × stream there are 21 cells
   below the threshold of five; the report's aggregations never reach it.
5. Carry the synthetic-data statement on the landing view (D-002).

### Day 5 stretch

Persona switcher (D-004), driven by `user_roles.csv` which is already generated. Narration
line: *"in production this comes from the authenticated session, not a dropdown."*

### Before the app deploys

**Regenerate the manifest** (I-015) — this is the one outstanding chore and it is now overdue:

```r
rsconnect::writeManifest(dependencyResolution = "library")
```

`dependencyResolution = "library"` is required. The file list has changed a great deal today:
`R/` gained five files, `data/` five, plus `data-raw/` and `tests/`, and the report added `gt`,
`plotly` and `htmltools`.

---

## 4. Achieved signal magnitudes — for narration

These are measured from the committed data, not targets.

| Signal | What the data shows |
|---|---|
| **S1** | Ironbark Southbank (F04), colorectal prolonged LOS: 12.5 / 12.8 / 11.8% (2015–17), rising through 2018–2023 to **28.4%**, correcting to **9.8%** in 2024. Two-period view: 13.3% → 20.1%. |
| **S2** | Lung surgery rate **22.2%** rest of state vs **12.1%** in Kurrajong + Melaleuca — a 10.1pp crude gap. |
| **S3** | Lung stage IV: **44.7%** rest of state vs **53.3%** in those two HHSs. Stage explains **44%** of the S2 gap, leaving a 5.7pp service-access residual. |

**The S1 contrast is the argument of the whole demonstration.** The report can show that the
facility deteriorated. It cannot show when it began, whether it is ongoing, or that it was
already fixed. Do not weaken this by adding a trend line to the report.

---

## 5. Open issues

| ID | Severity | Summary |
|---|---|---|
| I-005 | High at push | Public repo — no real DB/schema/server names anywhere, including comments |
| I-008 | High | Live demo depends on network, GitHub and Connect Cloud from the presentation room |
| I-010 | High | Deploy something every day; never 24h without a successful deployment |
| I-015 | **Medium — overdue** | `manifest.json` must be regenerated; file list has changed substantially |
| I-017 | Low (presentation) | Free-tier content is public — state this explicitly during the demo |
| I-018 | Medium | Two working copies; pull `--ff-only` on arrival, push before leaving |
| I-021 | Low | Stage-adjusted S2 gap is a noisy estimator; tolerance widened, no action |

Recently resolved, listed so nobody re-opens them: I-009 (D-034), I-016 (mitigation applied),
I-019 (explicit factor levels), I-020 (library restored, CSVs byte-identical), I-022 (real
palette adopted), I-023 (ggplotly legends), I-024 (Quarto path workaround).

---

## 6. Environment notes — hard-won, do not re-derive

**Restoring the library on a machine without matching Rtools** (D-037). CRAN serves Windows
binaries only for the *current* version of each package, so `renv.lock`'s pinned older versions
fall back to source builds. The home machine has only Rtools43 against R 4.5.2, and no admin
rights. Restore from Posit Package Manager dated snapshots instead:

```r
options(renv.config.repos.override = c(
  P3M_MAY = "https://packagemanager.posit.co/cran/2026-05-01",
  P3M_APR = "https://packagemanager.posit.co/cran/2026-04-15"
))
renv::restore(prompt = FALSE)
```

94 packages, all binaries, eleven seconds. **This is also demonstration material** — it is a
lived example of the Package Manager capability that is one of the audience's stated hooks.

**Four hypotheses were tested and eliminated** before finding that cause: OneDrive file
locking, blocked process spawning, Windows MAX_PATH, and install concurrency. Moving the
repository out of OneDrive would **not** have helped. Do not re-run those experiments.

**Rendering the report locally** (I-024). Quarto is not on PATH on the home machine; the only
copy is RStudio's bundled **1.3.353**, whose launcher breaks on the space in `Program Files`:

```
C:\PROGRA~1\RStudio\RESOUR~1\app\bin\quarto\bin\quarto.cmd render facility-report.qmd
```

Connect Cloud runs a much newer Quarto, so **a clean local render is weaker evidence than it
looks**. The first deployment of the real report is the actual test.

**Line endings** are pinned to LF by `.gitattributes`. Without it, `core.autocrlf=true` would
check the CSVs out as CRLF while the generator writes LF, and the reproducibility checksum
would fail for a reason unrelated to the seed.

---

## 7. Standing design constraints

**The eligibility rule drives the architecture.** Patients attach to a facility only if they
had surgery, so IND-01 and IND-06 are cohort-wide and analysable by HHS of residence only.
Enforced in metadata (`facility_dims_allowed`) and in `caq_calculate_indicator()`, which raises
rather than silently dropping the non-surgical cohort from the denominator.

**`NA` and `"Unknown"` are different things** (D-007, D-034). `NA` means *not eligible for this
indicator*. `"Unknown"` means *staged, stage not known*. `stage` is never `NA`. Reaching for
`na.rm = TRUE` to handle Unknown gives the wrong denominator — this is the likeliest future bug
in the codebase.

**Suppression order** (D-023): aggregate across all facilities first, then suppress. Tables
withhold the count and keep the row; funnel plots keep the point and withhold the label. Never
remove a facility before the pooled mean and control limits are computed.

**`plotly` for funnel plots only** (D-014). It rewrites more than you expect: `subtitle` and
`caption` are dropped (I-004) and legend trace names compound every discrete aesthetic
including `group` (I-023). Check rendered output, not the RStudio plot pane.

**`R/` is auto-sourced by Shiny on startup** (D-025) — definitions and constants only, no side
effects beyond `theme_set()` in `theme.R`. `dependencies.R` stays at the root for this reason.

**The report layout is settled** (D-035): `facility-report.qmd` lives at the repository root,
not in `report/`. Moving it breaks the Connect Cloud primary-file binding.

---

## 8. Remaining schedule

| Day | Date | Milestone |
|---|---|---|
| 4 | 20–23 Aug | **Shiny app** replaces the probe. Metadata-driven stratifier menu (D-008), S1 trend reveal (D-038), suppression visible (D-039). |
| 5 | 24 Aug | Persona switcher (D-004), polish, **full dress rehearsal on the demo machine**. |

Two days of slack exist. The most valuable use of it is **I-008 and I-010**: rehearse the
push-to-redeploy cycle from the actual presentation machine on the actual network, and record a
screen capture as a fallback. A rehearsal is worth more than another feature.
