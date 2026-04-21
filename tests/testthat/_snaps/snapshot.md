# p-value glyph ladder matches snapshot

    Code
      lapply(c(1e-04, 0.005, 0.03, 0.08, 0.5, NA_real_), janusplot:::.pvalue_to_glyph)
    Output
      [[1]]
      [1] "***"
      
      [[2]]
      [1] "**"
      
      [[3]]
      [1] "*"
      
      [[4]]
      [1] "·"
      
      [[5]]
      [1] ""
      
      [[6]]
      [1] ""
      

# palette choice vector matches snapshot

    Code
      janusplot:::.palette_choices()
    Output
       [1] "viridis"  "magma"    "inferno"  "plasma"   "cividis"  "mako"    
       [7] "rocket"   "turbo"    "RdYlBu"   "RdBu"     "PuOr"     "Spectral"
      [13] "YlOrRd"   "YlGnBu"   "Blues"    "Greens"  

# .cell_text_sizes output at k = 3 matches snapshot

    Code
      janusplot:::.cell_text_sizes(3L)
    Output
      $n_edf
      [1] 4
      
      $glyph
      [1] 4.6
      
      $asym
      [1] 3.8
      
      $shape
      [1] 6
      
      $empty
      [1] 3.2
      
      $diag
      [1] 5.2
      

# .cell_text_sizes output at k = 10 matches snapshot

    Code
      janusplot:::.cell_text_sizes(10L)
    Output
      $n_edf
      [1] 2.062893
      
      $glyph
      [1] 2.372327
      
      $asym
      [1] 1.959748
      
      $shape
      [1] 3.094339
      
      $empty
      [1] 1.650314
      
      $diag
      [1] 2.681761
      

