# janusplot (development version)

### Label placement — border vs. diagonal (2026-04-22)

* **New `labels` parameter** with three modes: `"border"` (default —
  variable names along the top + left margins, mirroring `corrplot`'s
  `tl.pos = "lt"` convention), `"diagonal"` (previous in-matrix
  layout), and `"none"` (suppressed). Default flipped to `"border"`
  because border labels free the diagonal cells and scale better to
  `k > 4` variables.
* **New `label_srt`** — rotation of top labels when
  `labels = "border"`. Default `45°` matches the visual reference;
  `0` and `90` are accepted.
* **New `label_cex`** — positive multiplier on border-label font
  size. Default `1`.
* Diagonal cells are now rendered as blank bordered panels whenever
  `labels != "diagonal"`, giving the matrix a uniform grid reading.

### Breaking: shape-metric column names (2026-04-21)

* User-facing `M` and `C` columns renamed to `monotonicity_index`
  and `convexity_index` across every data surface: the flat data
  frame from `janusplot(..., with_data = TRUE)`, `janusplot_data()`
  per-pair lists (`monotonicity_index_yx` / `convexity_index_yx` /
  `_xy` variants), the return of `janusplot_shape_metrics()`, the
  raw output of `janusplot_shape_sensitivity()`, and the precomputed
  `shape_sensitivity_demo` dataset. Paper symbols `M` / `C` remain
  as mnemonics in the documentation. Internal classifier parameter
  names (`M`, `C`) are unchanged because they match the math
  convention.
* New "Shape metrics explained" section in the `janusplot`
  vignette.
* Callers referencing `result$M` / `result$C` must update to
  `result$monotonicity_index` / `result$convexity_index`.

### Phase G — sensitivity study as a package feature (2026-04-21)

* **`janusplot_shape_sensitivity()`** — new public function that runs a
  full-factorial shape-recognition sensitivity sweep (shapes ×
  sample sizes × noise levels × replicates) and returns a tidy raw
  data frame. Optional parallel dispatch via `future.apply`.
* **`janusplot_shape_sensitivity_shapes()`** — lists the 14 canonical
  ground-truth shapes available to the sweep.
* **`janusplot_shape_sensitivity_summary()`** — per-cell accuracy
  aggregation at the fine (24-category) or archetype (7-family)
  level.
* **`janusplot_shape_sensitivity_plot()`** — four built-in
  diagnostic plots: fine / archetype confusion matrices, per-shape
  accuracy grid, recovery curves.
* **`shape_sensitivity_demo`** dataset — precomputed 2160-fit sweep
  shipped with the package so the vignette and examples don't need
  to re-run the sweep. Regenerated deterministically via
  `data-raw/shape_sensitivity_demo.R`.
* **New vignette** `shape-recognition-sensitivity.Rmd` — presents the
  sweep design, the pre-registered hypotheses, and every diagnostic
  plot on the precomputed demo dataset.
* `LazyData: true` in DESCRIPTION so `shape_sensitivity_demo` is
  accessible without an explicit `data()` call under default
  user expectations.

### Phase F — post-first-render revisions (2026-04-21)

* **Default correlation = Pearson** (switched from Spearman on the back
  of first-render review). Spearman + Kendall remain as `colour_by`
  options.
* **Colour-bar title simplified to `corr`** for all three correlation
  encodings; actual method remains visible in `janusplot_data()`
  column names and the caption.
* **Taxonomy expanded to 24 categories** via `(T, I)` dispatch. New
  fine categories: `skewed_peak`, `broad_peak`, `rippled_peak`,
  `wave`, `warped_wave`, `rippled_wave`, `complex_wave`, `bimodal`,
  `bimodal_ripple`, `bi_wave`, `bi_wave_ripple`, `rippled_monotone`.
* **Shape-types legend redesigned** — now renders every category as a
  canonical 1-cm thumbnail spline in a 6-column grid below the matrix
  (font-independent, full-width). Each panel is labelled
  `label (code)`. The old right-margin Unicode-glyph list is retired.
* **Cell glyphs off by default.** `annotations` default is
  `c("edf", "A")`; opt into per-cell shape markers with
  `annotations = c(..., "shape")` (glyph) or `annotations = c(..., "code")`
  (2-letter ASCII — safer on any font / PDF pipeline). When both are
  passed, `"code"` wins.
