# Tests for plot.janusplot_fit(): the returned object, every colour_by
# value under each channel, the annotations vocabulary, display guards,
# the empty-dots rule, the drawing order, the cell renderer and the strip,
# and vdiffr snapshots of the default cell on the three canonical cases.

fit_two <- function(d, vars = c("x1", "x2"), ...) {
  janusplot_fit(d, vars = vars, engine = "gam", ...)
}

# One directed cell of a fit, rendered as plot() would render it.
render_face <- function(fit, pair = 1L, direction = "yx", ...,
                        style = janusplot_style()) {
  face <- janusplot:::.pair_face(fit$pairs[[pair]], direction)
  janusplot:::.render_cell(
    pair = fit$pairs[[pair]], direction = direction,
    points = janusplot:::.cell_points(fit, face$var_x, face$var_y),
    style = style, text_sizes = janusplot:::.cell_text_sizes(2L), ...
  )
}

layer_geoms <- function(p) {
  unname(vapply(p$layers, function(l) class(l$geom)[1L], character(1L)))
}

# ---------------------------------------------------------------
# Return value and the view arguments
# ---------------------------------------------------------------

test_that("the colour bars use no deprecated ggplot2 guide argument", {
  withr::local_options(lifecycle_verbosity = "error")
  fit <- fit_two(make_linear_data(n = 100L), vars = c("x1", "x2", "x3"))
  expect_no_error(plot(fit))
  expect_no_error(plot(fit, colour_by = "pearson", background_by = "none"))
})

test_that("plot() returns a patchwork, which is a ggplot", {
  fit <- fit_two(make_linear_data(n = 100L), vars = c("x1", "x2", "x3"))
  p <- plot(fit)
  expect_s3_class(p, "ggplot")
  expect_s3_class(p, "patchwork")
  expect_identical(
    names(formals(janusplot:::plot.janusplot_fit)),
    c("x", "colour_by", "background_by", "annotations", "order", "display",
      "group",
      "focus_by", "focus_threshold", "axes", "style", "...")
  )
})

test_that("every colour_by value builds under every channel", {
  fit <- fit_two(make_nonlinear_data(n = 120L), vars = c("x1", "x2", "x3"))
  for (cb in janusplot:::.colour_choices()) {
    for (ch in c("border", "tile", "fill")) {
      p <- plot(fit, colour_by = cb,
                background_by = if (ch == "fill") "none" else "pearson",
                style = janusplot_style(colour_channel = ch,
                                        show_shape_legend = FALSE))
      expect_s3_class(p, "ggplot")
    }
  }
})

test_that("colour_by = 'edf' is deprecated and mapped to nonlinearity", {
  fit <- fit_two(make_nonlinear_data(n = 100L))
  lifecycle::expect_deprecated(p <- plot(fit, colour_by = "edf"))
  expect_s3_class(p, "ggplot")
  expect_error(plot(fit, colour_by = "spearmann"), "must be one of")
})

test_that("colour limits follow the documented rules", {
  lim <- janusplot:::.colour_limits
  expect_identical(lim(c(0.2, 0.7, NA), "nonlinearity"), c(0, 1))
  expect_identical(lim(c(0.2, 2.5), "nonlinearity"), c(0, 2.5))
  expect_identical(lim(c(0.2, 0.7), "asymmetry"), c(0, 1))
  expect_identical(lim(c(0.2, 0.7), "pearson"), c(-1, 1))
  expect_identical(lim(c(0.2, 0.7), "deviance_gap"), c(0.2, 0.7))
  expect_identical(lim(c(0.2, 0.7), "none"), c(NA_real_, NA_real_))
  expect_identical(lim(c(NA_real_, NA_real_), "nonlinearity"),
                   c(NA_real_, NA_real_))
})

