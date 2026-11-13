" Start highlighting inside a long nested block, without visiting its start.
call setline(1, ['bar {'] + repeat(['    # filler'], 100)
      \ + ['    colors {'] + repeat(['        # filler'], 100)
      \ + ['        background #000000', '    }', '}'])
setfiletype i3config
call assert_equal('i3ConfigColorsOpts', synIDattr(synID(203, 9, 1), 'name'))
call assert_equal('i3ConfigColor', synIDattr(synID(203, 20, 1), 'name'))
if !empty(v:errors)
  for error in v:errors
    echom error
  endfor
  cquit
endif
qa!
