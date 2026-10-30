# janusplot.R -- The one-call form janusplot(), equal to
# plot(janusplot_fit(data, vars, adjust, ...), <view arguments>, style),
# with the shim that maps the 0.2.0 arguments to their 1.0.0 homes for one
# release; the matrix title, the glossary caption and the final annotation
# step shared with plot.janusplot_fit(); and the deprecated
# janusplot_data() alias of janusplot_fit().

#' Asymmetric smoothed-association matrix
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Fits every ordered pair of numeric variables with [janusplot_fit()] and
#' draws the matrix with [plot.janusplot_fit()] in one call. Each cell
#' `[r, c]` off the diagonal shows the fitted spline of
#' `gam(x_r ~ s(x_c) + <adjust>)` from [mgcv::gam()] or [mgcv::bam()]:
#' the row variable on the vertical axis against the column variable on
#' the horizontal axis, as in [graphics::pairs()]. The diagonal is blank;
#' the variable names sit on the border and a key in the top-left corner
#' shows the convention.
#'
#' The two triangles differ by design: the asymmetry reveals
#' heteroscedasticity, leverage and directional non-linearity that a
#' single scalar correlation hides.
#'
#' @details
#' Model settings (`k`, `bs`, `engine`, `method`, `na_action`, `n_grid`,
#' `derivatives`, `derivative_ci`, `derivative_ci_nsim`, `p_adjust`,
#' `shape_cutoffs`, `k_check_thresholds`, `auto_refit_k`, `k_max_iter`,
#' `discrete`, `nthreads`, `parallel`, `keep_fits`) pass through `...` to
#' [janusplot_fit()], which forwards anything else to mgcv. Appearance
#' settings live in [janusplot_style()] and are passed as `style`. To draw
#' the same fit more than once, call [janusplot_fit()] and `plot()` it.
#'
#' The 0.2.0 appearance arguments of `janusplot()` are accepted through
#' `...` for one release, each with a deprecation warning, and are removed
#' in 1.1.0: `show_data`, `show_ci`, `palette`, `show_shape_legend`,
#' `glyph_style`, `labels`, `diagonal`, `label_srt`, `show_glossary`,
#' `compact`, `compact_threshold`, `compact_levels` and `focus_dim_alpha`
#' are applied to `style`; `label_cex`, `text_scale_diag`,
#' `text_scale_off_diag` and `glossary_scale` are mapped to the `labels`,
#' `diagonal`, `strip` and `glossary` elements of
#' `janusplot_style(text_size = )` at the matrix's variable count, close
#' to but not exactly the 0.2.0 sizes; `fill_by` is mapped to
#' `colour_by`; `show_asymmetry` and `signif_glyph` are mapped to
#' `annotations`; `labels = "diagonal"` is drawn as `"border"` with a
#' message; `with_data = TRUE` returns `list(plot, data)` with `data` the
#' table of `summary(janusplot_fit(...))`; `save_as`, `save_width`,
#' `save_height` and `save_dpi` write the plot once with
#' [ggplot2::ggsave()]. Arguments after `adjust` must be named: the
#' positional order of 0.2.0 is not shimmed.
#'
#' @inheritParams janusplot_fit
#' @inheritParams plot.janusplot_fit
#' @param ... Model arguments of [janusplot_fit()], further arguments to
#'   [mgcv::gam()] or [mgcv::bam()], and for one release the 0.2.0
#'   appearance arguments listed in Details.
#'
#' @returns A [patchwork][patchwork::patchwork-package] object, which is a
#'   ggplot, as described in [plot.janusplot_fit()]. With the deprecated
#'   `with_data = TRUE`, a list with elements `plot` (that object) and
#'   `data` (the per-cell table of [summary.janusplot_fit()]).
#'
#' @family smooth-associations
#' @seealso [janusplot_fit()] for the object behind the plot,
#'   [plot.janusplot_fit()] for the view arguments, [janusplot_style()]
#'   for the appearance settings.
#'
#' @examples
#' # Three variables, six asymmetric pairwise GAM fits.
#' janusplot(mtcars[, c("mpg", "hp", "wt")], engine = "gam")
#'
#' \donttest{
#' # Heteroscedastic pair: Pearson r is about 0.9 but the inverse fit is
#' # clearly non-linear, giving an asymmetry index above 0.5.
#' set.seed(2026L)
#' n  <- 200L
#' x1 <- stats::runif(n, 0, 10)
#' x2 <- x1 + stats::rnorm(n, sd = 0.2 * x1)
#' janusplot(data.frame(x1 = x1, x2 = x2, x3 = stats::rnorm(n)))
#'
#' # The 0.2.0 look: Pearson r washed over the whole cell.
#' janusplot(mtcars[, c("mpg", "hp", "wt")], colour_by = "pearson",
#'           background_by = "none",
#'           style = janusplot_style(colour_channel = "fill"))
#'
#' # One matrix shows one quantity; derivatives come from the same fit.
#' set.seed(2026L)
#' xs <- stats::runif(300L, -3, 3)
#' df <- data.frame(
#'   x  = xs,
#'   y1 = sin(xs)  + stats::rnorm(300L, sd = 0.3),
#'   y2 = xs^2     + stats::rnorm(300L, sd = 0.6)
#' )
#' janusplot(df, display = "fit")
#' janusplot(df, display = "d1")
#' janusplot(df, display = "d2", derivative_ci = "simultaneous")
#' }
#' @export
janusplot <- function(
  data,
  vars = NULL,
  adjust = NULL,
  colour_by = "nonlinearity",
  background_by = NULL,
  annotations = NULL,
  order = "original",
  display = "fit",
  group = NULL,
  focus_by = NA_character_,
  focus_threshold = "q90",
  axes = "original",
  style = janusplot_style(),
  ...
) {
  dots   <- list(...)
  legacy <- .shim_legacy_args(
    dots, style = style, colour_by = colour_by, annotations = annotations,
    user_env = rlang::caller_env()
  )
  fit <- rlang::inject(janusplot_fit(
    data = data, vars = vars, adjust = adjust, !!!legacy$fit_args
  ))
  style <- .apply_legacy_text(legacy$style, legacy$text_args,
                              length(fit$vars))
  # "edf" is resolved here so the deprecation names the caller of
  # janusplot(), not the package-internal call into plot().
  colour_by <- .resolve_colour_by(legacy$view_args$colour_by,
                                  user_env = rlang::caller_env())
  p <- plot(
    fit,
    colour_by       = colour_by,
    background_by   = background_by,
    annotations     = legacy$view_args$annotations,
    order           = order,
    display         = display,
    group           = group,
    focus_by        = focus_by,
    focus_threshold = focus_threshold,
    axes            = axes,
    style           = style
  )

  # Legacy post-actions ----------------------------------------------------
  post <- legacy$post
  if (!is.null(post$save_as)) {
    auto_dim <- max(6, 0.65 * length(fit$vars))
    ggplot2::ggsave(
      filename = post$save_as,
      plot     = p,
      width    = post$save_width  %||% auto_dim,
      height   = post$save_height %||% auto_dim,
      units    = "in",
      dpi      = post$save_dpi
    )
  }
  if (isTRUE(post$with_data)) {
    return(list(plot = p, data = summary(fit)))
  }
  p
}

