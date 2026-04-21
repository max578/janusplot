# Shape metrics for janusplot cells.
# Two continuous indices (monotonicity M, convexity C), two discrete
# counts (turning points, inflections), one ratio (flat range), and a
# rule-based classifier into 12 shape categories. All weights are the
# empirical density of x on the prediction grid, so the metrics describe
# the smooth *where the data actually live*, not the extrapolated tails.
#
# Exposed publicly via janusplot_shape_metrics() and
# janusplot_shape_cutoffs(). Internals are dot-prefixed.

# ---------------------------------------------------------------
# Default cutoff list. Tunable via the cutoffs argument.
# ---------------------------------------------------------------

#' Default cutoff thresholds for `shape_category` classification
#'
#' @description
#' Returns the named list of thresholds used to map the continuous
#' monotonicity (`M`) and convexity (`C`) indices (plus inflection
#' counts) into a discrete `shape_category`. Expose so callers can
#' override individual thresholds or pass a fully custom list to
#' [janusplot()] / [janusplot_shape_metrics()].
#'
#' @param ... Optional named overrides to merge into the defaults.
#'
#' @returns A named list with numeric thresholds:
#' \describe{
#'   \item{`mono_strong`}{`|M|` threshold for a strictly monotone smooth (default `0.9`).}
#'   \item{`mono_mod`}{`|M|` threshold for a curved-but-monotone smooth (default `0.5`).}
#'   \item{`mono_nonmono`}{`|M|` below this is considered non-monotone (default `0.3`).}
#'   \item{`mono_s`}{`|M|` threshold for labelling an S-shape (default `0.5`).}
#'   \item{`curv_low`}{`|C|` below this is considered near-linear curvature (default `0.2`).}
#'   \item{`curv_mod`}{`|C|` threshold for a clearly curved monotone (default `0.5`).}
#'   \item{`curv_strong`}{`|C|` threshold for a U-shape / inverted-U shape
#'     (default `0.5`).}
#'   \item{`flat`}{`range(fit) / sd(y)` below this is called `flat` (default `0.05`).}
#' }
#'
#' @examples
#' janusplot_shape_cutoffs()
#' janusplot_shape_cutoffs(curv_mod = 0.6, flat = 0.02)
#' @export
janusplot_shape_cutoffs <- function(...) {
  defaults <- list(
    mono_strong  = 0.9,
    mono_mod     = 0.5,
    mono_nonmono = 0.3,
    mono_s       = 0.5,
    curv_low     = 0.2,
    curv_mod     = 0.5,
    curv_strong  = 0.5,
    flat         = 0.05
  )
  overrides <- list(...)
  if (length(overrides)) {
    unknown <- setdiff(names(overrides), names(defaults))
    if (length(unknown)) {
      cli::cli_abort(c(
        "Unknown cutoff name{?s}: {.val {unknown}}.",
        i = "Allowed: {.val {names(defaults)}}."
      ))
    }
    for (nm in names(overrides)) {
      v <- overrides[[nm]]
      if (!is.numeric(v) || length(v) != 1L || !is.finite(v)) {
        cli::cli_abort("Cutoff {.val {nm}} must be a single finite number.")
      }
      defaults[[nm]] <- v
    }
  }
  defaults
}

# ---------------------------------------------------------------
# Canonical shape taxonomy: single source of truth for categories,
# glyphs, ASCII fallbacks, and one-line glosses. Consumed by the
# classifier, the cell renderer, and the shape-types legend.
# ---------------------------------------------------------------

