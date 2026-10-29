# Tests for janusplot_compare(): the per-cell table, its validation, the
# print() counts and the plot() method with both curves per cell. A
# synthetic Simpson case: within each of three groups the slope of y on x
# is positive, between groups the trend is negative.

make_simpson <- function(n_group = 60L) {
  withr::local_seed(2026L)
  g <- rep(c("g1", "g2", "g3"), each = n_group)
  mu <- c(g1 = 0, g2 = 2.5, g3 = 5)[g]
  x <- mu + stats::rnorm(length(g))
  data.frame(
    x = x,
    y = -1.5 * mu + 0.8 * (x - mu) + stats::rnorm(length(g), sd = 0.4),
    z = sin(x) + stats::rnorm(length(g), sd = 0.3),
    w = stats::rnorm(length(g)),
    g = factor(g)
  )
}

fit_simpson <- function(d = make_simpson(), vars = c("x", "y", "z"), ...) {
  suppressMessages(
    janusplot_fit(d, vars, engine = "gam", derivatives = integer(), ...)
  )
}

compare_columns <- c(
  "var_x", "var_y", "position", "n_used_a", "n_used_b",
  "edf_a", "edf_b", "delta_edf", "A_a", "A_b", "delta_A",
  "shape_a", "shape_b", "shape_changed",
  "archetype_a", "archetype_b", "archetype_changed"
)

sort_cells <- function(tab) {
  out <- tab[order(tab$var_x, tab$var_y), , drop = FALSE]
  rownames(out) <- NULL
  out
}

simpson <- local({
  d <- make_simpson()
  list(
    d = d,
    fit_a = fit_simpson(d),
    fit_b = fit_simpson(d, adjust = ~ g)
  )
})

# ---------------------------------------------------------------
# The object and its table
# ---------------------------------------------------------------

test_that("janusplot_compare() returns the class and the 17 columns in order", {
  cmp <- janusplot_compare(simpson$fit_a, simpson$fit_b)
  expect_s3_class(cmp, c("janusplot_compare", "list"), exact = TRUE)
  expect_named(cmp, c("table", "fit_a", "fit_b", "labels"))
  expect_identical(names(cmp$table), compare_columns)
  expect_identical(nrow(cmp$table), 6L)
  expect_identical(cmp$labels, c("A", "B"))
  expect_type(cmp$table$shape_changed, "logical")
  expect_type(cmp$table$archetype_changed, "logical")
  # Rows follow summary(fit_a), position comes from A.
  tab_a <- summary(simpson$fit_a)
  expect_identical(cmp$table$var_x, tab_a$var_x)
  expect_identical(cmp$table$var_y, tab_a$var_y)
  expect_identical(cmp$table$position, tab_a$position)
})

test_that("deltas are B minus A, row by row, against summary() of each fit", {
  cmp <- janusplot_compare(simpson$fit_a, simpson$fit_b)
  tab_a <- summary(simpson$fit_a)
  tab_b <- summary(simpson$fit_b)
  for (r in seq_len(nrow(cmp$table))) {
    row <- cmp$table[r, ]
    b <- tab_b[tab_b$var_x == row$var_x & tab_b$var_y == row$var_y, ]
    a <- tab_a[tab_a$var_x == row$var_x & tab_a$var_y == row$var_y, ]
    expect_identical(nrow(b), 1L)
    expect_equal(row$edf_a, a$edf)
    expect_equal(row$edf_b, b$edf)
    expect_equal(row$delta_edf, b$edf - a$edf)
    expect_equal(row$delta_A, b$asymmetry_index - a$asymmetry_index)
    expect_identical(row$n_used_b, b$n_used)
    expect_identical(row$shape_b, b$shape_category)
    expect_identical(row$shape_changed, a$shape_category != b$shape_category)
    expect_identical(row$archetype_changed,
                     a$shape_archetype != b$shape_archetype)
  }
  # The Simpson reversal: y ~ s(x) is linear and increasing once the group
  # enters the model.
  yx <- cmp$table[cmp$table$var_x == "x" & cmp$table$var_y == "y", ]
  expect_identical(yx$shape_b, "linear_up")
  expect_true(yx$shape_changed)
})

