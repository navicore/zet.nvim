function! zettlekast#calendar_action(day, month, year, week, dir)
    call luaeval('require("zettlekast.calendar").calendar_action(_A[1], _A[2], _A[3], _A[4], _A[5])',
        \ [str2nr(a:day), str2nr(a:month), str2nr(a:year), a:week, a:dir])
endfunction

function! zettlekast#calendar_sign(day, month, year)
    return luaeval('require("zettlekast.calendar").calendar_sign(_A[1], _A[2], _A[3])',
        \ [a:day, a:month, a:year])
endfunction