# ---------------------------------------------------------------
# The legacy shim: 0.2.0 arguments reached through `...` to their 1.0.0
# homes, one deprecation warning per name. Returns fit_args (everything
# that still belongs to janusplot_fit() or mgcv), view_args (colour_by,
# annotations), the modified style, the 0.2.0 text multipliers (applied
# by .apply_legacy_text() once the variable count is known) and the
# post-actions. Removed in 1.1.0.
# ---------------------------------------------------------------

.legacy_style_args <- function() {
  c("show_data", "show_ci", "palette", "show_shape_legend", "glyph_style",
    "labels", "diagonal", "label_srt", "show_glossary", "compact",
    "compact_threshold", "compact_levels", "focus_dim_alpha")
}

# The 0.2.0 text multipliers and the text_size element each one maps to.
.legacy_text_args <- function() {
  c(label_cex = "labels", text_scale_diag = "diagonal",
    text_scale_off_diag = "strip", glossary_scale = "glossary")
}

# Each multiplier times the element's automatic size at k variables
# becomes that element of style$text_size; elements the style already
# sets explicitly are scaled from their own size, and a style without
# text (text_size = NULL) stays without.
.apply_legacy_text <- function(style, text_args, k) {
  if (!length(text_args) || is.null(style$text_size)) return(style)
  current <- .resolve_text_pt(k, style$text_size)
  sizes <- if (is.list(style$text_size)) style$text_size else list()
  if (is.numeric(style$text_size)) sizes <- current
  for (name in names(text_args)) {
    element <- .legacy_text_args()[[name]]
    base <- current[[element]]
    if (is.na(base)) next
    sizes[element] <- list(base * text_args[[name]])
  }
  style_args <- unclass(style)
  style_args["text_size"] <- list(sizes)
  do.call(janusplot_style, style_args)
}