test_that("cell colours come from the scale the legend draws", {
  hex <- janusplot:::.colour_hex(c(0, 1, 2, NA), "nonlinearity", c(0, 2),
                                 "viridis")
  scale <- ggplot2::scale_fill_viridis_c(limits = c(0, 2))
  expect_identical(hex[1:3], scale$map(c(0, 1, 2)))
  expect_identical(hex[4L], NA_character_)
  expect_identical(janusplot:::.colour_hex(c(0.5, 1), "none", c(0, 1), "viridis"),
                   c(NA_character_, NA_character_))
  # A sequential palette under a correlation is replaced by RdBu.
  div <- janusplot:::.colour_hex(c(-1, 0, 1), "pearson", c(-1, 1), "viridis")
  expect_identical(toupper(div), c("#2166AC", "#F7F7F7", "#B2182B"))
})

test_that("annotations accept the seven names and reject others", {
  fit <- fit_two(make_nonlinear_data(n = 100L))
  p <- plot(fit, annotations = c("A", "edf", "signif", "code", "shape",
                                 "k_warn", "n"),
            style = janusplot_style(show_shape_legend = FALSE))
  expect_s3_class(p, "ggplot")
  expect_s3_class(plot(fit, annotations = character()), "ggplot")
  expect_error(plot(fit, annotations = c("A", "bogus")), "bogus")
  expect_error(plot(fit, annotations = c("A", "bogus")), "k_warn")
  expect_error(plot(fit, annotations = 1L), "character vector")
})

test_that("the default annotations drop A from eight variables", {
  expect_identical(janusplot:::.default_annotations(7L), c("A", "signif"))
  expect_identical(janusplot:::.default_annotations(8L), "signif")
  withr::local_seed(2026L)
  d <- as.data.frame(matrix(stats::rnorm(60L * 8L), 60L, 8L))
  names(d) <- paste0("x", 1:8)
  glossary <- function(p) p$patches$annotation$caption
  expect_match(glossary(plot(fit_two(d, vars = names(d)[1:3]))),
               "A = asymmetry index")
  fit8 <- fit_two(d, vars = names(d))
  expect_no_match(glossary(plot(fit8)), "A = asymmetry index")
  expect_match(glossary(plot(fit8, annotations = c("A", "signif"))),
               "A = asymmetry index")
})

test_that("the shape legend is attached by default only with the shape code", {
  fit <- fit_two(make_nonlinear_data(n = 100L))
  has_legend <- function(p) {
    identical(ggplot2::get_labs(p)$title, "Shape categories")
  }
  expect_false(has_legend(plot(fit)))
  expect_true(has_legend(plot(fit, annotations = c("code", "signif"))))
  expect_true(has_legend(plot(fit, style = janusplot_style(
    show_shape_legend = TRUE
  ))))
  expect_false(has_legend(plot(fit, annotations = "code",
    style = janusplot_style(show_shape_legend = FALSE))))
})

test_that("display = 'd1' / 'd2' need the order in the fit", {
  d <- make_nonlinear_data(n = 100L)
  fit <- fit_two(d)
  expect_s3_class(plot(fit, display = "d1"), "ggplot")
  expect_s3_class(plot(fit, display = "d2"), "ggplot")
  none <- fit_two(d, derivatives = integer())
  expect_error(plot(none, display = "d1"), "derivative order 1")
  expect_error(plot(none, display = "d2"), "janusplot_fit")
  first <- fit_two(d, derivatives = 1L)
  expect_s3_class(plot(first, display = "d1"), "ggplot")
  expect_error(plot(first, display = "d2"), "derivative order 2")
  expect_error(plot(fit, display = "d3"), "must be one of")
})

test_that("unknown arguments in ... are an error naming them", {
  fit <- fit_two(make_linear_data(n = 80L))
  expect_error(plot(fit, show_data = FALSE), "show_data")
  expect_error(plot(fit, show_data = FALSE), "janusplot_style")
  expect_error(plot(fit, palette = "magma", colour = "red"), "palette")
  expect_error(plot(fit, style = list(show_data = TRUE)), "janusplot_style")
})

