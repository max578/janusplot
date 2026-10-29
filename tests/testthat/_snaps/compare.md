# print() gives the counts, the changed rows and the settings line

    Code
      print(cmp)
    Output
      janusplot comparison: marginal against group-adjusted
      3 variables (x, y, z), 3 pairs, 6 directed cells
      adjust: marginal = none, group-adjusted = ~g
      From marginal to group-adjusted, the shape changed in 4 of 6 directed cells (3 of 3 pairs) and the archetype in 3.
      Cells whose shape changed:
        x ~ s(y): shape bi_wave_ripple -> s_shape, EDF 8.64 -> 3.02, A 0.21 -> 0.50
        x ~ s(z): shape s_shape -> concave_up, EDF 1.00 -> 1.00, A 0.78 -> 0.78
        y ~ s(x): shape rippled_wave -> linear_up, EDF 5.59 -> 1.00, A 0.21 -> 0.50
        y ~ s(z): shape skewed_peak -> concave_up, EDF 2.34 -> 1.00, A 0.55 -> 0.78

---

    Code
      print(same)
    Output
      janusplot comparison: run 1 against run 2
      3 variables (x, y, z), 3 pairs, 6 directed cells
      adjust: run 1 = ~g, run 2 = ~g
      From run 1 to run 2, the shape changed in 0 of 6 directed cells (0 of 3 pairs) and the archetype in 0.
      No shape label changed.

---

    Code
      print(janusplot_compare(simpson$fit_a, fit_k, labels = c("marginal",
        "adjusted, k = 5")))
    Output
      janusplot comparison: marginal against adjusted, k = 5
      3 variables (x, y, z), 3 pairs, 6 directed cells
      adjust: marginal = none, adjusted, k = 5 = ~g
      From marginal to adjusted, k = 5, the shape changed in 6 of 6 directed cells (3 of 3 pairs) and the archetype in 5.
      Cells whose shape changed:
        x ~ s(y): shape bi_wave_ripple -> s_shape, EDF 8.64 -> 2.78, A 0.21 -> 0.47
        x ~ s(z): shape s_shape -> concave_up, EDF 1.00 -> 1.00, A 0.78 -> 0.60
        y ~ s(x): shape rippled_wave -> linear_up, EDF 5.59 -> 1.00, A 0.21 -> 0.47
        y ~ s(z): shape skewed_peak -> concave_up, EDF 2.34 -> 1.00, A 0.55 -> 0.59
        z ~ s(x): shape bimodal -> warped_wave, EDF 8.22 -> 3.98, A 0.78 -> 0.60
        z ~ s(y): shape bimodal_ripple -> wave, EDF 8.01 -> 3.89, A 0.55 -> 0.59
      The fits also differ in k, so a changed label may come from that setting as well as from the adjustment.

