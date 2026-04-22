# 0002. Class system — stay on S3

**Status.** Accepted · 2026-04-22.

## Context

R offers S3, S4, S7, and R6 class systems. `/rpkg` v0.3+ guidance
prefers S7 for new formal hierarchies in methods-shape packages.
janusplot returns `ggplot` / `patchwork` objects and does not
introduce its own formal objects.

## Decision

- No formal class hierarchy is introduced.
- The public API returns base R and dependency-provided objects:
  `ggplot` (the matrix composite), `list` (for `janusplot_data()`
  and sensitivity outputs), and `data.frame` / `data.table` (for
  the flat summary table in `janusplot(..., with_data = TRUE)`).
- If a future version grows a result object substantial enough to
  warrant a class, S7 is preferred per `/rpkg` v0.3 guidance.
  Re-evaluate at each major-version bump.

## Consequences

- Users retain the full ggplot extension surface; `+ theme_*()`
  works out of the box.
- No per-class maintenance burden (no `print.janusplot`,
  `summary.janusplot`, etc.).
- Cost: no class-level introspection of the object; users must
  read documented component names in `janusplot_data()` output.
- Rejected alternatives: S4 (no descent from an S4 hierarchy
  required — janusplot orchestrates `mgcv::gam()` but does not
  extend it); R6 (no mutable state).
