# API stability — janusplot

**Policy.** This package follows
[Semantic Versioning](https://semver.org/) and the
[lifecycle](https://lifecycle.r-lib.org/articles/stages.html)
vocabulary for individual symbols.

## Stability stages

- **experimental** — may change without notice in any release; used
  for all pre-v1.0.0 API.
- **stable** — public API; breaking changes only at major-version
  bumps, with at least one minor version of overlap via
  `lifecycle::deprecate_warn()`.
- **superseded** — a better alternative exists; the symbol is kept
  working but is not extended.
- **deprecated** — scheduled for removal; emits
  `lifecycle::deprecate_warn()` and will be removed after at least
  one minor version.

## Public surface — current state (v0.0.0.9000)

| Symbol | Type | Stage | Since | Notes |
|---|---|---|---|---|
| `janusplot()` | function | experimental | 0.0.0.9000 | Core entry point. Parameters `labels`, `label_srt`, `label_cex` added 2026-04-22. `fill_by` and `show_asymmetry` are deprecated aliases. |
| `janusplot_data()` | function | experimental | 0.0.0.9000 | Companion returning raw fits + per-pair metrics. |
| `janusplot_shape_metrics()` | function | experimental | 0.0.0.9000 | Weighted monotonicity / convexity indices + turning / inflection counts. |
| `janusplot_shape_cutoffs()` | function | experimental | 0.0.0.9000 | Default classification thresholds; override via a named list. |
| `janusplot_shape_hierarchy()` | function | experimental | 0.0.0.9000 | 24-category taxonomy hierarchy table. |
| `janusplot_shape_sensitivity()` | function | experimental | 0.0.0.9000 | Factorial shape × n × σ × reps sweep. |
| `janusplot_shape_sensitivity_shapes()` | function | experimental | 0.0.0.9000 | Built-in generator catalogue (14 shapes). |
| `janusplot_shape_sensitivity_summary()` | function | experimental | 0.0.0.9000 | Per-cell accuracy aggregation. |
| `janusplot_shape_sensitivity_plot()` | function | experimental | 0.0.0.9000 | Four diagnostic plot types. |
| `shape_sensitivity_demo` | dataset | experimental | 0.0.0.9000 | Precomputed 2160-fit sweep. Regenerated deterministically via `data-raw/shape_sensitivity_demo.R`. |

## Deprecations in flight

| Symbol / argument | Since | Schedule |
|---|---|---|
| `janusplot(fill_by = ...)` | 0.0.0.9000 | Removal after v1.0.0 — at least one minor version of warnings. Use `colour_by =`. |
| `janusplot(show_asymmetry = ...)` | 0.0.0.9000 | Removal after v1.0.0. Use `annotations = c("A", ...)`. |

## Breaking-change policy

- Column renames in output tables are breaking. The 2026-04-21 rename
  `M` / `C` → `monotonicity_index` / `convexity_index` is documented
  in `NEWS.md`. No further rename is planned before v1.0.0.
- Changes to default argument values are breaking for callers who
  rely on defaults. The 2026-04-22 switch of `labels` from `"diagonal"`
  to `"border"` is documented in `NEWS.md`.

## Versioning

- Development versions carry `0.0.0.9000` until the first CRAN
  release.
- Upon CRAN acceptance, the version becomes `0.1.0`.
- v1.0.0 is gated on (a) R Journal paper acceptance, (b) one minor
  release beyond 0.1.0, and (c) all current `experimental` API
  promoted to `stable`.
