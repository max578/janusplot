# cran-comments.md

## Submission type

Update of `janusplot` from 0.1.1 (published 2026-07-02) to **1.0.0**.
Version 0.2.0 was tagged in the repository but never submitted, so this
release carries its changes as well.

## Summary of changes

- **Licence change from GPL (>= 3) to MIT.** I am the sole author and
  copyright holder; no third-party code is included.
- A fit-once design: `janusplot_fit()` fits every ordered pair of
  variables once and returns an object with `print()`, `summary()` and
  `plot()` methods. `janusplot_pair()`, `janusplot_compare()` and
  `janusplot_direction()` are views of that object, and
  `janusplot_style()` holds the appearance settings.
- `janusplot()` keeps working as a one-call wrapper. Its earlier appearance
  arguments are accepted with a deprecation warning for one release.
  `janusplot_data()` and `janusplot_direction_test()` are deprecated.
  NEWS.md lists every breaking change with the old and new call.
- The shape taxonomy has 27 categories (24 in 0.1.1).

## Suggested package not on CRAN

`kernR` is in `Suggests:` only and is available from
<https://max578.r-universe.dev>, declared in `Additional_repositories:`.
Every use is guarded: `janusplot_direction()` checks
`requireNamespace("kernR", quietly = TRUE)` and stops with an informative
message if it is missing, its example runs only when `kernR` is
installed, and its tests skip without it. Neither vignette uses it.

## Test environments

- macOS 26 (Darwin 25) / Apple Silicon, R 4.6.1 (local).
- win-builder (R-devel and R-release): to be run before submission.
- R-hub v2 (`rhub::rhub_check()`): to be run before submission.

## R CMD check results

Local `R CMD check --as-cran` on the built `janusplot_1.0.0.tar.gz`, with
user profiles disabled: **0 ERRORs, 0 WARNINGs, 0 NOTEs.** With the remote
incoming checks on, the incoming check is expected to report `kernR` as a
suggested package outside the mainstream repositories, available through
`Additional_repositories`.

## Downstream dependencies

There are no reverse dependencies on CRAN.