* **Hierarchy columns added to every output.** `janusplot(..., with_data)$data`
  gains `shape_code`, `shape_archetype`, `shape_monotonic`,
  `shape_linear`. `janusplot_data()` pairs gain per-direction
  `shape_code_yx` / `shape_code_xy` and the matching
  `shape_archetype_*`, `shape_monotonic_*`, `shape_linear_*`.
* **New public function `janusplot_shape_hierarchy()`** — returns the
  24-row taxonomy with hierarchy columns (`category`, `code`,
  `archetype`, `monotonic`, `linear`, `label`, `gloss`). Intended for
  downstream group-bys and for cross-referencing the compact 2-letter
  codes when they appear in cells or the data table.
* **Classifier is noise-robust.** Sign-change detection now uses
  lobe-mass-weighted accounting, so tail-noise wiggles on a smoothed
  saturating curve no longer inflate the inflection count into
  `complex`.

**Academic framing.** The broader-tier vocabulary (linear /
non-linear, monotone / non-monotone, convex / concave) is standard
calculus; the archetype layer is anchored by Pya & Wood (2015)
*Stat & Comput* (shape-constrained additive models) and Calabrese
(2008) *Env Tox Chem* (dose-response taxonomy). The `(T, I)` dispatch
is a coarsened Morse-theoretic critical-point classification
(Milnor 1963).

### Breaking / behaviour changes (2026-04-21 cell encoding redesign)

* **Default cell colour now encodes Spearman rank correlation.** The
  per-cell fill previously encoded EDF (non-linearity). It now encodes
  classical monotonic correlation via the new `colour_by` argument
  with a diverging `RdBu` palette symmetric around zero. Choose
  `colour_by = "pearson"` / `"kendall"` for other correlation flavours
  or `colour_by = "edf"` to restore the legacy encoding.
* **`fill_by` is deprecated** — use `colour_by`. When supplied,
  `fill_by` fires a soft deprecation warning and forwards to
  `colour_by` for one minor version.
* **Corner annotations switched to `annotations`** — a character
  vector (subset of `c("edf", "A", "shape")`) now controls which
  corner labels render on each cell. `"A"` (asymmetry index) replaces
  the old `n = ...` annotation; `"edf"` keeps EDF visible as text;
  `"shape"` draws the new shape-category glyph bottom-right.
* **`show_asymmetry` is deprecated** — use `annotations`. When
  supplied, the legacy argument fires a soft deprecation warning and
  is merged into `annotations`.

### New features

* **Objective shape descriptor** — every cell now carries two
  continuous indices (monotonicity `M`, convexity `C`), two discrete
  counts (`n_turning_points`, `n_inflections`), and a discrete
  `shape_category` from a 12-category taxonomy (`linear_up`,
  `linear_down`, `convex_up`, `concave_up`, `convex_down`,
  `concave_down`, `u_shape`, `inverted_u`, `s_shape`, `complex`,
  `flat`, `indeterminate`). Cutoffs are tunable via
  `janusplot_shape_cutoffs()`.
* **`janusplot_shape_metrics()`** — public function to compute the
  shape descriptor for any fitted `mgcv::gam` with a single `s()`
  term.
* **`janusplot_shape_cutoffs()`** — public function returning the
  default threshold list; callers override individual thresholds via
  `...`.
* **Shape-types legend** — when `annotations` includes `"shape"`, a
  compact legend listing every category present in the matrix is
  attached alongside the colour bar. Toggle with `show_shape_legend`.
* **Unicode / ASCII glyph switch** — new `glyph_style` argument
  (`"unicode"` default, `"ascii"` fallback) for pipelines that lack
  Unicode curve glyphs.
* **Extended data table** — `janusplot(..., with_data = TRUE)$data`
  gains columns `cor_pearson`, `cor_spearman`, `cor_kendall`,
  `tie_ratio`, `M`, `C`, `n_turning_points`, `n_inflections`,
  `flat_range_ratio`, `shape_category`, `colour_value`. The legacy
  `fill_value` column is renamed `colour_value`.
* **Extended `janusplot_data()` pairs** — each per-pair element gains
  Pearson / Spearman / Kendall correlations, tie ratio, and
  per-direction shape descriptors (`M_yx`, `C_yx`, `M_xy`, `C_xy`,
  `n_turning_*`, `n_inflect_*`, `shape_yx`, `shape_xy`).

## janusplot 0.0.0.9000

### New features

