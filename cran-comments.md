# cran-comments.md

## Submission type

Update of `janusplot` from 0.1.0 to **0.1.1**. The current CRAN version is 0.1.0
(published 2026-04-28). This is a minor feature and performance release with no
breaking change to the public API.

## Summary of changes in 0.1.1

- **New `engine = c("bam", "gam")` argument** selecting the `mgcv` fitting
  backend. The default changes from `mgcv::gam` to `mgcv::bam` for a 3-10x
  speed-up at janusplot's scale. This is the single non-byte-identical change:
  `bam`'s fREML estimation differs from `gam`'s REML by ~1-3% in effective
  degrees of freedom, so fitted values, the asymmetry index, and per-cell colour
  fills may shift slightly when a user upgrades. `engine = "gam"` reproduces
  0.1.0 output verbatim; this is documented prominently at the top of `NEWS.md`.
- Per-cell k-checking, scale-aware compact rendering, rendering-only axes modes,
  and figure-to-file output via `save_as`. All strictly additive.
- Internal: shared scalar-argument validation centralised behind one helper;
  test coverage of argument validation extended.

## Test environments

- macOS 26 (Darwin 25) / Apple Silicon -- R 4.5.2 (local).
- win-builder (R-devel and R-release) -- to be re-run immediately before
  submission.
- R-hub v2 (`rhub::rhub_check()`, default platforms) -- to be re-run immediately
  before submission.

## R CMD check results

Local `R CMD check --as-cran` on the built `janusplot_0.1.1.tar.gz`: **0 ERRORs,
0 WARNINGs, 2 NOTEs**. Both NOTEs are local-environmental and are not expected on
the CRAN check farm, win-builder, or R-hub.

### NOTE -- future file timestamps (local only)

`checking for future file timestamps ... unable to verify current time` is
raised on the local check host, which cannot reach a time service.

### NOTE -- HTML manual validation skipped (local only)

`checking HTML version of manual ... Skipping checking HTML validation: 'tidy'
doesn't look like recent enough HTML Tidy` reflects the dated `tidy` shipped with
the local macOS host; the CRAN farm and win-builder carry a recent HTML Tidy and
do not raise it.

## Downstream dependencies

There are **0 reverse dependencies** on CRAN (checked against the current CRAN
package database on 2026-06-26: zero reverse Depends / Imports / LinkingTo, and
zero reverse Suggests). The default-engine change therefore has no reverse-
dependency impact.

## Package scope

`janusplot` renders pairwise asymmetric smoothed-association matrices of
continuous variables via `mgcv` GAM fits. Each off-diagonal cell displays a
directional smooth; the package exposes per-pair shape descriptors
(monotonicity, convexity, inflection counts, a 24-category shape taxonomy) plus
a recovery-rate sensitivity study (`janusplot_shape_sensitivity()`) with
precomputed demo data.

## Notes to the maintainers

- All examples are executable without `\dontrun{}`; the heavier demonstrations
  sit under `\donttest{}`.
- All tests run under `testthat` edition 3; visual output is regression-tested
  with `vdiffr` and skips cleanly where the snapshot back-end is unavailable.
- No compiled code; pure R with `Imports:` from `mgcv`, `ggplot2`, `patchwork`,
  `grid`, `stats`, `cli`, `lifecycle`, `rlang`.
- Source tarball is ~2 MB, including the precomputed `shape_sensitivity_demo`
  dataset.