.shape_taxonomy <- function() {
  # Order within the data frame drives legend layout (top-left to
  # bottom-right, row-major). Group monotone shapes, then peaks,
  # then waves, then multi-peak, with flat / indeterminate last.
  #
  # Four hierarchy columns layered from finest to coarsest:
  #   category  — 24-way fine label (primary dispatch)
  #   code      — unique 2-letter ASCII shorthand (cell-safe)
  #   archetype — 7-family grouping (SCAM / dose-response inspired)
  #   monotonic — monotone / non_monotone / degenerate
  #   linear    — linear / non_linear / degenerate
  data.frame(
    category  = c(
      "linear_up", "linear_down",
      "convex_up", "concave_up",
      "convex_down", "concave_down",
      "s_shape", "rippled_monotone",
      "u_shape", "inverted_u",
      "skewed_peak", "broad_peak", "rippled_peak",
      "wave", "warped_wave", "rippled_wave", "complex_wave",
      "bimodal", "bimodal_ripple",
      "bi_wave", "bi_wave_ripple",
      "complex",
      "flat", "indeterminate"
    ),
    code      = c(
      "lu", "ld",
      "vu", "cu", "vd", "cd",
      "ss", "rm",
      "us", "iu",
      "sp", "bp", "rp",
      "wv", "ww", "rw", "cw",
      "bm", "mr",
      "bw", "wr",
      "cx",
      "ft", "id"
    ),
    archetype = c(
      "monotone_linear", "monotone_linear",
      "monotone_curved", "monotone_curved",
      "monotone_curved", "monotone_curved",
      "monotone_curved", "monotone_curved",
      "unimodal", "unimodal",
      "unimodal", "unimodal", "unimodal",
      "wave", "wave", "wave", "wave",
      "multimodal", "multimodal",
      "multimodal", "multimodal",
      "chaotic",
      "degenerate", "degenerate"
    ),
    monotonic = c(
      "monotone", "monotone",
      "monotone", "monotone", "monotone", "monotone",
      "monotone", "monotone",
      "non_monotone", "non_monotone",
      "non_monotone", "non_monotone", "non_monotone",
      "non_monotone", "non_monotone", "non_monotone", "non_monotone",
      "non_monotone", "non_monotone",
      "non_monotone", "non_monotone",
      "non_monotone",
      "degenerate", "degenerate"
    ),
    linear    = c(
      "linear", "linear",
      "non_linear", "non_linear", "non_linear", "non_linear",
      "non_linear", "non_linear",
      "non_linear", "non_linear",
      "non_linear", "non_linear", "non_linear",
      "non_linear", "non_linear", "non_linear", "non_linear",
      "non_linear", "non_linear",
      "non_linear", "non_linear",
      "non_linear",
      "degenerate", "degenerate"
    ),
    glyph     = c(
      "\u2197", "\u2198",
      "\u2310", "\u2312", "\u2323", "\u00ac",
      "\u222b", "\u2248",
      "\u222a", "\u2229",
      "\u22cf", "\u2293", "\u223f",
      "\u223f", "\u219d", "\u2307", "\u2307",
      "MM", "MM", "MN", "MN", "X",
      "\u2014", "?"
    ),
    ascii     = c(
      "/", "\\",
      "J", "r", "u", "L",
      "S", "~",
      "U", "^",
      "P", "#", "P",
      "~", "~", "~", "~",
      "M", "M", "N", "N", "X",
      "-", "?"
    ),
    label     = c(
      "linear up", "linear down",
      "convex up", "concave up",
      "convex down", "concave down",
      "S-shape", "rippled monotone",
      "U-shape", "inverted U",
      "skewed peak", "broad peak", "rippled peak",
      "wave", "warped wave", "rippled wave", "complex wave",
      "bimodal", "bimodal + ripple",
      "bi-wave", "bi-wave + ripple", "complex",
      "flat", "indeterminate"
    ),
    gloss     = c(
      "monotone increasing, near-linear",
      "monotone decreasing, near-linear",
      "accelerating growth",
      "saturating growth (diminishing returns)",
      "decelerating decay",
      "accelerating decay",
      "monotone with one inflection",
      "monotone with multiple curvature flips",
      "non-monotone bowl (single minimum)",
      "non-monotone dome (single maximum)",
      "asymmetric single extremum, one inflection",
      "single extremum with shoulders, two inflections",
      "single extremum with ripples",
      "one full oscillation (sine-like)",
      "wave with asymmetric curvature",
      "wave with extra inflection",
      "wave with multiple ripples",
      "two extrema pairs (double peak)",
      "double peak with extra ripples",
      "two full oscillations",
      "bi-wave with extra ripples",
      "five or more extrema / inflections",
      "no meaningful variation",
      "fit unavailable or undefined"
    ),
    stringsAsFactors = FALSE
  )
}