* `janusplot()` — asymmetric smoothed-association matrix visualisation.
  For each pair of numeric variables `(X_i, X_j)` with `i != j`, the
  cell at matrix position `[i, j]` renders the fitted spline from
  `mgcv::gam(X_j ~ s(X_i) + <adjust>)`. Upper and lower triangles show
  the two directional fits. Diagonal cells carry variable labels.
* `janusplot_data()` — programmatic companion returning raw GAM fits
  and per-pair metrics (EDF, F-test p-value, deviance explained,
  asymmetry index) without constructing a ggplot. Set
  `keep_fits = TRUE` to retain the full `mgcv::gam` objects.
* **Asymmetry index** — the per-pair single-number summary
  `|EDF_yx − EDF_xy| / (EDF_yx + EDF_xy)`, bounded in `[0, 1]`,
  exposed both via `janusplot_data()$pairs[[i]]$asymmetry_index` and
  (optionally) as a cell corner annotation via `show_asymmetry = TRUE`.
* **Partial smooths via `adjust =`** — any one-sided formula RHS
  (e.g. `~ s(z) + s(g, bs = "re")`) propagates to every pairwise
  GAM, producing covariate-adjusted smooths and supporting random
  effects out of the box.
* **`order = "hclust"`** — reorder variables by hierarchical
  clustering of `1 - |cor|` (matching the `corrplot` convention) to
  group strongly correlated variables visually.
* **`na_action = "pairwise"`** (default) vs `"complete"` — per-pair
  complete observations with annotated `n_used` per cell, vs listwise
  deletion.
* **Parallelism via `future.apply`** — set `parallel = TRUE` to
  dispatch pair fits across a user-configured `future::plan()`.
* **Colour palette choice** — `palette =` accepts one of 16 options:
  - viridis family (colourblind-safe sequential): `viridis` (default),
    `magma`, `inferno`, `plasma`, `cividis`, `mako`, `rocket`;
  - viridis high-contrast: `turbo` (not colourblind-safe);
  - ColorBrewer diverging (colourblind-safe): `RdYlBu`, `RdBu`, `PuOr`;
  - ColorBrewer diverging (not colourblind-safe): `Spectral`;
  - ColorBrewer sequential (colourblind-safe): `YlOrRd`, `YlGnBu`,
    `Blues`, `Greens`.
* **Shared right-margin colourbar legend** when `fill_by != "none"`,
  placed in a dedicated fixed-width column (1.8 cm) so cells remain
  square.
* **Cell annotations scale with `k`** — `n` and `EDF` labels shrink
  sublinearly as the number of variables grows, keeping small-cell
  plots legible.
* **Glossary caption** — a dynamic caption below the matrix explains
  the on-plot abbreviations (`n`, `EDF`, `A`, fill encoding, and
  significance glyphs), showing only the keys actually displayed.
* **`with_data = TRUE`** — optional flat per-cell summary table
  returned alongside the ggplot, as a `data.table` when the package
  is installed or a `data.frame` otherwise.

### Testing and quality

* 70 unit + integration tests; 5 `vdiffr` visual-regression snapshots.
* Passes `R CMD check --as-cran` with 0 ERRORs, 0 WARNINGs; 2 NOTEs
  remain (both environmental: new-submission status; local HTML Tidy
  version).
* Three-scenario simulation study validating the approach — linear
  recovery, non-linear detection, and heteroscedastic asymmetry.
  Scenario 3 is the paper's headline result: under a DGP with
  Pearson `r = 0.93`, `janusplot` recovers an asymmetry index ≈ 0.56
  (IQR [0.52, 0.65]), exposing hidden directional structure a
  scalar correlation misses.

### Project context

* Standalone CRAN release target (`max578/janusplot`). An earlier
  plan to merge into `AAGI-AUS/effectsurf` was superseded on
  2026-04-21; this package now ships on its own.
* Accompanying R Journal paper *Beyond Pearson: Visualising
  Asymmetric Non-linear Associations with Generalised Additive
  Models* is in preparation (see `paper/` in the dev workspace).

### Dependency diet

Imports kept minimal: `mgcv`, `ggplot2`,
`patchwork`, `grid`, `stats`, `cli`, `rlang`. Optional: `data.table`,
`future.apply`, `vdiffr`, `withr`, `palmerpenguins`, `MASS`,
`agridat`, `knitr`, `rmarkdown`.