test_that("cells are matched by name whatever order either fit stored", {
  ref <- janusplot_compare(simpson$fit_a, simpson$fit_b)
  fit_b_rev <- fit_simpson(simpson$d, vars = c("z", "y", "x"), adjust = ~ g)
  cmp <- janusplot_compare(simpson$fit_a, fit_b_rev)
  expect_equal(sort_cells(cmp$table), sort_cells(ref$table))

  # With A reordered, only position (taken from A) may differ.
  fit_a_rev <- fit_simpson(simpson$d, vars = c("z", "y", "x"))
  cmp_rev <- janusplot_compare(fit_a_rev, simpson$fit_b)
  keep <- setdiff(compare_columns, "position")
  expect_equal(sort_cells(cmp_rev$table)[, keep],
               sort_cells(ref$table)[, keep])
})

test_that("a variable mismatch lists the variables only in A and only in B", {
  fit_w <- fit_simpson(simpson$d, vars = c("x", "y", "w"))
  expect_error(
    janusplot_compare(simpson$fit_a, fit_w),
    "same variables"
  )
  err <- tryCatch(janusplot_compare(simpson$fit_a, fit_w),
                  error = function(e) conditionMessage(e))
  expect_match(err, "Only in `fit_a`: \"z\"", fixed = TRUE)
  expect_match(err, "Only in `fit_b`: \"w\"", fixed = TRUE)
})

test_that("non-fit inputs and bad labels are refused", {
  expect_error(janusplot_compare(summary(simpson$fit_a), simpson$fit_b),
               "fit_a")
  expect_error(janusplot_compare(simpson$fit_a, list()), "fit_b")
  bad <- list("A", c("A", "B", "C"), c("A", NA), c("A", ""), c(1, 2))
  for (lab in bad) {
    expect_error(
      janusplot_compare(simpson$fit_a, simpson$fit_b, labels = lab),
      "two non-empty strings"
    )
  }
  expect_error(
    janusplot_compare(simpson$fit_a, simpson$fit_b, labels = c("m", "m")),
    "differently"
  )
})

test_that("shape_changed is NA when a side failed", {
  d_fail <- simpson$d
  d_fail$z <- 1
  fit_fail <- suppressWarnings(fit_simpson(d_fail, adjust = ~ g))
  cmp <- janusplot_compare(simpson$fit_a, fit_fail)
  touches_z <- cmp$table$var_x == "z" | cmp$table$var_y == "z"
  expect_true(all(is.na(cmp$table$edf_b[touches_z])))
  expect_true(all(is.na(cmp$table$shape_changed[touches_z])))
  expect_true(all(is.na(cmp$table$archetype_changed[touches_z])))
  expect_false(anyNA(cmp$table$shape_changed[!touches_z]))
  expect_output(print(cmp), "4 directed cells with a failed fit on one side are not compared")
  expect_s3_class(plot(cmp), "ggplot")
})

# ---------------------------------------------------------------
# print()
# ---------------------------------------------------------------

test_that("print() says one pair for a two-variable comparison", {
  d <- make_simpson()
  cmp <- janusplot_compare(fit_simpson(d, vars = c("x", "y")),
                           fit_simpson(d, vars = c("x", "y"), adjust = ~ g))
  lines <- testthat::capture_output_lines(print(cmp))
  expect_match(lines[2L], "^2 variables \\(x, y\\), 1 pair, 2 directed cells$")
})

test_that("print() gives the counts, the changed rows and the settings line", {
  cmp <- janusplot_compare(simpson$fit_a, simpson$fit_b,
                           labels = c("marginal", "group-adjusted"))
  expect_snapshot(print(cmp))
  expect_output(shown <- withVisible(print(cmp)), "shape changed")
  expect_false(shown$visible)
  expect_identical(shown$value, cmp)

  same <- janusplot_compare(simpson$fit_b, simpson$fit_b,
                            labels = c("run 1", "run 2"))
  expect_snapshot(print(same))

  fit_k <- fit_simpson(simpson$d, adjust = ~ g, k = 5L)
  expect_snapshot(print(janusplot_compare(
    simpson$fit_a, fit_k, labels = c("marginal", "adjusted, k = 5")
  )))
})

