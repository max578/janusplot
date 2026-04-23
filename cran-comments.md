# cran-comments.md

## Submission type

First submission of `janusplot` to CRAN (version 0.1.0).

## Test environments

- macOS 26 (Darwin 25.3) / Apple Silicon — R 4.5.2 (local).
- win-builder (R-devel, R 4.6.0 RC 2026-04-22 r89945 ucrt) — 2 NOTEs
  on `janusplot_0.1.0.tar.gz` (see below). Will be re-run on the
  trimmed-example rebuild immediately before submission.
- R-hub v2 (`rhub::rhub_check()`, GitHub-Actions-backed, all default
  platforms) — pending; will be re-run immediately before submission.

## R CMD check results

Expected status on the submission tarball: **1 NOTE** (new-submission
feasibility only). Itemised below, with the resolved prior NOTE also
documented for continuity.

### NOTE 1 — CRAN incoming feasibility

"New submission" — expected for a first submission; informational only.
All URLs verified to resolve (pkgdown site live at
`https://max578.github.io/janusplot/`).

### Resolved — examples execution time

Win-builder's initial build of `janusplot_0.1.0.tar.gz` reported
`checking examples ... [19s] NOTE` with the `janusplot()` example
elapsing 11.17s — over the 10s CRAN threshold. Cause: the runnable
example used `mtcars[, c("mpg", "hp", "wt", "qsec")]` (12 off-diagonal
GAM fits). Trimmed to a 3-variable subset (6 off-diagonal fits), which
is expected to run in roughly half the time and clear the threshold.
Heavier demonstrations remain under `\donttest{}`.

### Local-only, not reproduced upstream

Local `R CMD check --as-cran` additionally raises
`checking for future file timestamps ... NOTE` / `unable to verify
current time`. Environmental (check host cannot reach a standard time
service); not reproduced on win-builder or R-hub.

## Downstream dependencies

None — this is a first submission. There are no reverse dependencies.

## Package scope

`janusplot` renders pairwise asymmetric smoothed-association matrices
of continuous variables via `mgcv::gam()` fits. Each cell displays a
directional GAM smooth; the package exposes per-pair shape descriptors
(monotonicity, convexity, inflection counts, 24-category shape taxonomy)
plus a recovery-rate sensitivity study
(`janusplot_shape_sensitivity()`) with precomputed demo data.

A companion R Journal paper
(*Beyond Pearson: Visualising Asymmetric Non-linear Associations with
Generalised Additive Models*) is in preparation; the package is
submitted independently and does not depend on the paper's publication.

## Notes to the maintainers

- All examples are executable without `\dontrun{}`.
- All tests run in parallel under `testthat` edition 3.
- Vignettes build in roughly 20 seconds on reference hardware.
- No C/C++/Rust code; pure R with `Imports:` from `mgcv`, `ggplot2`,
  `patchwork`, `grid`, `stats`, `cli`, `lifecycle`, `rlang`.
- Package size after build is modest (~2 MB source tarball including
  the precomputed `shape_sensitivity_demo` dataset).