# Quick lookup helper — given a vector of category names, returns the
# corresponding column (code / archetype / monotonic / linear) from
# the single source-of-truth taxonomy table.
.shape_lookup <- function(category, column) {
  tax <- .shape_taxonomy()
  idx <- match(category, tax$category)
  tax[[column]][idx]
}

#' Shape-category taxonomy table
#'
#' @description
#' Return the full janusplot shape taxonomy as a data frame with four
#' hierarchy columns plus presentation fields. The taxonomy is the
#' single source of truth consumed by the classifier, the cell
#' renderer, the legend plate, and the `janusplot_data()` output.
#'
#' Hierarchy columns (finest → coarsest):
#' \describe{
#'   \item{`category`}{24-way fine label (`linear_up`, `skewed_peak`,
#'     `bimodal`, …). Computed per cell by [janusplot()].}
#'   \item{`code`}{Unique two-letter ASCII shorthand (safe on any
#'     font or typesetting pipeline) — e.g. `lu` for `linear_up`.}
#'   \item{`archetype`}{Seven-family grouping: `monotone_linear`,
#'     `monotone_curved`, `unimodal`, `wave`, `multimodal`,
#'     `chaotic`, `degenerate`.}
#'   \item{`monotonic`}{Three-way coarse classification: `monotone`
#'     / `non_monotone` / `degenerate`.}
#'   \item{`linear`}{Binary: `linear` / `non_linear` /
#'     `degenerate`.}
#' }
#'
#' The broader tiers (linear/non-linear, monotone/non-monotone) are
#' textbook calculus; the archetype layer maps cleanly to
#' shape-constrained regression vocabulary (Pya & Wood 2015;
#' Meyer 2008) and to dose-response shape categories (Calabrese
#' 2008; Calabrese & Baldwin 2001). The `(T, I)` dispatch
#' underlying each fine category is a coarsened Morse-theoretic
#' critical-point classification (Milnor 1963).
#'
#' @returns A data frame with 24 rows and columns `category`,
#'   `code`, `archetype`, `monotonic`, `linear`, `glyph`, `ascii`,
#'   `label`, `gloss`.
#'
#' @references
#' Calabrese, E. J. (2008). Hormesis: why it is important to
#'   toxicology and toxicologists. *Environmental Toxicology and
#'   Chemistry*, **27**(7), 1451–1474.
#'
#' Meyer, M. C. (2008). Inference using shape-restricted regression
#'   splines. *Annals of Applied Statistics*, **2**(3), 1013–1033.
#'
#' Milnor, J. (1963). *Morse Theory*. Princeton University Press.
#'
#' Pya, N., & Wood, S. N. (2015). Shape constrained additive models.
#'   *Statistics and Computing*, **25**(3), 543–559.
#'
#' @examples
#' tax <- janusplot_shape_hierarchy()
#' head(tax[, c("category", "code", "archetype", "monotonic", "linear")])
#' # Count how many categories live in each archetype
#' table(tax$archetype)
#' @export
janusplot_shape_hierarchy <- function() {
  .shape_taxonomy()
}

