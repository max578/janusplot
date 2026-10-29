# print() states the verdict, reason, p-values and rows

    Code
      print(res)
    Output
      janusplot direction test: x -> y against y -> x
      verdict: forward (x -> y), reason forward_only
        Residuals of the fit x -> y are independent of x (p = 0.995), while
        residuals of the fit y -> x remain dependent on y (p = 0.005). The
        additive-noise model holds in the forward direction only.
      HSIC residual independence (alpha = 0.05):
        x -> y  p = 0.995
        y -> x  p = 0.005
      n_used = 300 of n = 300 complete cases

---

    Code
      print(below)
    Output
      janusplot direction test: x -> y against y -> x
      verdict: undecided (no direction), reason n_below_min
        n below n_min
      HSIC residual independence (alpha = 0.05):
        x -> y  not tested
        y -> x  not tested
      n_used = 25 of n = 25 complete cases