.shim_legacy_args <- function(dots, style, colour_by, annotations,
                              user_env = rlang::caller_env()) {
  nms <- names(dots)
  if (length(dots) && (is.null(nms) || !all(nzchar(nms)))) {
    cli::cli_abort(c(
      "Every argument after {.arg adjust} must be named.",
      i = "The positional order of janusplot() 0.2.0 is not carried over."
    ), call = rlang::caller_env())
  }
  warn <- function(name, with = NULL, details = NULL) {
    lifecycle::deprecate_warn(
      when = "1.0.0", what = sprintf("janusplot(%s = )", name),
      with = with, details = details, user_env = user_env
    )
  }

  # Appearance knobs into the style object -------------------------------
  moved <- intersect(nms, .legacy_style_args())
  if (length(moved)) {
    style_args <- unclass(style)
    for (name in moved) {
      warn(name, with = sprintf("janusplot_style(%s = )", name))
      value <- dots[[name]]
      if (name == "labels" && identical(value, "diagonal")) {
        cli::cli_inform(c(
          i = 'labels = "diagonal" is no longer available; drawing labels = "border".'
        ))
        value <- "border"
      }
      style_args[name] <- list(value)
    }
    style <- do.call(janusplot_style, style_args)
  }

  # Text multipliers, applied once the variable count is known -----------
  text_args <- list()
  for (name in intersect(nms, names(.legacy_text_args()))) {
    element <- .legacy_text_args()[[name]]
    warn(name, with = "janusplot_style(text_size = )",
         details = sprintf(paste(
           "Mapped to the %s element of text_size in points, scaled from",
           "its automatic size; the result is close to, not identical",
           "with, the 0.2.0 size."
         ), dQuote(element, FALSE)))
    .check_scalar_positive(dots[[name]], name)
    text_args[[name]] <- dots[[name]]
  }

  # View arguments ---------------------------------------------------------
  if ("fill_by" %in% nms) {
    warn("fill_by", with = "janusplot(colour_by = )")
    colour_by <- dots$fill_by
  }
  # The two 0.2.0 flags edited the 0.2.0 set, which the size-based
  # default replaces.
  if (is.null(annotations) &&
      any(c("show_asymmetry", "signif_glyph") %in% nms)) {
    annotations <- c("A", "signif")
  }
  if ("show_asymmetry" %in% nms) {
    warn("show_asymmetry", with = "janusplot(annotations = )")
    if (isTRUE(dots$show_asymmetry)) {
      annotations <- union(annotations, "A")
    } else if (isFALSE(dots$show_asymmetry)) {
      annotations <- setdiff(annotations, "A")
    }
  }
  if ("signif_glyph" %in% nms) {
    warn("signif_glyph", with = "janusplot(annotations = )",
         details = 'The significance glyph is the "signif" annotation.')
    .check_flag(dots$signif_glyph, "signif_glyph")
    annotations <- if (dots$signif_glyph) {
      union(annotations, "signif")
    } else {
      setdiff(annotations, "signif")
    }
  }

  # Post-actions -----------------------------------------------------------
  post <- list(with_data = FALSE, save_as = NULL, save_width = NULL,
               save_height = NULL, save_dpi = 300)
  if ("with_data" %in% nms) {
    warn("with_data",
         details = "Use summary(janusplot_fit(...)) for the per-cell table.")
    .check_flag(dots$with_data, "with_data")
    post$with_data <- dots$with_data
  }
  if ("save_as" %in% nms) {
    warn("save_as", with = "ggplot2::ggsave()")
    .check_save_as(dots$save_as)
    post$save_as <- dots$save_as
  }
  for (name in c("save_width", "save_height")) {
    if (name %in% nms) {
      warn(name, with = "ggplot2::ggsave()")
      .check_save_dim(dots[[name]], name)
      post[[name]] <- dots[[name]]
    }
  }
  if ("save_dpi" %in% nms) {
    warn("save_dpi", with = "ggplot2::ggsave()")
    .check_save_dpi(dots$save_dpi)
    post$save_dpi <- dots$save_dpi
  }

  shimmed <- c(.legacy_style_args(), names(.legacy_text_args()),
               "fill_by", "show_asymmetry",
               "signif_glyph", "with_data", "save_as", "save_width",
               "save_height", "save_dpi")
  list(
    fit_args  = dots[setdiff(nms, shimmed)],
    view_args = list(colour_by = colour_by, annotations = annotations),
    style     = style,
    text_args = text_args,
    post      = post
  )
}