# Canonical (x, y) thumbnail for each shape category. The legend
# renders these as mini-panels, which is font-independent and more
# visually informative than a Unicode glyph. All thumbnails live on
# x ∈ [0, 1] with y normalised to [0, 1] at draw time.
.shape_thumbnail_df <- function(category, n = 80L) {
  x <- seq(0, 1, length.out = as.integer(n))
  y <- switch(category,
    linear_up        = x,
    linear_down      = 1 - x,
    convex_up        = x^2,
    concave_up       = sqrt(x),
    convex_down      = (1 - x)^2,
    concave_down     = sqrt(1 - x),
    s_shape          = 1 / (1 + exp(-10 * (x - 0.5))),
    rippled_monotone = x + 0.08 * sin(8 * pi * x),
    u_shape          = 4 * (x - 0.5)^2,
    inverted_u       = 1 - 4 * (x - 0.5)^2,
    skewed_peak      = (x * exp(1 - 3 * x)) * (3 * exp(1)) / exp(2),
    broad_peak       = exp(-((x - 0.5) * 3)^4),
    rippled_peak     = exp(-((x - 0.5) * 3)^2) +
                         0.08 * sin(12 * pi * x),
    wave             = 0.5 + 0.5 * sin(2 * pi * x - pi / 2),
    warped_wave      = 0.5 + 0.5 * sin(2 * pi * (x^1.4) - pi / 2),
    rippled_wave     = 0.5 + 0.5 * sin(2 * pi * x - pi / 2) +
                         0.07 * sin(8 * pi * x),
    complex_wave     = 0.5 + 0.5 * sin(2 * pi * x - pi / 2) +
                         0.18 * sin(10 * pi * x),
    bimodal          = exp(-((x - 0.25) * 6)^2) +
                         exp(-((x - 0.75) * 6)^2),
    bimodal_ripple   = exp(-((x - 0.25) * 6)^2) +
                         exp(-((x - 0.75) * 6)^2) +
                         0.05 * sin(14 * pi * x),
    bi_wave          = 0.5 + 0.5 * sin(4 * pi * x - pi / 2),
    bi_wave_ripple   = 0.5 + 0.5 * sin(4 * pi * x - pi / 2) +
                         0.07 * sin(14 * pi * x),
    complex          = 0.5 + 0.35 * sin(6 * pi * x) *
                         cos(3 * pi * x),
    flat             = rep(0.5, length(x)),
    indeterminate    = rep(NA_real_, length(x)),
    rep(NA_real_, length(x))
  )
  data.frame(x = x, y = y, category = category,
             stringsAsFactors = FALSE)
}

# Glyph lookup (Unicode by default; "ascii" overrides for
# font-coverage fallback).
.shape_glyph <- function(category, style = c("unicode", "ascii")) {
  style <- match.arg(style)
  tax   <- .shape_taxonomy()
  idx   <- match(category, tax$category)
  col   <- if (style == "ascii") "ascii" else "glyph"
  ifelse(is.na(idx), "?", tax[[col]][idx])
}

# ---------------------------------------------------------------
# Rule-based classifier. Inputs must be finite scalars or NA.
# ---------------------------------------------------------------

# Dispatch for the monotone (T=0, I=0) cell — no turning points, no
# inflections. Uses the (M, C) indices to separate strict-linear from
# curved monotone, with orientation from sign(M) and curvature from
# sign(C).
.classify_monotone <- function(M, C, cutoffs) {
  if (abs(M) > cutoffs$mono_strong && abs(C) < cutoffs$curv_low) {
    return(if (M > 0) "linear_up" else "linear_down")
  }
  if (M >  cutoffs$mono_mod && C >  cutoffs$curv_mod) return("convex_up")
  if (M >  cutoffs$mono_mod && C < -cutoffs$curv_mod) return("concave_up")
  if (M < -cutoffs$mono_mod && C >  cutoffs$curv_mod) return("convex_down")
  if (M < -cutoffs$mono_mod && C < -cutoffs$curv_mod) return("concave_down")
  if (M >  0) return("linear_up")
  if (M <  0) return("linear_down")
  "flat"
}

