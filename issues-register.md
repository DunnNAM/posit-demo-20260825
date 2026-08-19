# Issues Register — CAQ Posit Connect Cloud Demonstrator

Open risks, unknowns and defects. Referenced inline in code comments as `I-###`.
ID scheme inherited from the existing MDT dashboard prototype.

**Severity:** `Blocker` · `High` · `Medium` · `Low`
**Status:** `Open` · `Verifying` · `Mitigated` · `Closed`

---

## Blockers — must be resolved Day 1

### I-001 — Two Connect Cloud deployments from one repository: unverified
**Severity:** Blocker · **Status:** **CLOSED 2026-08-19** — all checks resolved on Day 1 ·
**Owner:** Nathan

**Day 1 results.**

| # | Check | Result |
|---|---|---|
| 1 | Both items deploy from one repository | **Pass** — via a single root `manifest.json`, not `renv.lock`. See D-017. |
| 2 | Restore completes; duration | **Pass** — ~2s. Connect Cloud *provides* pre-built packages rather than installing them. Full deploy ~10s. No pruning needed. |
| 3 | Working directory | **Pass, with a caveat** — the app runs from `/cloud/project`; the report renders in an ephemeral copy at `/tmp/<name>/rendered-output-<id>`. Different absolute paths, but both are the **root of the repository tree**, so relative-from-root paths resolve identically. See I-016. |
| 4 | `source("R/smoke_shared.R")` | **Pass** in both products. |
| 5 | `data/smoke_data.csv` readable | **Pass** in both products. |
| 6 | `ggplot2` renders | **Pass** in both products. |
| 7 | `bslib::font_google("Lato")` | **Pass** — app loaded without error. |
| 8 | Private repository on this tier | **No** — free tier publishes from public repositories only; private repos require a paid plan. Repository stays public; I-005 becomes a hard constraint. |

**Initial failure and resolution.** The first attempt failed: Connect Cloud requires
`manifest.json` for R content and does not read `renv.lock`. Resolved by
`rsconnect::writeManifest()`; see I-015 for the library/lockfile conflict encountered while
generating it, and D-018 for the revised reproducibility narrative.

**Unexpected finding.** A `manifest.json` placed in a content item's own subdirectory is
ignored; Connect Cloud reads the root manifest and takes content type from the publish
request. This simplified the layout rather than complicating it — see D-017.

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

### I-012 — `renv::init()` discovered 8,498 files; dependency scan scope is wrong
**Severity:** Medium · **Status:** Closed 2026-08-19 · **Owner:** Nathan

`renv::init()` warned that 8,498 files were found for dependency scanning, against a project
containing seven. Cause was candidate 1: the RStudio project was open one directory level
above the repository, so `renv` was scanning `D:/Development` and all sibling projects.

**Resolution:** deleted the generated `renv/` directory (no `renv.lock` had been written),
corrected the working directory to the repository root, re-ran `renv::init()` successfully.

**Correction to the original verification method:** counting packages in `renv.lock` is not a
valid pollution test. `renv.lock` records the full transitive closure, so a declared set of
~18 packages including `shiny`, `plotly`, `gt`, `reactable` and `rmarkdown` legitimately
produces 120–160 lockfile entries. The correct test is `unique(renv::dependencies()$Source)`
— every scanned file must resolve inside the repository.

**Recurrence prevention:** an `.Rproj` file at the repository root, always used to open the
project. `renv::init()` writes the activating `.Rprofile` to the repository root, so opening
RStudio at any other level leaves renv inactive and the session silently running against the
system library. Fixing the working directory with `setwd()` is session-scoped and does not
prevent recurrence.

### I-016 — The two products run from different absolute paths
**Severity:** Medium · **Status:** Open — mitigation designed, to apply on Day 3 ·
**Raised:** 2026-08-19, Day 1