# A single file path whose extension names an image device.
.check_save_as <- function(save_as, call = rlang::caller_env(2L)) {
  if (!is.character(save_as) || length(save_as) != 1L || !nzchar(save_as)) {
    cli::cli_abort(
      "{.arg save_as} must be a single non-empty file path or NULL.",
      call = call
    )
  }
  ext <- tolower(tools::file_ext(save_as))
  valid_ext <- c("png", "pdf", "svg", "jpg", "jpeg", "tif", "tiff",
                 "eps", "ps", "bmp")
  if (!nzchar(ext) || !(ext %in% valid_ext)) {
    cli::cli_abort(c(
      "Cannot infer image device from {.arg save_as} extension {.val {ext}}.",
      i = "Supported: {.val {valid_ext}}."
    ), call = call)
  }
  invisible(NULL)
}

.check_save_dim <- function(x, arg_name, call = rlang::caller_env(2L)) {
  if (!is.null(x) && (!is.numeric(x) || length(x) != 1L ||
                      !is.finite(x) || x <= 0)) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a single positive numeric or NULL.",
      call = call
    )
  }
  invisible(NULL)
}

.check_save_dpi <- function(x, call = rlang::caller_env(2L)) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
    cli::cli_abort("{.arg save_dpi} must be a single positive numeric.",
                   call = call)
  }
  invisible(NULL)
}

# ---------------------------------------------------------------
# Display-mode title: the label at the top of the assembled matrix
# naming what is rendered in every cell. Unicode primes by default,
# ASCII fallback when glyph_style = "ascii".
# ---------------------------------------------------------------

.display_title <- function(display, glyph_style = c("ascii", "unicode")) {
  glyph_style <- rlang::arg_match(glyph_style)
  if (glyph_style == "unicode") {
    switch(display,
      fit = "Direct fit",
      d1  = "First derivative  f\u2032(x)",
      d2  = "Second derivative  f\u2033(x)",
      display
    )
  } else {
    switch(display,
      fit = "Direct fit",
      d1  = "First derivative  df/dx",
      d2  = "Second derivative  d^2 f / dx^2",
      display
    )
  }
}

# ---------------------------------------------------------------
# Glossary caption body -- only lists keys actually shown on the
# plot: the annotations, the colour encoding and its channel, and the
# derivative band mode when a derivative is displayed.
# ---------------------------------------------------------------