# Primary classifier: dispatch on (T, I) = (n_turning_points,
# n_inflections). (M, C) only disambiguates the `(0, 0)` and `(1, 0)`
# cells. See .shape_taxonomy() for the category list + glosses.
.classify_shape <- function(M, C, n_turn, n_inflect, flat_ratio, cutoffs) {
  if (is.na(M) || is.na(C)) return("indeterminate")
  if (!is.na(flat_ratio) && flat_ratio < cutoffs$flat) return("flat")
  n_T <- if (is.na(n_turn))    0L else as.integer(n_turn)
  n_I <- if (is.na(n_inflect)) 0L else as.integer(n_inflect)
  if (n_T >= 5L || n_I >= 5L) return("complex")

  if (n_T == 0L) {
    if (n_I == 0L) return(.classify_monotone(M, C, cutoffs))
    if (n_I == 1L) return("s_shape")
    return("rippled_monotone")        # n_I >= 2
  }
  if (n_T == 1L) {
    if (n_I == 0L) return(if (C > 0) "u_shape" else "inverted_u")
    if (n_I == 1L) return("skewed_peak")
    if (n_I == 2L) return("broad_peak")
    return("rippled_peak")             # n_I >= 3
  }
  if (n_T == 2L) {
    if (n_I <= 1L) return("wave")
    if (n_I == 2L) return("warped_wave")
    if (n_I == 3L) return("rippled_wave")
    return("complex_wave")             # n_I >= 4
  }
  if (n_T == 3L) {
    if (n_I >= 3L) return("bimodal_ripple")
    return("bimodal")                  # n_I in {0, 1, 2}
  }
  if (n_T == 4L) {
    if (n_I >= 3L) return("bi_wave_ripple")
    return("bi_wave")                  # n_I in {0, 1, 2}
  }
  "complex"
}

# ---------------------------------------------------------------
# Numerical derivatives on an equally-spaced grid.
# Central differences inside, forward/backward at the endpoints.
# ---------------------------------------------------------------

.central_diff <- function(x, y) {
  n <- length(y)
  if (n < 3L) return(rep(NA_real_, n))
  d <- numeric(n)
  d[1L]  <- (y[2L] - y[1L])     / (x[2L] - x[1L])
  d[n]   <- (y[n]  - y[n - 1L]) / (x[n]  - x[n - 1L])
  idx    <- 2:(n - 1L)
  d[idx] <- (y[idx + 1L] - y[idx - 1L]) / (x[idx + 1L] - x[idx - 1L])
  d
}

# Robust sign-change count for a derivative vector. A candidate sign
# change at index j is only counted when the integrated |v| in the
# lobe on either side exceeds `min_lobe_frac` of the total integrated
# |v|. This discards tail-noise wiggles that would otherwise inflate
# inflection / turning-point counts for spline-smoothed saturating
# curves and similar shapes.
.n_sign_changes <- function(v, min_lobe_frac = 0.1, rel_tol = 1e-2) {
  v <- v[is.finite(v)]
  n <- length(v)
  if (n < 2L) return(0L)
  scale_v <- max(abs(v))
  if (!is.finite(scale_v) || scale_v == 0) return(0L)
  total <- sum(abs(v))
  if (!is.finite(total) || total == 0) return(0L)

  # Suppress noise floor before sign extraction.
  v_clean <- ifelse(abs(v) < rel_tol * scale_v, 0, v)
  s <- sign(v_clean)
  # Forward-fill zero runs so a candidate crossing sits between two
  # non-zero sign regions rather than swallowing the boundary.
  prev <- 0
  for (i in seq_along(s)) {
    if (s[i] == 0) s[i] <- prev else prev <- s[i]
  }
  if (all(s == 0)) return(0L)

  change_idx <- which(diff(s) != 0) + 1L
  if (!length(change_idx)) return(0L)

  # Integrate |v| between consecutive change boundaries.
  boundaries <- c(0L, change_idx - 1L, n)
  lobe_mass  <- numeric(length(boundaries) - 1L)
  for (k in seq_along(lobe_mass)) {
    lo <- boundaries[k] + 1L
    hi <- boundaries[k + 1L]
    if (hi < lo) next
    lobe_mass[k] <- sum(abs(v[lo:hi]))
  }
  lobe_frac <- lobe_mass / total

  # Count only crossings where BOTH adjacent lobes carry substantial
  # mass.
  real <- 0L
  for (j in seq_along(change_idx)) {
    if (lobe_frac[j] >= min_lobe_frac &&
        lobe_frac[j + 1L] >= min_lobe_frac) {
      real <- real + 1L
    }
  }
  real
}

