# Issues Register — CAQ Posit Connect Cloud Demonstrator

Open risks, unknowns and defects. Referenced inline in code comments as `I-###`.
ID scheme inherited from the existing MDT dashboard prototype.

**Severity:** `Blocker` · `High` · `Medium` · `Low`
**Status:** `Open` · `Verifying` · `Mitigated` · `Closed`

---

## Blockers — must be resolved Day 1

### I-001 — Two Connect Cloud deployments from one repository: unverified
**Severity:** Blocker · **Status:** Verifying — probe written, awaiting deployment ·
**Owner:** Nathan · **Due:** Day 1

Connect Cloud deploys content from a Git repository by selecting a repo, branch and primary
file. It is **not confirmed** that a single `renv.lock` at the repository root serves two
separate deployments (a `.qmd` and an `app.R`) from the same repo, nor how the working
directory is set for each.

**I do not know the current Connect Cloud behaviour here with confidence and will not guess.**
This must be tested empirically, not reasoned about.

**Action:** the Day 1 probe (`app.R` + `facility-report.qmd`, placeholder content per D-024)
is written and ready to push. Deploy both from the same repository and tick off:

| # | Check | Why it matters |
|---|---|---|
| 1 | Both content items deploy from one root `renv.lock` | If not, the repo must be split (fallback below) |
| 2 | `renv` restore completes, and how long it takes | Heavy packages (`plotly`, `gt`, `reactable`) are in the probe deliberately to time this |
| 3 | Each product reports its working directory | Confirms the D-017 flat-root assumption |
| 4 | `source("R/smoke_shared.R")` succeeds in both | The shared indicator layer depends on this |
| 5 | `readr::read_csv("data/smoke_data.csv")` succeeds in both | Committed data must be reachable post-deploy |
| 6 | A `ggplot2` plot renders in both | Graphics device present on the build host |
| 7 | `bslib::font_google("Lato")` resolves in the app | Network font dependency (I-003) |
| 8 | Whether a private repository is supported on this account tier | Determines whether the schema stays public (I-005) |

Record the answers against this table in the register — do not rely on memory.

**Fallback if check 1 fails:** two separate repositories, with the shared `R/` layer
duplicated and kept in sync manually for the duration of the demo. Ugly, but survivable.
**Fallback if check 2 is slow:** prune the probe's dependency declaration to the minimum set
and drop `gt`/`reactable` in favour of base `knitr::kable()` and `DT`.

### I-002 — `pacman::p_load()` produces an incomplete `renv.lock`
**Severity:** Blocker · **Status:** Mitigated by D-015 · **Date raised:** 2026-08-19

The existing prototype's `global.R` loads all packages via `pacman::p_load()`. `renv`
discovers dependencies through static analysis of `library()`, `require()` and `::` calls;
bare symbols inside `p_load()` are not detected. Carrying this pattern across would produce
a lockfile missing most dependencies and a restore failure on deployment.

**Mitigation:** D-015 — explicit `library()` calls. `pacman` is not used in this project.
**Verification:** after writing `app.R`, run `renv::snapshot()` and confirm every package
appears in the lockfile. Do not assume.

---

## High

### I-003 — Google Fonts require network access at render time
**Severity:** High · **Status:** Mitigated by D-022; residual risk under test (I-001 check 7)
· **Due:** Day 1

The existing prototype calls `sysfonts::font_add_google("Lato")` plus `showtext_auto()`, and
`bslib::font_google("Lato")` in the theme. Both fetch font resources over the network. On
Connect Cloud this happens on the build/render host, and behaviour is not confirmed.
`showtext` additionally interacts with plot DPI in ways that can silently change text sizing
between local RStudio and a deployed render.

**Action:** include a `font_add_google()` call in the Day 1 trivial deployment test.
**Fallback:** drop `showtext` entirely and let `bslib` handle web fonts for the app while the
report uses a system sans-serif. Visual cost is minor; the risk of a broken render on demo
day is not.

### I-008 — Live demo depends on network, GitHub and Connect Cloud availability
**Severity:** High · **Status:** Open · **Due:** Day 5

The centrepiece — push to GitHub, redeploy, refresh — fails completely without connectivity
to both services from the presentation room.