.build_glossary_text <- function(annotations, colour_by,
                                 colour_channel = "border",
                                 display = "fit",
                                 derivative_ci = "pointwise",
                                 background_by = "none",
                                 adjusted = FALSE) {
  parts <- "Each cell: row ~ s(column), the row variable on the vertical axis"
  if ("formula" %in% annotations) {
    parts <- c(parts, "Strip formula = response ~ predictor of the cell")
  }
  if (display == "fit" && "A" %in% annotations) {
    parts <- c(parts,
      "A = asymmetry index |EDF_yx - EDF_xy| / (EDF_yx + EDF_xy), in [0, 1]")
  }
  if (display == "fit" && "edf" %in% annotations) {
    parts <- c(parts,
      "EDF = effective degrees of freedom of the smooth")
  }
  if ("r" %in% annotations) {
    parts <- c(parts, sprintf("r = %s of the pair%s",
                              .background_label(background_by) %||%
                                "Pearson r",
                              if (adjusted) ", marginal" else ""))
  }
  if ("n" %in% annotations) {
    parts <- c(parts, "n = rows used by the cell")
  }
  if (display == "fit" && "shape" %in% annotations) {
    parts <- c(parts,
      "Shape glyph = objective shape category (see shape-types legend below)")
  }
  if (display == "fit" && "k_warn" %in% annotations) {
    parts <- c(parts,
      "! marks a cell flagged for possible k underfit or capped at the distinct predictor count")
  }
  where <- switch(colour_channel,
    border = "Cell border encodes",
    tile   = "Corner tile encodes",
    fill   = "Cell colour encodes"
  )
  colour_msg <- switch(colour_by,
    spearman     = "Spearman rank correlation (corr)",
    pearson      = "Pearson correlation (corr)",
    kendall      = "Kendall correlation (corr)",
    nonlinearity = "non-linearity, EDF - 1 (see right-margin legend)",
    asymmetry    = "the asymmetry index A of the pair, in [0, 1]",
    deviance_gap = paste(
      "the deviance gap: deviance explained by the",
      "smooth minus that of the straight-line fit"
    ),
    none         = NULL
  )
  if (!is.null(colour_msg)) parts <- c(parts, paste(where, colour_msg))
  if (background_by != "none") {
    parts <- c(parts, sprintf(
      "Cell background encodes %s of the pair%s: white at 0, deeper towards -1 and 1",
      .background_label(background_by),
      if (adjusted) ", marginal (before adjustment)" else ""
    ))
  } else if (adjusted) {
    parts <- c(parts,
      "No cell background: the curves are adjusted, the correlations marginal")
  }
  if (display == "fit" && "signif" %in% annotations) {
    parts <- c(parts,
      "Signif. of smooth F-test: *** p<.001, ** p<.01, * p<.05, \u00b7 p<.1")
  }
  if (display %in% c("d1", "d2")) {
    parts <- c(parts, sprintf(
      "Derivative panel: curve from D %%*%% coef(gam), dashed line at zero; CI mode = %s",
      derivative_ci
    ))
  }
  paste(parts, collapse = "\n")
}

# ---------------------------------------------------------------
# Finalise composite plot -- add title + optional caption in a
# single plot_annotation call so patchwork lays them out cleanly.
# ---------------------------------------------------------------

.finalize_plot <- function(composite, title, caption = NULL,
                           text_pt = .text_size_auto(4L), family = "") {
  composite +
    patchwork::plot_annotation(
      title   = if (is.na(text_pt$title)) NULL else title,
      caption = if (is.na(text_pt$glossary)) NULL else caption,
      theme = ggplot2::theme(
        plot.title   = .element_text_or_blank(
          text_pt$title,
          family     = family,
          face       = "bold",
          hjust      = 0,
          colour     = "grey10",
          margin     = ggplot2::margin(t = 2, b = 6)
        ),
        plot.caption = .element_text_or_blank(
          text_pt$glossary,
          family     = family,
          hjust      = 0,
          colour     = "grey25",
          lineheight = 1.1,
          margin     = ggplot2::margin(t = 8, b = 2)
        )
      )
    )
}

#' Deprecated: raw GAM fits and per-cell metrics
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `janusplot_data()` was renamed [janusplot_fit()] in janusplot 1.0.0 and
#' forwards every argument to it. The result is the `janusplot_fit`
#' object described there: `pvalue_yx` and `pvalue_xy` are now
#' `association_p_yx` and `association_p_xy`, and first and second
#' derivatives are computed by default.
#'
#' @inheritDotParams janusplot_fit -x -object
#'
#' @returns A `janusplot_fit` object; see [janusplot_fit()]. Its `call`
#'   component records the `janusplot_data()` call as made.
#'
#' @keywords internal
#' @export
janusplot_data <- function(...) {
  lifecycle::deprecate_soft(
    when = "1.0.0",
    what = "janusplot_data()",
    with = "janusplot_fit()"
  )
  out <- janusplot_fit(...)
  out$call <- match.call()
  out
}