# Empirical x-density evaluated on the prediction grid. Trapezoidal
# integration weights built in: we normalise so sum(w) = 1.
.grid_weights <- function(raw_x, grid_x) {
  raw_x <- raw_x[is.finite(raw_x)]
  if (length(raw_x) < 2L || diff(range(raw_x)) == 0) {
    w <- rep(1, length(grid_x))
    return(w / sum(w))
  }
  bw <- tryCatch(stats::bw.nrd0(raw_x), error = function(e) {
    stats::sd(raw_x) * (4 / (3 * length(raw_x)))^(1 / 5)
  })
  if (!is.finite(bw) || bw <= 0) bw <- diff(range(raw_x)) / 20
  dens <- tryCatch(
    stats::density(raw_x, bw = bw,
                   from = min(grid_x), to = max(grid_x),
                   n = max(512L, length(grid_x))),
    error = function(e) NULL
  )
  if (is.null(dens)) {
    w <- rep(1, length(grid_x))
    return(w / sum(w))
  }
  w <- stats::approx(dens$x, dens$y, xout = grid_x, rule = 2L)$y
  w[!is.finite(w) | w < 0] <- 0
  if (sum(w) <= 0) {
    w <- rep(1, length(grid_x))
  }
  w / sum(w)
}

# ---------------------------------------------------------------
# Raw metric computation (no classification). Cached on each pair
# fit so render-time reclassification under different cutoffs is
# free. Returns M, C, counts, flat ratio. Never errors.
# ---------------------------------------------------------------

.na_shape_raw <- function() {
  list(
    M                = NA_real_,
    C                = NA_real_,
    n_turning_points = NA_integer_,
    n_inflections    = NA_integer_,
    flat_range_ratio = NA_real_
  )
}