test_that("order = 'hclust' and 'alphabetical' reorder the drawing only", {
  d <- make_linear_data(n = 100L)
  names(d) <- c("zulu", "bravo", "alpha", "mike")
  fit <- janusplot_fit(d, engine = "gam")
  expected <- janusplot:::.reorder_hclust(fit$data, fit$vars)
  expect_false(identical(expected, fit$vars))
  idx <- janusplot:::.cell_index(fit$pairs, expected)
  pr <- fit$pairs[[1L]]
  expect_identical(
    idx$key[idx$pair == 1L & idx$direction == "xy"],
    sprintf("%d_%d", match(pr$var_i, expected), match(pr$var_j, expected))
  )
  p_h <- plot(fit, order = "hclust", style = janusplot_style(show_shape_legend = FALSE))
  p_a <- plot(fit, order = "alphabetical", style = janusplot_style(show_shape_legend = FALSE))
  expect_s3_class(p_h, "ggplot")
  expect_s3_class(p_a, "ggplot")
  expect_identical(fit$vars, c("zulu", "bravo", "alpha", "mike"))
})

test_that("focus, axes and diagonal options render", {
  fit <- fit_two(make_nonlinear_data(n = 120L), vars = c("x1", "x2", "x3"))
  st <- janusplot_style(show_shape_legend = FALSE, diagonal = "density")
  expect_s3_class(plot(fit, focus_by = "edf", focus_threshold = "q50", style = st),
                  "ggplot")
  expect_s3_class(plot(fit, focus_by = "asymmetry", focus_threshold = 0.1,
                       axes = "standardised", style = st), "ggplot")
  expect_s3_class(plot(fit, axes = "rank",
                       style = janusplot_style(diagonal = "name", labels = "none")),
                  "ggplot")
  expect_error(plot(fit, focus_by = "nonsense"), "Unknown")
  expect_error(plot(fit, focus_by = c("edf", "asymmetry")), "single value")
  expect_error(plot(fit, axes = "log"), "must be one of")
})

test_that("plot() does not re-emit the fit-time messages", {
  d <- make_linear_data(n = 80L)
  d$x3 <- d$x1
  fit <- suppressWarnings(fit_two(d, vars = c("x1", "x2", "x3")))
  expect_identical(nrow(fit$flags$failed), 2L)
  expect_silent(p <- plot(fit, style = janusplot_style(show_shape_legend = FALSE)))
  expect_s3_class(p, "ggplot")
})

# ---------------------------------------------------------------
# The cell renderer, the face and the strip
# ---------------------------------------------------------------

test_that(".pair_face() exposes one direction under direction-free names", {
  fit <- fit_two(make_nonlinear_data(n = 120L))
  pr <- fit$pairs[[1L]]
  yx <- janusplot:::.pair_face(pr, "yx")
  xy <- janusplot:::.pair_face(pr, "xy")
  expect_identical(c(yx$var_x, yx$var_y), c("x1", "x2"))
  expect_identical(c(xy$var_x, xy$var_y), c("x2", "x1"))
  expect_identical(yx$edf, pr$edf_yx)
  expect_identical(xy$edf, pr$edf_xy)
  expect_identical(yx$pred, pr$pred_yx)
  expect_identical(xy$deriv, pr$deriv_xy)
  expect_identical(yx$shape, pr$shape_yx)
  expect_identical(yx$association_p, pr$association_p_yx)
  expect_identical(yx$asymmetry_index, pr$asymmetry_index)
  expect_identical(xy$n_used, pr$n_used)
  expect_false(yx$k_capped)
  expect_error(janusplot:::.pair_face(pr, "zz"), "must be one of")
})

test_that("the strip carries the requested annotations in order", {
  fit <- fit_two(make_nonlinear_data(n = 120L))
  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  strip <- janusplot:::.cell_strip_text
  expect_match(strip(face, c("A", "signif")), "^A 0\\.[0-9]{2}  \\**$")
  expect_match(strip(face, c("A", "edf", "signif")),
               "^A 0\\.[0-9]{2}  EDF [0-9]+\\.[0-9]  \\**$")
  expect_match(strip(face, c("A", "edf", "signif"), compact = TRUE),
               "^A 0\\.[0-9]{2} E [0-9]+\\.[0-9] \\**$")
  expect_match(strip(face, c("code", "n")), sprintf("^%s  n %d$", face$shape_code,
                                                     face$n_used))
  expect_null(strip(face, character()))
  expect_null(strip(face, "k_warn"))
  face$k_capped <- TRUE
  expect_identical(strip(face, "k_warn"), "!")
  expect_identical(strip(face, "k_warn", glyph_style = "unicode"), "\u26A0")
})

