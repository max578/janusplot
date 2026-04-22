# 0003. Imports budget — cap at 10

**Status.** Accepted · 2026-04-22.

## Context

Every `Imports:` dependency is maintenance the package author takes
on. `/rpkg` v0.4 sets a soft archetype-1 Imports cap of 10.

## Decision

The hard Imports cap is **10**. Additions require explicit
justification recorded in this ADR. Removals follow the deprecation
cycle in `API_STABILITY.md` if the removed package was used from
public API, and are free if it was internal.

## Current inventory (8)

| Package | Purpose | Load-bearing? |
|---|---|---|
| `mgcv` (>= 1.9.0) | GAM fitting | Yes — the package is built around `mgcv::gam()`. |
| `ggplot2` (>= 3.5.0) | Cell rendering + matrix output | Yes — return value is a ggplot object. |
| `patchwork` (>= 1.1.0) | Matrix assembly | Yes — stitching `(k+1) × (k+1)` grid + side strips. |
| `grid` | `unit()` for patchwork layout | Yes — absolute-size strip widths / heights. |
| `stats` | base; correlations, tests | Yes. |
| `cli` (>= 3.6.0) | User-facing errors, warnings, info | Yes — house style. |
| `rlang` (>= 1.1.0) | `arg_match`, `is_installed`, `check_installed` | Yes. |
| `lifecycle` (>= 1.0.0) | Roxygen `badge()` + future `deprecate_warn()` | Yes — once a single deprecation is emitted at runtime, `lifecycle` must sit in `Imports:`. |

## `Suggests:` discipline

Every package in `Suggests:` that is called as `pkg::fun()` from `R/`
is gated with `rlang::is_installed()` or `requireNamespace()`. See
`audit_2026-04-20.md` for the portfolio-wide audit confirming the
pattern.

## Consequences

- The Imports budget keeps installation fast and the `R CMD check`
  surface small.
- Discourages speculative dependencies — each new Import updates
  this ADR.
- Rejected historical addition: `scales` as an Import. Its only use
  (`scales::alpha`) was rewritten to `ggplot2::alpha` to avoid the
  extra dep.