# ---------------------------------------------------------------
# plot()
# ---------------------------------------------------------------

test_that("plot() returns a ggplot with group, hclust order and errors on dots", {
  cmp <- janusplot_compare(simpson$fit_a, simpson$fit_b)
  expect_s3_class(plot(cmp), "ggplot")
  expect_s3_class(plot(cmp, group = "g"), "ggplot")
  expect_s3_class(plot(cmp, order = "hclust"), "ggplot")
  expect_s3_class(
    plot(cmp, order = "alphabetical",
         style = janusplot_style(glyph_style = "unicode", diagonal = "name")),
    "ggplot"
  )
  expect_error(plot(cmp, colour_by = "asymmetry"), "colour_by")
  expect_error(plot(cmp, group = "nope"), "nope")
  expect_error(plot(cmp, style = list()), "janusplot_style")
})

test_that("a changed cell carries the red border and both curves", {
  cmp <- janusplot_compare(simpson$fit_a, simpson$fit_b)
  face <- function(fit, x, y) {
    p <- Filter(function(p) setequal(c(p$var_i, p$var_j), c(x, y)), fit$pairs)
    janusplot:::.pair_face(p[[1L]], if (p[[1L]]$var_i == x) "yx" else "xy")
  }
  render <- function(x, y, ...) {
    row <- cmp$table[cmp$table$var_x == x & cmp$table$var_y == y, ]
    janusplot:::.render_compare_cell(
      face_a = face(simpson$fit_a, x, y),
      face_b = face(simpson$fit_b, x, y),
      points = janusplot:::.cell_points(simpson$fit_b, x, y),
      shape_changed = row$shape_changed,
      style = janusplot_style(),
      text_sizes = janusplot:::.cell_text_sizes(3L), ...
    )
  }
  changed <- render("x", "y")
  border <- changed$theme$panel.border
  expect_identical(border$colour, "#b2182b")
  expect_identical(border$linewidth, 1.2)
  geoms <- unname(vapply(changed$layers, function(l) class(l$geom)[1L],
                         character(1L)))
  expect_identical(geoms, c("GeomPoint", "GeomRibbon", "GeomLine", "GeomLine"))
  expect_identical(changed$layers[[3L]]$aes_params$colour, "grey45")
  expect_identical(changed$layers[[3L]]$aes_params$linetype, "dashed")
  expect_identical(changed$layers[[4L]]$aes_params$colour,
                   janusplot_style()$curve_colour)
  expect_match(changed$labels$subtitle, "^EDF [0-9.]+ -> [0-9.]+$")

  unchanged <- cmp$table[!cmp$table$shape_changed, ][1L, ]
  plain <- render(unchanged$var_x, unchanged$var_y)
  expect_identical(plain$theme$panel.border$colour, "grey55")
  expect_identical(plain$theme$panel.border$linewidth, 0.35)

  compact <- render("x", "y", tier = 2L)
  geoms <- unname(vapply(compact$layers, function(l) class(l$geom)[1L],
                         character(1L)))
  expect_identical(geoms, c("GeomLine", "GeomLine"))
  expect_match(compact$labels$subtitle, "^E ")
})

test_that("the unicode glyph style draws the unicode arrow", {
  expect_identical(janusplot:::.compare_arrow("unicode"), intToUtf8(8594L))
  expect_identical(janusplot:::.compare_arrow("ascii"), "->")
})

test_that("default compare plot matches snapshot", {
  skip_if_not_installed("vdiffr")
  cmp <- janusplot_compare(simpson$fit_a, simpson$fit_b,
                           labels = c("marginal", "group-adjusted"))
  vdiffr::expect_doppelganger("compare-default-simpson", plot(cmp))
})