test_that("a shape label on a non-significant cell is marked n.s.", {
  fit <- fit_two(make_nonlinear_data(n = 120L))
  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  strip <- janusplot:::.cell_strip_text
  face$association_p <- 0.001
  expect_false(grepl("n.s.", strip(face, c("code", "shape")), fixed = TRUE))
  face$association_p <- 0.2
  expect_identical(strip(face, "code"), paste0(face$shape_code, "  n.s."))
  with_shape <- strip(face, c("code", "shape"))
  expect_identical(lengths(regmatches(with_shape,
                                      gregexpr("n.s.", with_shape, fixed = TRUE))), 1L)
  expect_false(grepl("n.s.", strip(face, c("A", "signif")), fixed = TRUE))
  # The adjusted p-value decides when the fit adjusted.
  face$association_p_adj <- 0.001
  expect_false(grepl("n.s.", strip(face, "code", p_adjust = "holm"),
                     fixed = TRUE))
})

test_that("the significance glyph follows the fit's p_adjust", {
  d <- make_nonlinear_data(n = 120L)
  raw  <- fit_two(d, vars = c("x1", "x2", "x3", "x4"))
  holm <- fit_two(d, vars = c("x1", "x2", "x3", "x4"), p_adjust = "holm")
  faces_raw  <- lapply(raw$pairs, janusplot:::.pair_face, direction = "xy")
  faces_holm <- lapply(holm$pairs, janusplot:::.pair_face, direction = "xy")
  g_raw  <- vapply(faces_raw, janusplot:::.face_signif, character(1L),
                   p_adjust = "none")
  g_adj  <- vapply(faces_holm, janusplot:::.face_signif, character(1L),
                   p_adjust = "holm")
  g_tbl  <- holm$table$signif[holm$table$position == "upper"]
  expect_identical(g_adj, g_tbl)
  expect_identical(g_raw, vapply(faces_raw, function(f) {
    janusplot:::.pvalue_to_glyph(f$association_p)
  }, character(1L)))
})

test_that(".render_cell() returns a plain ggplot with the default layers", {
  fit <- fit_two(make_nonlinear_data(n = 120L))
  cell <- render_face(fit, colour = "#440154FF")
  expect_s3_class(cell, "ggplot")
  expect_false(inherits(cell, "patchwork"))
  expect_identical(layer_geoms(cell), c("GeomPoint", "GeomRibbon", "GeomLine"))
  expect_match(cell$labels$subtitle, "^A 0\\.[0-9]{2}")
  # No points, no band.
  bare <- render_face(fit, style = janusplot_style(show_data = FALSE, show_ci = FALSE))
  expect_identical(layer_geoms(bare), "GeomLine")
  # Tier 1 drops the points and compacts the strip; tier 3 drops the
  # curve and the strip and shows the shape glyph.
  t1 <- render_face(fit, annotations = c("A", "edf", "signif"), tier = 1L)
  expect_identical(layer_geoms(t1), c("GeomRibbon", "GeomLine"))
  expect_match(t1$labels$subtitle, "^A 0\\.[0-9]{2} E ")
  t3 <- render_face(fit, tier = 3L)
  expect_identical(layer_geoms(t3), "GeomText")
  expect_null(t3$labels$subtitle)
})