**Mitigation:**
1. Test from the actual presentation machine on the actual network before Day 5
2. Record a short screen capture of a successful push-to-deploy cycle as a fallback
3. Have the deployed URLs already open in browser tabs before presenting

### I-010 — No deployment rehearsal until Day 5
**Severity:** High · **Status:** Open

The plan back-loads the full dress rehearsal. Any Day 5 discovery has no recovery time.

**Mitigation:** deploy *something* every day from Day 1. The repository should never go more
than 24 hours without a successful Connect Cloud deployment.

---

## Medium

### I-004 — `ggplotly()` drops `subtitle` and `caption`
**Severity:** Medium · **Status:** Mitigated by D-014 · **Date raised:** 2026-08-19

`plotly::ggplotly()` does not carry `labs(subtitle=)` or `labs(caption=)` through from the
`ggplot` object. Under D-012, funnel plots are the charts most likely to need a suppression
footnote — and under D-014 they are the only charts using `plotly`.

**Mitigation:** render footnotes as separate `htmltools` text beneath the plot, not as plot
captions. Applies to funnel plots only.

### I-006 — Signal S3 needs sign-off before the generator is written
**Severity:** Medium · **Status:** Closed 2026-08-19 — approved at half-the-gap sizing (D-011)

S3 (later stage distribution in the two low-surgery-rate lung HHSs) is proposed but not
agreed. It changes the generator's dependency structure — stage must be conditioned on
residence HHS for lung, and surgery probability conditioned on stage.

**Design intent if approved:** size the effect so stage explains roughly half the S2 gap.
Fully explaining it makes the service-access story disappear; not explaining it at all
wastes the drill-down.

### I-007 — Suppression and funnel plots interact awkwardly
**Severity:** Medium · **Status:** Mitigated by D-023 · **Date closed:** 2026-08-19

Funnel plots derive value from including low-volume facilities — that is what the widening
control limits illustrate. Suppressing n < 5 removes exactly those points. Removing a
facility from a funnel plot also changes the pooled mean line if suppression is applied
before aggregation.

**Action:** decide and document the order of operations — aggregate first, then suppress the
*label*, retaining the point. Confirm this is acceptable under CAQ convention.

### I-009 — Stage "Unknown" handling is undefined
**Severity:** Medium · **Status:** Open · **Due:** Day 2

Stage carries an "Unknown" level (IND-06). It is not yet decided whether Unknown is shown as
a category, excluded from the denominator, or reported separately as a completeness measure.
The existing prototype suppresses unknown values from charts and notes an unresolved
intention to add per-chart footnotes with unknown counts — the same trap.

**Action:** decide in Day 2's metrics layer and record as a decision. Whatever is chosen must
be visible in the output, not silent.

---

## Low

### I-005 — Public repository content review
**Severity:** Low · **Status:** Open · **Owner:** Nathan · **Due:** before first push

The repository is public. Facility names, HHS names, indicator definitions and schema
structure will all be visible. Nathan's stated intent is to design the synthetic data so it
neither replicates real-world results nor exposes sensitive database architecture.

**Action:** before the first push, confirm that facility names are clearly fictional (or
clearly generic), that no table/column names mirror the real warehouse, and that no
connection strings, DSNs or server names appear anywhere — including in comments. Note that
the existing prototype's `global.R` contains real database and table names; **none of it
should be copied across**.

### I-011 — Report and app could diverge on indicator values
**Severity:** Low · **Status:** Mitigated by D-010, D-020 · **Date raised:** 2026-08-19

Two products calculating the same measures independently will eventually disagree, and
disagreeing in front of this audience would undermine the entire argument.

**Mitigation:** all indicator logic lives in `R/metrics.R`; neither product calculates
anything itself. Verify on Day 3 by computing a headline figure in both and comparing.

---

## Closed

### I-002 — `pacman::p_load()` produces an incomplete `renv.lock`
**Closed:** 2026-08-19 · **Resolution:** D-015. `pacman` is dropped from this project;
packages are declared with explicit `library()` calls. Verification remains as I-001 check 2.

### I-006 — Signal S3 needs sign-off
**Closed:** 2026-08-19 · **Resolution:** approved, sized to explain half the S2 gap (D-011).

### I-007 — Suppression and funnel plots interact awkwardly
**Closed:** 2026-08-19 · **Resolution:** D-023 — aggregate first, retain the point, suppress
the label.
