# cran-comments.md

## Submission type

First submission of `janusplot` to CRAN.

## R CMD check results

0 errors | 0 warnings | 1 note (New submission).

## Pre-submission verification

Tested on:

- macOS 26 (Darwin 25.3) / Apple Silicon — R 4.5.2
- `devtools::check_win_devel()` — pending
- `rhub::rhub_check()` — pending

## Downstream dependencies

None — this is a first submission. No reverse-dependencies exist.

## Package scope

`janusplot` renders pairwise asymmetric smoothed-association matrices of
continuous variables via `mgcv::gam()` fits. Each cell displays a directional
GAM smooth, and the package exposes per-pair shape descriptors (monotonicity,
convexity, inflection counts, 24-category shape taxonomy) plus a
sensitivity-study function (`janusplot_shape_sensitivity()`) with precomputed
demo data.

The package pairs with an R Journal paper:
*Beyond Pearson: Visualising Asymmetric Non-linear Associations with
Generalised Additive Models* (in preparation).