test_that("the colour channels paint the cell as documented", {
  fit <- fit_two(make_nonlinear_data(n = 120L))
  border <- render_face(fit, colour = "#FDE725FF")
  expect_identical(border$theme$panel.border$colour, "#FDE725FF")
  expect_identical(border$theme$panel.border$linewidth, 2.4)
  tile <- render_face(fit, colour = "#FDE725FF",
                      style = janusplot_style(colour_channel = "tile"))
  expect_identical(tile$theme$panel.border$colour, "grey55")
  expect_true("GeomCustomAnn" %in% layer_geoms(tile))
  fill <- render_face(fit, colour = "#FDE725FF",
                      style = janusplot_style(colour_channel = "fill"))
  expect_identical(layer_geoms(fill)[1L], "GeomRect")
  expect_identical(fill$layers[[1L]]$aes_params$fill, "#FDE725FF")
  # No colour: grey border, no tile, no rect.
  none <- render_face(fit, colour = NA_character_,
                      style = janusplot_style(colour_channel = "tile"))
  expect_identical(none$theme$panel.border$colour, "grey55")
  expect_false("GeomCustomAnn" %in% layer_geoms(none))
  # Out of focus: grey wash first, no colour.
  dim <- render_face(fit, colour = "#FDE725FF", is_focused = FALSE)
  expect_identical(layer_geoms(dim)[1L], "GeomRect")
  expect_identical(dim$theme$panel.border$colour, "grey55")
})

test_that("corner annotations use the 0.2.0 placement", {
  fit <- fit_two(make_nonlinear_data(n = 120L))
  cell <- render_face(fit, annotations = c("A", "edf", "signif", "code", "n"),
                      style = janusplot_style(annotation_position = "corners"))
  expect_null(cell$labels$subtitle)
  labels <- unlist(lapply(cell$layers, function(l) l$aes_params$label))
  expect_true(any(grepl("^A = 0\\.[0-9]{2}\nEDF = [0-9.]+\nn = [0-9]+$", labels)))
  expect_true(any(labels == fit$pairs[[1L]]$shape_code_yx))
})

test_that("an empty cell says why", {
  d <- make_linear_data(n = 80L)
  d$x3 <- d$x1
  fit <- suppressWarnings(fit_two(d, vars = c("x1", "x3")))
  cell <- render_face(fit)
  labels <- unname(unlist(lapply(cell$layers, function(l) l$aes_params$label)))
  expect_identical(labels, "no fit")
  # A sparse pair beside a fittable one: pair 2 is (x1, x3).
  d <- make_linear_data(n = 40L)
  d$x3 <- NA_real_
  d$x3[1:3] <- c(0.1, 0.5, 0.9)
  fit <- suppressWarnings(fit_two(d, vars = c("x1", "x2", "x3")))
  expect_identical(fit$pairs[[2L]]$var_j, "x3")
  cell <- render_face(fit, pair = 2L)
  labels <- unname(unlist(lapply(cell$layers, function(l) l$aes_params$label)))
  expect_identical(labels, "n < 5")
})

test_that("derivative cells keep the zero line inside the panel", {
  fit <- fit_two(make_linear_data(n = 120L))
  cell <- render_face(fit, display = "d1")
  expect_identical(layer_geoms(cell),
                   c("GeomHline", "GeomBlank", "GeomRibbon", "GeomLine"))
  expect_match(cell$labels$subtitle, "^df/dx  n [0-9]+$")
  built <- ggplot2::ggplot_build(cell)
  y_range <- built$layout$panel_params[[1L]]$y.range
  expect_lte(y_range[1L], 0)
  expect_gte(y_range[2L], 0)
  # The derivative of a near-linear fit sits on one side of zero.
  deriv <- fit$pairs[[1L]]$deriv_yx[["1"]]
  expect_true(all(deriv$lo > 0) || all(deriv$hi < 0))
  # No band under show_ci = FALSE, and a unicode order label on request.
  bare <- render_face(fit, display = "d2",
                      style = janusplot_style(show_ci = FALSE, glyph_style = "unicode"))
  expect_identical(layer_geoms(bare), c("GeomHline", "GeomBlank", "GeomLine"))
  expect_match(bare$labels$subtitle, "^f\u2033  n [0-9]+$")
})

# ---------------------------------------------------------------
# vdiffr snapshots of the default cell on the three canonical cases
# ---------------------------------------------------------------

# The default cell as plot() draws it: border colour, Pearson background.
render_default <- function(fit, colour) {
  render_face(fit, colour = colour,
              background = janusplot:::.background_hex(
                fit$pairs[[1L]]$cor_pearson, "BuOr", 0.35
              ))
}