.compute_shape_metrics_raw <- function(fit_obj) {
  if (is.null(fit_obj) || !is.list(fit_obj)) return(.na_shape_raw())
  pred <- fit_obj$pred
  if (is.null(pred) || nrow(pred) < 3L) return(.na_shape_raw())
  if (all(is.na(pred$fit))) return(.na_shape_raw())

  x  <- pred$x
  y  <- pred$fit
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 3L) return(.na_shape_raw())
  x <- x[ok]; y <- y[ok]

  raw_x <- if (!is.null(fit_obj$raw) && nrow(fit_obj$raw) > 0L) {
    fit_obj$raw[[fit_obj$x_name]]
  } else {
    x
  }
  w <- .grid_weights(raw_x, x)

  d1 <- .central_diff(x, y)
  d2 <- .central_diff(x, d1)

  abs_d1_sum <- sum(w * abs(d1), na.rm = TRUE)
  abs_d2_sum <- sum(w * abs(d2), na.rm = TRUE)
  # Zero integrated slope / curvature means a truly flat or truly
  # linear smooth; in both cases the corresponding index is 0, not
  # NA. Only return NA when the raw derivatives themselves were NA.
  M <- if (is.finite(abs_d1_sum) && abs_d1_sum > 0) {
    sum(w * d1, na.rm = TRUE) / abs_d1_sum
  } else if (is.finite(abs_d1_sum)) {
    0
  } else {
    NA_real_
  }
  C <- if (is.finite(abs_d2_sum) && abs_d2_sum > 0) {
    sum(w * d2, na.rm = TRUE) / abs_d2_sum
  } else if (is.finite(abs_d2_sum)) {
    0
  } else {
    NA_real_
  }
  # Dimensionless curvature-signal: compares integrated |d2| against
  # integrated |d1| scaled by the x-range, so the test is invariant
  # to absolute units. When the second derivative is numerical noise
  # (linear smooth), this collapses to zero and we suppress both C
  # and the inflection count.
  x_range <- diff(range(x, na.rm = TRUE))
  y_range <- diff(range(y, na.rm = TRUE))
  curv_signal <- if (is.finite(x_range) && x_range > 0 &&
                     is.finite(abs_d1_sum) && abs_d1_sum > 0) {
    abs_d2_sum * x_range / abs_d1_sum
  } else {
    NA_real_
  }
  slope_signal <- if (is.finite(x_range) && x_range > 0 &&
                      is.finite(y_range) && y_range > 0) {
    abs_d1_sum * x_range / y_range
  } else {
    NA_real_
  }
  if (is.finite(curv_signal) && curv_signal < 1e-3 && is.finite(C)) C <- 0

  # Count sign changes only when the underlying derivative carries
  # meaningful signal; otherwise noise-driven sign flips inflate
  # counts and mis-classify linear / flat smooths as `complex`.
  n_turn <- if (is.finite(slope_signal) && slope_signal < 1e-3) {
    0L
  } else {
    .n_sign_changes(d1)
  }
  n_inflect <- if (is.finite(curv_signal) && curv_signal < 1e-3) {
    0L
  } else {
    .n_sign_changes(d2)
  }

  raw_y <- if (!is.null(fit_obj$raw) && !is.null(fit_obj$y_name) &&
               !is.null(fit_obj$raw[[fit_obj$y_name]])) {
    fit_obj$raw[[fit_obj$y_name]]
  } else {
    y
  }
  sd_y <- stats::sd(raw_y, na.rm = TRUE)
  flat_ratio <- if (!is.finite(sd_y) || sd_y == 0) {
    0
  } else {
    y_range / sd_y
  }

  list(
    M                = unname(M),
    C                = unname(C),
    n_turning_points = as.integer(n_turn),
    n_inflections    = as.integer(n_inflect),
    flat_range_ratio = unname(flat_ratio)
  )
}

# Classified variant — raw + shape_category via user cutoffs.
.compute_shape_metrics <- function(fit_obj,
                                   cutoffs = janusplot_shape_cutoffs()) {
  raw <- .compute_shape_metrics_raw(fit_obj)
  raw$shape_category <- .classify_shape(
    raw$M, raw$C, raw$n_turning_points, raw$n_inflections,
    raw$flat_range_ratio, cutoffs
  )
  raw
}

# ---------------------------------------------------------------
# Public wrapper: compute shape metrics directly from a fitted
# mgcv::gam on a single predictor, or from the list returned by a
# pair-fit helper.
# ---------------------------------------------------------------

