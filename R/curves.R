# curves.R -- janusplot_curves(): the fitted curves of a janusplot_fit as
# one long data frame, so a caller can draw them with ggplot2 or any other
# tool without reaching into the pair list. Nothing is refitted.

#' Fitted curves of a janusplot fit as a data frame
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns the curves a [janusplot_fit()] object stores, one row per grid
#' point of every directed cell, for drawing with ggplot2 or any other
#' tool. The fitted curves come with their 95 percent band; the
#' derivative curves, when the fit computed them, with theirs. Nothing is
#' refitted.
#'
#' @details
#' A cell `var_y ~ s(var_x)` is identified by `var_x` and `var_y`, and by
#' `position` as in `summary()`: `"upper"` when `var_y` comes first in
#' `fit$vars`. The fitted curve is on the response scale and its band is
#' mapped from the link scale, as in the plots. Under `adjust` with the
#' identity link, the curve is averaged over the adjustment covariates
#' (see [janusplot_fit()]). Cells that failed to fit have no rows.
#'
#' @param fit A `janusplot_fit` object from [janusplot_fit()].
#' @param x,y Two variable names of `fit$vars` to return both directions
#'   of that pair only, or `NULL` (the default) for every pair.
#' @param what `"fit"` (the default) for the fitted curves, `"d1"` or
#'   `"d2"` for the first or second derivative, which need that order in
#'   `fit$settings$derivatives`.
#'
#' @returns A data frame with columns `var_x`, `var_y`, `position`, `x`,
#'   `fit`, `se` (on the link scale), `lo` and `hi`, one row per grid
#'   point of each directed cell.
#'
#' @family smooth-associations
#' @seealso [summary.janusplot_fit()] for the per-cell numbers.
#'
#' @examples
#' fit <- janusplot_fit(airquality[, c("Ozone", "Temp", "Wind")],
#'                      engine = "gam")
#' curves <- janusplot_curves(fit, "Temp", "Ozone")
#' head(curves)
#'
#' # Both directions of the pair on shared axes.
#' library(ggplot2)
#' ggplot(curves, aes(x, fit, colour = var_y)) +
#'   geom_ribbon(aes(ymin = lo, ymax = hi, fill = var_y), alpha = 0.2,
#'               colour = NA) +
#'   geom_line() +
#'   facet_wrap(~ var_y, scales = "free")
#' @export
janusplot_curves <- function(fit, x = NULL, y = NULL,
                             what = c("fit", "d1", "d2")) {
  .check_fit_object(fit)
  what <- rlang::arg_match(what)
  .check_display_available(what, fit$settings$derivatives)
  pairs <- fit$pairs
  if (!is.null(x) || !is.null(y)) {
    if (is.null(x) || is.null(y)) {
      cli::cli_abort("Give both {.arg x} and {.arg y}, or neither.")
    }
    .check_fit_pair(fit, x, y)
    pairs <- pairs[.find_pair(fit, x, y)]
  }
  rows <- list()
  for (p in pairs) {
    for (direction in c("yx", "xy")) {
      face <- .pair_face(p, direction)
      df <- if (what == "fit") {
        face$pred
      } else {
        face$deriv[[if (what == "d1") "1" else "2"]]
      }
      if (is.null(df) || !nrow(df) || all(is.na(df$fit))) next
      rows[[length(rows) + 1L]] <- data.frame(
        var_x    = face$var_x,
        var_y    = face$var_y,
        position = if (direction == "xy") "upper" else "lower",
        x        = df$x,
        fit      = df$fit,
        se       = df$se,
        lo       = df$lo,
        hi       = df$hi,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) {
    return(data.frame(var_x = character(), var_y = character(),
                      position = character(), x = numeric(),
                      fit = numeric(), se = numeric(), lo = numeric(),
                      hi = numeric(), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