test_that("default cell on linear recovery matches snapshot", {
  skip_if_not_installed("vdiffr")
  fit <- fit_two(make_linear_data(n = 150L, seed = 1L))
  vdiffr::expect_doppelganger("cell-default-linear",
                              render_default(fit, "#440154FF"))
})

test_that("default cell on quadratic detection matches snapshot", {
  skip_if_not_installed("vdiffr")
  fit <- fit_two(make_nonlinear_data(n = 200L, seed = 2L))
  vdiffr::expect_doppelganger("cell-default-quadratic",
                              render_default(fit, "#FDE725FF"))
})

test_that("default cell on sinusoidal detection matches snapshot", {
  skip_if_not_installed("vdiffr")
  fit <- fit_two(make_nonlinear_data(n = 200L, seed = 2L), vars = c("x1", "x3"))
  vdiffr::expect_doppelganger("cell-default-sinusoidal",
                              render_default(fit, "#21908CFF"))
})

# ---------------------------------------------------------------
# Orientation, the corner key and the correlation background
# ---------------------------------------------------------------

# The matrix grid of plot(): the first member of the top row.
matrix_grid <- function(p) p$patches$plots[[1L]]

# The curve layer of a matrix cell, and its data.
cell_curve_layer <- function(cell) {
  Filter(function(l) inherits(l$geom, "GeomLine"), cell$layers)[[1L]]
}
cell_curve <- function(cell) cell_curve_layer(cell)$data

# The members of a patchwork: a wrap of patchworks keeps them all in
# $patches$plots; otherwise the last member is the object itself.
patch_members <- function(p) {
  members <- p$patches$plots
  if (!inherits(p, "plot_filler")) members <- c(members, list(p))
  members
}

# The face of the first pair whose response is `response`.
face_by_response <- function(fit, response) {
  pr <- fit$pairs[[1L]]
  janusplot:::.pair_face(pr, if (identical(pr$var_j, response)) "yx" else "xy")
}

test_that("every cell is row ~ s(column)", {
  d <- withr::with_seed(11L, {
    x <- stats::runif(300L, -3, 3)
    data.frame(x = x, y = x^2 + stats::rnorm(300L, sd = 0.5))
  })
  fit <- janusplot_fit(d, engine = "gam", derivatives = integer())
  tab <- summary(fit)
  # y = x^2 is non-linear one way only.
  expect_gt(tab$edf[tab$var_y == "y"], 3)
  expect_lt(tab$edf[tab$var_y == "x"], 1.5)
  p <- plot(fit, style = janusplot_style(show_shape_legend = FALSE))
  grid <- matrix_grid(p)
  # The 3 x 3 grid with its label row and column, by row: the cell at
  # (row y, column x) is member 8 and carries y ~ s(x).
  y_on_x <- face_by_response(fit, "y")
  expect_equal(cell_curve(grid[[8L]])$fit, y_on_x$pred$fit)
  expect_equal(range(cell_curve(grid[[8L]])$x), range(d$x))
  x_on_y <- face_by_response(fit, "x")
  expect_equal(cell_curve(grid[[6L]])$fit, x_on_y$pred$fit)
  expect_equal(range(cell_curve(grid[[6L]])$x), range(d$y))
  # The table names the upper cell x ~ s(y).
  expect_identical(tab$position[tab$var_y == "x"], "upper")
  expect_identical(tab$position[tab$var_y == "y"], "lower")
})

test_that("the corner key shows the first two variables", {
  fit <- fit_two(make_linear_data(n = 80L), vars = c("x1", "x2", "x3"))
  st <- janusplot_style(show_shape_legend = FALSE)
  key <- matrix_grid(plot(fit, style = st))[[1L]]
  labels <- key$layers[[2L]]$data$label
  expect_identical(labels[1L], "each cell:\nrow ~ s(column)")
  expect_true(all(c("x1 ~\ns(x2)", "x2 ~\ns(x1)") %in% labels))
  # A name past seven characters turns the key generic.
  expect_identical(janusplot:::.key_names(c("Solar.R", "Ozone")),
                   c("Solar.R", "Ozone"))
  expect_identical(janusplot:::.key_names(c("fixed acidity", "pH")),
                   c("v1", "v2"))
  expect_identical(janusplot:::.key_names(c("pH", "total sulfur dioxide")),
                   c("v1", "v2"))
  # show_key = FALSE leaves the corner empty.
  plain <- matrix_grid(plot(fit, style = janusplot_style(
    show_key = FALSE, show_shape_legend = FALSE
  )))
  expect_length(plain[[1L]]$layers, 0L)
})

