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
      $pt
      $pt$strip
      [1] 8
      
      $pt$labels
      [1] 10
      
      $pt$diagonal
      [1] 14.79543
      
      $pt$legend
      [1] 9
      
      $pt$key
      [1] 5.5
      
      $pt$glossary
      [1] 9
      
      $pt$title
      [1] 13
      
      $pt$axis
      [1] 8
      
      
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
      $pt
      $pt$strip
      [1] 5
      
      $pt$labels
      [1] 10
      
      $pt$diagonal
      [1] 7.630348
      
      $pt$legend
      [1] 9
      
      $pt$key
      [1] 5
      
      $pt$glossary
      [1] 9
      
      $pt$title
      [1] 13
      
      $pt$axis
      [1] 5
      
      
      $n_edf
      [1] 2.5
      
      $glyph
      [1] 2.875
      
      $asym
      [1] 2.375
      
      $shape
      [1] 3.75
      
      $empty
      [1] 2
      
      $diag
      [1] 2.681761
      