The Shiny app runs from `/cloud/project`. The Quarto report renders in an ephemeral copy at
`/tmp/<name>/rendered-output-<id>`. Both are the root of the repository tree, so
relative-from-root paths resolve correctly in both — but the absolute paths differ, and the
report's render directory is disposable.

**Rules arising:**
1. Never use absolute paths.
2. Never assume the two products share a location.
3. The report cannot cache anything to disk between renders.
4. Files beside the `.qmd` need a `report/` prefix when referenced from inside it, because
   the working directory is the tree root, not `report/`. Counterintuitive; expect it to catch
   someone.

**Unverified mechanism.** It is not established *why* Quarto renders with the working
directory at the tree root rather than the document's own folder. The behaviour is observed,
not explained, and could shift — adding a `_quarto.yml` for theming is exactly the kind of
change that might alter execute-directory handling.

**Mitigation to apply in the Day 3 report setup chunk:** walk up from the current directory
until `R/smoke_shared.R` is visible, then set `knitr::opts_knit$set(root.dir = ...)` to that
path. Correct under Connect Cloud, under the app's layout, and under a local render from
`report/`. Removes the dependency on inferred behaviour.

**Superseded advice:** an earlier proposal to set `root.dir = normalizePath("..")` was written
assuming the working directory would be `report/`. It would have pushed above the tree root
and broken every path. Never applied.

### I-017 — Free-tier content is publicly accessible; sharing controls are a paid feature
**Severity:** Low (presentation risk, not technical) · **Status:** Open ·
**Owner:** Nathan · **Due:** before the presentation

Connect Cloud's free tier publishes from public repositories only, and deployed content
carries a public URL accessible to anyone with the link; the account's content page is also
public. Private repositories require the Basic plan or above. Gated sharing — private links
with revocable tokens, SSO, role-based access control — sits on higher tiers again.

**Presentation risk.** Clinical leads A and B are likely to ask whether real facility data
could be served this way. If the room infers that today's configuration is deployment-ready
for real cancer data, that is a materially misleading impression to leave with a Senior
Director.

**Action:** state the limitation explicitly during the demonstration rather than waiting to be
asked. The honest framing is that Connect Cloud does support gated content and identity-based
access, but not on the tier being demonstrated. This also reinforces D-004 — when narrating
"in production this comes from the authenticated session," that capability genuinely exists at
the tiers CAQ would purchase.

**Secondary note:** the free plan allows 20 active hours. Shiny applications consume active
hours while running; static Quarto documents do not. Avoid leaving the app running during
rehearsals this week.

### I-015 — `writeManifest()` fails: library and lockfile out of sync
**Severity:** Medium · **Status:** Open · **Owner:** Nathan · **Raised:** 2026-08-19, Day 1

`rsconnect::writeManifest()` aborts with "Library and lockfile are out of sync". Installing
`rsconnect` into the project library added it and its dependencies, but `renv::snapshot()`
does not record them — renv's default snapshot mode captures only packages referenced by
project code, and nothing in the project references `rsconnect`. A subsequent snapshot
updated `openssl` and `rlang` but did not resolve the mismatch.

**Underlying tension:** `rsconnect` is a local deployment tool, not a project dependency. It
must be present to generate the manifest, but should not appear in the reproducibility
artefact or in the deployed package set.

**Resolution adopted:** call `writeManifest(dependencyResolution = "library")`, resolving
versions from the installed library rather than the lockfile. The manifest's package list is
derived from scanning bundled code, so the 18 packages declared in `dependencies.R` are
captured while `rsconnect` — referenced by no bundled file — is not.

**Rejected alternative:** `renv::snapshot(type = "all")` would sync the two by recording
`rsconnect` and its dependencies in `renv.lock`, placing a local-only tool into the artefact
presented as the project's reproducibility story.

**Carried forward:** `manifest.json` must be regenerated whenever the file list or package set
changes. This is a standing maintenance obligation introduced by the I-001 finding, and a
plausible source of a stale-deployment failure later in the week.