test_that("the background blends from white by the signed correlation", {
  hex <- janusplot:::.background_hex
  expect_identical(hex(0), "#FFFFFF")
  blend <- function(end, at) {
    v <- grDevices::colorRamp(c("white", end))(at)
    grDevices::rgb(v[, 1L], v[, 2L], v[, 3L], maxColorValue = 255)
  }
  expect_identical(hex(1), blend("#B35806", 0.35))
  expect_identical(hex(-1), blend("#2166AC", 0.35))
  expect_identical(hex(-0.5, "PuOr", 1), blend("#542788", 0.5))
  expect_identical(hex(NA_real_), NA_character_)

  fit <- fit_two(make_nonlinear_data(n = 120L), vars = c("x1", "x2", "x3"))
  p <- plot(fit, style = janusplot_style(show_shape_legend = FALSE))
  grid <- matrix_grid(p)
  # Cell (row x1, column x2) has the Pearson r of the pair (x1, x2).
  expect_identical(grid[[7L]]$theme$panel.background$fill,
                   hex(fit$pairs[[1L]]$cor_pearson))
  # One bar per matrix, over [-1, 1] with a labelled tick at 0.
  bars <- patch_members(p$patches$plots[[2L]])
  bar <- bars[[length(bars)]]
  fill <- bar$scales$get_scales("fill")
  expect_identical(fill$breaks, c(-1, 0, 1))
  expect_identical(fill$limits, c(-1, 1))
  expect_identical(fill$name, "Background\n(Pearson r)")

  # Spearman picks the other correlation; "none" draws nothing.
  sp <- matrix_grid(plot(fit, background_by = "spearman",
                         style = janusplot_style(show_shape_legend = FALSE)))
  expect_identical(sp[[7L]]$theme$panel.background$fill,
                   hex(fit$pairs[[1L]]$cor_spearman))
  none <- plot(fit, background_by = "none",
               style = janusplot_style(show_shape_legend = FALSE))
  expect_true(is.na(matrix_grid(none)[[7L]]$theme$panel.background$fill))
  expect_false(any(vapply(patch_members(none$patches$plots[[2L]]),
                          function(b) {
                            identical(b$scales$get_scales("fill")$name,
                                      "Background\n(Pearson r)")
                          }, logical(1L))))
  expect_error(plot(fit, background_by = "rank"), "must be one of")
})

test_that("a fit with adjust draws no background unless one is asked for", {
  d <- make_nonlinear_data(n = 120L, seed = 2L)
  d$g <- factor(rep(c("a", "b", "c"), length.out = nrow(d)))
  fit <- fit_two(d, vars = c("x1", "x2", "x3"), adjust = ~ s(g, bs = "re"))
  style <- janusplot_style(show_shape_legend = FALSE)
  p <- plot(fit, annotations = c("A", "r"), style = style)
  expect_true(is.na(matrix_grid(p)[[7L]]$theme$panel.background$fill))
  caption <- p$patches$annotation$caption
  expect_match(caption, "No cell background: the curves are adjusted",
               fixed = TRUE)
  expect_match(caption, "r = Pearson r of the pair, marginal", fixed = TRUE)
  expect_match(matrix_grid(p)[[7L]]$labels$subtitle, "marginal r ",
               fixed = TRUE)
  asked <- plot(fit, background_by = "pearson", style = style)
  expect_identical(matrix_grid(asked)[[7L]]$theme$panel.background$fill,
                   janusplot:::.background_hex(fit$pairs[[1L]]$cor_pearson))
  expect_match(asked$patches$annotation$caption,
               "Pearson r of the pair, marginal (before adjustment)",
               fixed = TRUE)
  one_call <- janusplot(d, vars = c("x1", "x2", "x3"),
                        adjust = ~ s(g, bs = "re"), engine = "gam",
                        style = style)
  expect_true(is.na(matrix_grid(one_call)[[7L]]$theme$panel.background$fill))
})

