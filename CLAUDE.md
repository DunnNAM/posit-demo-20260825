# CLAUDE.md — CAQ Posit Connect Cloud demonstrator

Read this first, every session. Then read `HANDOVER.md` for current state, and consult
`project-brief.md`, `decision-register.md` and `issues-register.md` as needed.

---

## What this project is

A five-day build for **Cancer Alliance Queensland**. Synthetic cancer-indicator data feeding a
Quarto HTML report and a Shiny dashboard, both published to **Posit Connect Cloud** from a
public GitHub repository, demonstrated live to CAQ management on **24 August 2026**.

**The subject is the publishing workflow and the platform, not the clinical findings.** All
data is invented. Design choices serve the demonstration.

---

## Working agreement — follow these strictly

1. **Do not write code until the approach is agreed.** Propose, get confirmation, then build.
   This is the user's explicit standing instruction, not a suggestion.
2. **Data first.** The underlying data content and structure are settled before any Quarto or
   Shiny work. Do not jump ahead to building content.
3. **Every change to scope, data or code is recorded** in `decision-register.md` (`D-###`) or
   `issues-register.md` (`I-###`), in the same commit as the change. These files are the
   session-to-session memory — if it isn't written down, it didn't happen.
4. **Reference register IDs inline in code comments** (e.g. `# Aggregate first (D-023)`), so
   the reasoning survives contact with the next reader.

---

## Code conventions — non-negotiable

- **Namespace every function call**: `dplyr::filter()`, `ggplot2::geom_line()`,
  `readr::read_csv()`. Exceptions: the pipe, and `ggplot2` layer composition with `+`.
- **Explicit `library()` calls. Never `pacman::p_load()`** (D-015). `renv` and
  `rsconnect` discover dependencies by static analysis and cannot see packages passed as bare
  symbols to `p_load()`.
- **Comment for transferability.** Staff other than the author will maintain this. Explain
  *why*, not *what*.
- **Tidyverse idiom** where reasonable. The user is an intermediate-to-advanced R programmer —
  be concise and skip beginner explanation.
- **Never invent packages or functions.** If unsure whether something exists or is deprecated,
  say so rather than guessing.
- **`dependencies.R` at the repository root is a declaration file — never sourced, never run**
  (D-025). It exists so `renv` and `rsconnect` see the full package set. It must **not** live
  in `R/`, because Shiny auto-sources everything in `R/`.
- **Everything in `R/` is auto-sourced by Shiny on startup** (D-025). Definitions and constants
  only — no side effects beyond `ggplot2::theme_set()`.

---

## Hard constraints

- **The repository is PUBLIC** and the Connect Cloud free tier only publishes from public
  repos (I-005, I-017). **No real database names, table names, schema structures, server
  names, DSNs or credentials anywhere — including in comments.** An earlier CAQ prototype
  shared with the assistant contained these; none of it may be copied across.
- **No database code.** No `DBI`, no `odbc`, no `USE_REAL_DATA` flag (D-003).
- **No claim of clinical validity.** A synthetic-data statement appears on the landing view of
  both products (D-002).
- **Indicator logic lives in `R/` and is calculated once.** Neither the report nor the app
  computes its own numbers (D-010, I-011).

---

## Repository layout (D-017 — resolved by Day 1 deployment evidence)

```
/app.R                        Shiny entry point (Connect Cloud primary file)
/manifest.json                SINGLE root manifest — union of both products' packages
/dependencies.R               Declaration only. Never sourced.
/renv.lock                    Local reproducibility. NOT read by Connect Cloud.
/R/                           Shared layer — ONE canonical copy, used by both products
/data/                        Committed synthetic CSVs
/data-raw/                    Seeded generator script
/report/facility-report.qmd   Quarto entry point (Connect Cloud primary file)
/project-brief.md /decision-register.md /issues-register.md /HANDOVER.md
```

---

## Deployment facts — learned empirically on Day 1, do not re-derive

- Connect Cloud requires **`manifest.json`** for R content. It **does not read `renv.lock`**,
  and explicitly truncates `renv/activate.R` to prevent renv activation (D-018).
- **A manifest in a content item's subdirectory is IGNORED.** Connect Cloud reads the root
  manifest and takes content type from the publish request, tolerating a mismatch.
- Connect Cloud performs a **full `git clone`** of the repository. The manifest's file list
  does **not** filter the bundle, so both products reach `R/` and `data/` at the root.
- **Working directories differ between products but are both the tree root** (I-016):
  app runs from `/cloud/project`; the report renders in an ephemeral
  `/tmp/<name>/rendered-output-<id>`. Use relative-from-root paths only. Never absolute.
- Packages are **provided pre-built**, not compiled: ~2s for 94 packages, ~10s total deploy.
  No need to prune the dependency set.

### Regenerating the manifest — required whenever files or packages change

```r
rsconnect::writeManifest(dependencyResolution = "library")
```

`dependencyResolution = "library"` is required (I-015): installing `rsconnect` into the
project library desynchronises it from `renv.lock`, and this bypasses the lockfile without
polluting it with a local-only tool.

---

## Local commands

```r
renv::restore()                                   # restore environment
shiny::runApp()                                   # run the app
```

```
quarto render report/facility-report.qmd          # render the report (CLI, not the R package)
```

**Do not use `quarto::quarto_render()`** (D-026) — the `quarto` R package is deliberately not
a project dependency. Use the CLI or RStudio's Render button.

**Always run both products locally before pushing.** Two path bugs were caught this way on
Day 1 at zero cost (I-014).

---

## Presentation accuracy — matters, the audience includes two technical leads

- **Do not claim Connect Cloud restores `renv.lock`.** It does not (D-018). The accurate line:
  `renv` pins the environment locally, `writeManifest()` transfers those pins into
  `manifest.json`, and Connect Cloud provisions from that.
- **Do not imply the current setup is deployment-ready for real patient data** (I-017). Free
  tier content is publicly accessible. Gated sharing, SSO and RBAC exist — on higher tiers.