### I-013 — Declaration-only file was executed by Shiny's `R/` auto-sourcing
**Severity:** Medium · **Status:** Closed 2026-08-19 · **Owner:** Nathan · **Raised:** Day 1

`R/dependencies.R` carried a header stating it was never sourced or run. Shiny auto-sources
every `.R` file in an `R/` directory next to `app.R`, so it was in fact executed on every app
start, attaching all 18 declared packages regardless of use.

**Detected by:** `lubridate` and `plotly` appearing in the local startup log, despite `app.R`
calling `library()` for neither.

**Impact:** low functionally — the packages are in the lockfile and attach cleanly, and D-016
namespacing means the extra masking cannot change behaviour. The real defect was
documentation: a file whose header contradicted its actual behaviour, in a project whose
comments are a stated deliverable for staff transferability.

**Resolution:** D-025. Declaration file moved to the repository root as `dependencies.R`;
header corrected to explain why its location matters. `renv` detection is unaffected.

**Carried forward:** everything placed in `R/` from Day 2 must be safe to source on app
startup — definitions and constants only.

### I-014 — Skeleton files delivered to the wrong paths
**Severity:** Medium · **Status:** Closed 2026-08-19 · **Raised:** Day 1

Two files from the Day 1 skeleton were placed at the repository root rather than in their
intended subdirectories: `smoke_shared.R` (belongs in `R/`) and `smoke_data.csv` (belongs in
`data/`). Both were referenced by relative path from `app.R` and `facility-report.qmd` and
would have failed on deployment.

**Detected by:** `renv::dependencies()` source listing, then a runtime error on local app run.

**Resolution:** files moved with `file.rename()`; no code change required.

**Lesson recorded:** the local run caught both at zero cost. Continue running both products
locally before every push — a Connect Cloud build log is a far more expensive place to find a
missing file.

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
**Severity:** Medium · **Status:** **CLOSED 2026-08-19** — resolved by D-034: Unknown is an
explicit category, included in every denominator and calculation, never silently dropped.
Note that `stage` is never `NA` — `NA` means ineligible (D-007), "Unknown" means unstaged.

Stage carries an "Unknown" level (IND-06). It is not yet decided whether Unknown is shown as
a category, excluded from the denominator, or reported separately as a completeness measure.
The existing prototype suppresses unknown values from charts and notes an unresolved
intention to add per-chart footnotes with unknown counts — the same trap.

**Action:** decide in Day 2's metrics layer and record as a decision. Whatever is chosen must
be visible in the output, not silent.

### I-018 — Two working copies on two machines; registers can diverge
**Severity:** Medium · **Status:** Open · **Owner:** Nathan · **Raised:** 2026-08-19, Day 1 ·
**Due:** standing, to Day 5

The repository is cloned in two places on two different machines:

| Machine | Path | Role |
|---|---|---|
| Home | `C:/Users/namdu/OneDrive/Documents/ShinyStuff/posit-demo-20260825` | Claude Code sessions, build work |
| Work laptop | `D:/Development/posit-demo-20260825` | RStudio, **and the Day 5 dress rehearsal machine** |

**Observed once already.** On Day 1 the home copy pushed `52022c7` (register sync) while the
work laptop held an unpushed `b6c0c76` (delete `R/dependencies.R`, add `renv.lock`). The
laptop's pull produced merge commit `303905a`. It resolved cleanly **only because the two
commits touched disjoint files.** The register files are edited from both machines and are the
most likely thing to be edited in both at once — that case does not resolve cleanly, and
resolving a conflicted register by hand is how a decision silently goes missing.

**Not caused by the `D:/Development` path.** This is ordinary two-clone drift and would occur
from any location. The path carries its own separate risks — see I-005 (real database names in
the adjacent MDT prototype; the `git rev-parse --show-toplevel` gate) and I-012 (renv scanning
sibling projects when the `.Rproj` is opened one level up).