test_that("the background and the fill channel are refused together", {
  fit <- fit_two(make_linear_data(n = 80L))
  err <- expect_error(
    plot(fit, style = janusplot_style(colour_channel = "fill"))
  )
  expect_match(conditionMessage(err), "background_by")
  expect_match(conditionMessage(err), "colour_channel")
  expect_s3_class(
    plot(fit, colour_by = "pearson", background_by = "none",
         style = janusplot_style(colour_channel = "fill")),
    "ggplot"
  )
})

test_that("the strip prints r and the formula on request", {
  fit <- fit_two(make_nonlinear_data(n = 120L))
  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  strip <- janusplot:::.cell_strip_text
  expect_identical(strip(face, "formula"), "x2 ~ x1")
  expect_identical(strip(face, "r"),
                   sprintf("r %.2f", fit$pairs[[1L]]$cor_pearson))
  expect_identical(strip(face, "r", background_by = "kendall"),
                   sprintf("r %.2f", fit$pairs[[1L]]$cor_kendall))
  expect_identical(strip(face, "r", background_by = "none"),
                   sprintf("r %.2f", fit$pairs[[1L]]$cor_pearson))
  face$cor_pearson <- -0.001
  expect_identical(strip(face, "r"), "r 0.00")
  face$cor_pearson <- -0.03
  expect_identical(strip(face, c("formula", "A", "r")),
                   sprintf("x2 ~ x1  A %.2f  r -0.03", face$asymmetry_index))
  expect_identical(strip(face, "r", adjusted = TRUE), "marginal r -0.03")
  expect_s3_class(plot(fit, annotations = c("formula", "r")), "ggplot")
})

test_that("text_size reaches every text of the matrix", {
  fit <- fit_two(make_nonlinear_data(n = 120L), vars = c("x1", "x2", "x3"))
  p <- plot(fit, style = janusplot_style(
    show_shape_legend = FALSE,
    text_size = list(strip = 7, title = NULL, glossary = NULL, key = NULL)
  ))
  grid <- matrix_grid(p)
  expect_identical(grid[[7L]]$theme$plot.subtitle$size, 7)
  expect_null(p$patches$annotation$title)
  expect_null(p$patches$annotation$caption)
  expect_length(grid[[1L]]$layers, 0L)
  # Border labels in points.
  label <- grid[[2L]]$layers[[1L]]$aes_params$size
  expect_equal(label * ggplot2::.pt, 10)
  # No text at all still draws the cells.
  bare <- plot(fit, style = janusplot_style(text_size = NULL,
                                            show_shape_legend = FALSE))
  bare_grid <- matrix_grid(bare)
  expect_s3_class(bare_grid[[7L]]$theme$plot.subtitle, "element_blank")
  expect_length(bare_grid[[2L]]$layers, 0L)
  expect_identical(layer_geoms(bare_grid[[7L]]),
                   c("GeomPoint", "GeomRibbon", "GeomLine"))
  # The coloured border and the curve take their widths in points.
  wide <- matrix_grid(plot(fit, style = janusplot_style(
    border_width = 4, curve_width = 1, show_shape_legend = FALSE
  )))
  expect_equal(wide[[7L]]$theme$panel.border$linewidth, 4 / ggplot2::.pt)
  expect_equal(cell_curve_layer(wide[[7L]])$aes_params$linewidth,
               1 / ggplot2::.pt)
})

test_that("janusplot() passes background_by and has 14 formals", {
  expect_identical(
    names(formals(janusplot)),
    c("data", "vars", "adjust", "colour_by", "background_by", "annotations",
      "order", "display", "group", "focus_by", "focus_threshold", "axes",
      "style", "...")
  )
  d <- make_linear_data(n = 80L)
  p <- janusplot(d, vars = c("x1", "x2"), engine = "gam",
                 background_by = "none",
                 style = janusplot_style(show_shape_legend = FALSE))
  expect_true(is.na(matrix_grid(p)[[6L]]$theme$panel.background$fill))
})