#' Shape metrics for a fitted univariate smooth
#'
#' @description
#' Compute the continuous monotonicity and convexity indices, inflection
#' and turning-point counts, and rule-based shape category for a fitted
#' univariate smooth. Works on either a per-pair fit object returned
#' from the janusplot internal machinery or a freshly fitted
#' [mgcv::gam()] with a single `s()` term.
#'
#' Both indices are bounded in `[-1, 1]` and weighted by the empirical
#' density of the predictor:
#' * `M` — monotonicity index. `+1` strictly increasing, `-1` strictly
#'   decreasing, `0` non-monotone.
#' * `C` — convexity index. `+1` globally convex (bowl-up), `-1`
#'   globally concave (bowl-down), `0` inflection-dominated.
#'
#' @param fit Either a list returned by a janusplot pair-fit helper
#'   (must contain `pred` and `raw`), or a fitted [mgcv::gam()] with
#'   a single `s(x)` term.
#' @param x_name Character. Column name of the predictor when `fit` is
#'   a [mgcv::gam()] object. Ignored for pair-fit lists.
#' @param newdata Optional data frame supplying the raw predictor values
#'   used for density weighting when `fit` is a [mgcv::gam()] object.
#'   If `NULL`, the model frame is used.
#' @param n_grid Integer. Prediction grid length when `fit` is a
#'   [mgcv::gam()] object. Default `200L`.
#' @param cutoffs Named list of classification thresholds; see
#'   [janusplot_shape_cutoffs()]. Default uses package defaults.
#'
#' @returns A named list with components `M`, `C`, `n_turning_points`,
#'   `n_inflections`, `flat_range_ratio`, `shape_category`.
#'
#' @seealso [janusplot_shape_cutoffs()], [janusplot()], [janusplot_data()].
#'
#' @examples
#' # On a fitted gam
#' set.seed(2026L)
#' n  <- 200L
#' x  <- stats::runif(n, 0, 10)
#' y  <- log1p(x) + stats::rnorm(n, sd = 0.3)
#' d  <- data.frame(x = x, y = y)
#' fit <- mgcv::gam(y ~ s(x), data = d, method = "REML")
#' janusplot_shape_metrics(fit, x_name = "x", newdata = d)
#' @export
janusplot_shape_metrics <- function(fit,
                                    x_name  = NULL,
                                    newdata = NULL,
                                    n_grid  = 200L,
                                    cutoffs = janusplot_shape_cutoffs()) {
  if (is.list(fit) && !inherits(fit, "gam") &&
      !is.null(fit$pred) && !is.null(fit$x_name)) {
    return(.compute_shape_metrics(fit, cutoffs = cutoffs))
  }
  if (!inherits(fit, "gam")) {
    cli::cli_abort(
      "{.arg fit} must be a fitted {.cls gam} or a janusplot pair-fit list."
    )
  }
  if (is.null(x_name) || !is.character(x_name) || length(x_name) != 1L) {
    cli::cli_abort(
      "{.arg x_name} must be a single character naming the predictor."
    )
  }
  mf <- stats::model.frame(fit)
  if (is.null(newdata)) newdata <- mf
  if (!x_name %in% names(newdata)) {
    cli::cli_abort(
      "Column {.val {x_name}} not found in {.arg newdata} or model frame."
    )
  }
  xv <- newdata[[x_name]]
  xv <- xv[is.finite(xv)]
  if (length(xv) < 3L) {
    cli::cli_abort("Need at least 3 finite values of {.val {x_name}}.")
  }
  x_grid <- seq(min(xv), max(xv), length.out = as.integer(n_grid))
  nd     <- data.frame(placeholder = x_grid)
  names(nd) <- x_name
  # Hold any additional covariates at typical values (mean for numeric,
  # mode for factor). Mirrors .typical_newdata() from internal-fit.R.
  for (nm in setdiff(names(mf), c(x_name, all.vars(fit$formula)[1L]))) {
    col <- mf[[nm]]
    nd[[nm]] <- if (is.numeric(col)) mean(col, na.rm = TRUE) else
      if (is.factor(col)) factor(levels(col)[which.max(tabulate(col))],
                                 levels = levels(col)) else
                                   names(sort(table(col), decreasing = TRUE))[1L]
  }
  preds <- stats::predict(fit, newdata = nd, se.fit = TRUE)
  y_name <- all.vars(fit$formula)[1L]
  pred_df <- data.frame(
    x   = x_grid,
    fit = as.numeric(preds$fit),
    se  = as.numeric(preds$se.fit),
    lo  = as.numeric(preds$fit) - 1.96 * as.numeric(preds$se.fit),
    hi  = as.numeric(preds$fit) + 1.96 * as.numeric(preds$se.fit)
  )
  raw_df <- newdata[, intersect(c(x_name, y_name), names(newdata)),
                    drop = FALSE]
  synth <- list(
    x_name = x_name, y_name = y_name,
    pred   = pred_df, raw = raw_df
  )
  .compute_shape_metrics(synth, cutoffs = cutoffs)
}