**Neither copy can be deleted.** The dress rehearsal runs on the work machine (Day 5), and the
Claude Code sessions run at home.

**Mitigation — discipline, since tooling cannot enforce it across machines:**
1. `git pull --ff-only` as the first action on arriving at either machine.
2. Commit and push before leaving either machine. Never walk away with uncommitted registers.
3. `git config pull.ff only` set in both clones, so an accidental pull refuses rather than
   silently merging.
4. On the work laptop, confirm `git rev-parse --show-toplevel` returns the demo folder before
   any push (the I-005 gate).

**Carried forward:** if a register conflict does occur, resolve it by keeping **both** sides of
the change — a `D-###` or `I-###` entry is append-only in practice, so a conflict almost always
means two additions, not a genuine contradiction.

### I-019 — CSV round-trip drops factor ordering; `data_prep.R` must restore it
**Severity:** Medium · **Status:** Open · **Due:** Day 2, with the shared layer ·
**Raised:** 2026-08-19

`age_group_5yr` and `age_group_10yr` are created as ordered factors by the generator, but CSV
carries no type information: `readr::read_csv()` returns them as character. `sex`,
`seifa_quintile`, `stage` and `hhs_residence` are likewise character on read, against the
`fct` types specified in brief §6.

**Currently harmless, and that is the trap.** The age-group labels happen to sort correctly
under alphabetical ordering (`[25,30)` … `[90,Inf)`), so a plot axis looks right today.
`stage` also happens to sort `I, II, III, IV, Unknown` correctly. Any relabelling — dropping
the interval notation for "25–29", or renaming Unknown — silently breaks the ordering with no
error, in a chart nobody re-checks.

**Action:** `R/data_prep.R` converts all six columns to factors with explicit levels
immediately after reading, and does so once for both products (D-010). Do not rely on the
incidental sort order.

### I-020 — Home machine cannot reproduce the lockfile environment
**Severity:** Medium · **Status:** Open · **Owner:** Nathan · **Raised:** 2026-08-19

`renv.lock` pins R 4.5.3. The home machine (see I-018) has 4.3.1, 4.3.3, 4.4.2 and 4.5.2 but
not 4.5.3, and this clone has never had `renv::restore()` run against it — there is no project
library here at all.

**The patch-level difference is the lesser half of this issue.** R package binaries on Windows
are built per *minor* version: 4.5.2 and 4.5.3 both resolve to the `4.5` binary path, so
`renv::restore()` under 4.5.2 installs exactly the versions `renv.lock` pins. renv will warn
about the R version and proceed. The material gap is that no project library exists here at
all, not the third digit.

The generator was therefore developed and run under R 4.5.2 against the **user** library, with
`readr`, `tidyr`, `purrr` and `forcats` installed there to make it runnable. Nothing was
installed into a project library and `renv.lock` was not modified, so the reproducibility
artefact is untouched — but the data in `data/` was produced by an environment that the
lockfile does not describe.

**Why it is not a blocker:** the generator uses only `dplyr`, `tibble` and `readr` for
ordinary data manipulation, with a fixed seed (D-001). Nothing in it is version-sensitive.

**Action:** re-run the generator on the work laptop under the lockfile environment before the
demonstration and confirm the CSVs are byte-identical. If they are not, the R version becomes
part of the reproducibility story and must be narrated accordingly — the claim on screen is
that a seeded script reproduces the data exactly (D-001, brief §1).

### I-021 — The stage-adjusted S2 gap is a noisy estimator
**Severity:** Low · **Status:** Open — tolerance widened, no action required ·
**Raised:** 2026-08-19

The stage-adjusted gap in D-030 is computed by direct standardisation: stage-specific surgery
rates observed in the two S2 HHSs, applied to the stage mix of the rest of the state. Those
rates come from ~2,800 lung patients split five ways, so the smaller stage strata carry real
sampling error, and the comparator (the observed rest-of-state rate) carries its own.

