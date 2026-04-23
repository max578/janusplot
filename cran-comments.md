# cran-comments.md

## Submission type

First submission of `janusplot` to CRAN (version 0.1.0).

## Test environments

- macOS 26 (Darwin 25.3) / Apple Silicon — R 4.5.2 (local).
- win-builder (R-devel) — pending; will be re-run immediately before submission.
- R-hub v2 (`rhub::rhub_check()`, GitHub-Actions-backed, all default
  platforms) — pending; will be re-run immediately before submission.

## R CMD check results

Local `R CMD check --as-cran` with `--no-manual`:

```
Status: 2 NOTEs
  * checking CRAN incoming feasibility ... NOTE
  * checking for future file timestamps ... NOTE
```

Each NOTE is itemised and justified below.

### NOTE 1 — CRAN incoming feasibility

Sub-items reported by `R CMD check --as-cran`:

* **"New submission"** — expected for a first submission; informational
  only.
* **"Found the following (possibly) invalid URLs: `https://max578.github.io/janusplot/`"** —
  the pkgdown site is deployed by the `pkgdown.yaml` GitHub Actions
  workflow on push to `main`. At the moment of this local check the
  site had not yet finished deploying; the URL resolves within a few
  minutes of the release push and has been verified to resolve before
  this submission is sent. The URL is retained in `DESCRIPTION`,
  `README.md`, `CITATION.cff`, and `man/janusplot-package.Rd` because
  it is the canonical documentation site for the package.

### NOTE 2 — Future file timestamps

`checking for future file timestamps ... NOTE` / `unable to verify
current time`. Environmental: raised when the check host cannot reach
a standard time service. Not a package defect; does not appear on
win-builder or R-hub runs.

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
