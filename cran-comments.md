# cran-comments.md

## Submission type

Update of `janusplot` from 0.1.1 (published 2026-07-02) to **0.2.0**.

## Summary of changes in 0.2.0

- **Licence change from GPL (>= 3) to MIT.** I am the sole author and
  copyright holder; no third-party code is included.
- New exported function `janusplot_direction_test()`, which checks whether
  the residuals of each direction of fit are independent of the putative
  cause. It uses the suggested package `kernR`, which is not on CRAN; see
  below.
- A per-cell fit that errors now carries its message into both returns and
  raises one summary warning per matrix.
- The insufficient-data decline of `janusplot_shape_metrics()` raises a
  classed condition.
- Documentation corrections in both vignettes and the README.

## Suggested package not on CRAN

`kernR` is in `Suggests:` only and is available from
<https://max578.r-universe.dev>, declared in `Additional_repositories:`.
Every use is guarded: `janusplot_direction_test()` checks
`requireNamespace("kernR", quietly = TRUE)` and stops with an informative
message if it is missing, its example runs only when `kernR` is installed,
and its tests call `skip_if_not_installed("kernR")`. Neither vignette uses it.

## Test environments

- macOS 26 (Darwin 25) / Apple Silicon, R 4.6.1 (local).
- win-builder (R-devel and R-release): to be run before submission.
- R-hub v2 (`rhub::rhub_check()`): to be run before submission.

## R CMD check results

Local `R CMD check --as-cran` on the built `janusplot_0.2.0.tar.gz`, with user
profiles disabled and `_R_CHECK_CRAN_INCOMING_REMOTE_=true`:
**0 ERRORs, 0 WARNINGs, 0 NOTEs.** The incoming check reports `kernR` as a
suggested package outside the mainstream repositories, available through
`Additional_repositories`.

## Downstream dependencies

There are no reverse dependencies on CRAN.