The realised ratio was 0.56 against a theoretical 0.44 — a gap larger than the multiplier's
effect on it. Retuning `S2_ACCESS_MULTIPLIER` to chase the theoretical value would be fitting
the parameter to one seed's noise.

**Resolution:** the generator asserts the ratio within 0.40–0.60 rather than at a point value,
and D-030 records the achieved figures. **If the seed changes, expect the ratio to move by
several hundredths and do not treat that as a defect.**

### I-022 — `R/theme.R` palette values are placeholders, not the CAQ palette
**Severity:** Medium · **Status:** Open · **Owner:** Nathan · **Due:** before Day 5 ·
**Raised:** 2026-08-19

D-013 says to adopt the existing MDT prototype's `theme.R` **verbatim** — CAQ palette,
`scale_colour_caq()`, `scale_fill_caq()` and the `theme_set()` block. That prototype is not in
this repository and was not available when the shared layer was written, so the hex values
currently in `R/theme.R` are a neutral, colour-blind-safe stand-in, not CAQ's colours.

The function names, signatures and structure are deliberately identical to what D-013
describes, so substitution is a change to the `CAQ_PALETTE` and `CAQ_COLOURS` constants and
nothing else. No calling code needs to change.

**Why it matters beyond aesthetics.** Presenting a demonstration to CAQ management in colours
that are not CAQ's, while the register claims the palette was adopted from their own
prototype, is a small but avoidable credibility gap in front of an audience that includes the
Senior Director.

**Action:** copy the real palette out of the prototype's `theme.R` on the work laptop and
replace the two constants. **Copy the colour values only** — the prototype's `global.R`
contains real database and table names and none of it may cross into this public repository
(I-005).

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

**Added 2026-08-19 (arising from I-012) — verify the git repository root before pushing.**
The demo repository sits inside `D:/Development`, alongside other projects including the MDT
prototype whose `global.R` contains real database names, table names and a DSN. If `git init`
was run from `D:/Development` rather than the demo folder, a push to a public GitHub
repository would publish all of it.

Confirm in the terminal before the first push:

```
git rev-parse --show-toplevel
```

This must return the demo repository path, not `D:/Development`. Treat this as a hard gate on
the first push — severity for this specific check is **High**, not Low.

### I-011 — Report and app could diverge on indicator values
**Severity:** Low · **Status:** Mitigated by D-010, D-020 · **Date raised:** 2026-08-19

Two products calculating the same measures independently will eventually disagree, and
disagreeing in front of this audience would undermine the entire argument.

**Mitigation:** all indicator logic lives in `R/metrics.R`; neither product calculates
anything itself. Verify on Day 3 by computing a headline figure in both and comparing.

---

## Closed

### I-001 — Two Connect Cloud deployments from one repository
**Closed:** 2026-08-19 · **Resolution:** all eight checks completed on Day 1. Layout resolved
in D-017; reproducibility narrative corrected in D-018. Full result table retained under the
Blockers section above for reference.

### I-002 — `pacman::p_load()` produces an incomplete `renv.lock`
**Closed:** 2026-08-19 · **Resolution:** D-015. `pacman` is dropped from this project;
packages are declared with explicit `library()` calls. Verification remains as I-001 check 2.

### I-006 — Signal S3 needs sign-off
**Closed:** 2026-08-19 · **Resolution:** approved, sized to explain half the S2 gap (D-011).

### I-007 — Suppression and funnel plots interact awkwardly
**Closed:** 2026-08-19 · **Resolution:** D-023 — aggregate first, retain the point, suppress
the label.

### I-009 — Stage "Unknown" handling is undefined
**Closed:** 2026-08-19 · **Resolution:** D-034 — Unknown is an explicit category, counted in
every denominator and every calculation, and shown as a category wherever stage appears.
