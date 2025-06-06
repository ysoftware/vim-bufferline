let s:updatetime = &updatetime
let s:window_start = 0

function! bufferline#truncate_middle(str) abort
    let maxlen = 33
    let keep_right = 10
    if strlen(a:str) <= maxlen
        return a:str
    endif
    let keep_left = maxlen - keep_right - 1
    let left = strpart(a:str, 0, keep_left)
    let right = strpart(a:str, strlen(a:str) - keep_right, keep_right)
    return left . '*' . right
endfunction

function! s:echo()
    if &filetype ==# 'unite'
        return
    endif

    redraw

    let current_buffer = bufnr('%')
    let last_buffer    = bufnr('$')
    let added_buffer   = 1

    " 12 is magical and is the threshold for when it doesn't wrap text anymore
    let width = &columns - 12
    let built = ''

    let items = []
    for i in range(1, last_buffer)
        if bufexists(i) && buflisted(i)
            let is_modified = getbufvar(i, '&mod')
            let modified = is_modified ? g:bufferline_modified : ''
            let full_name = fnamemodify(bufname(i), ':p')
            let fname = fnamemodify(full_name, g:bufferline_fname_mod)

            let hl = 'BufferLine'

            if exists('g:bufferline_custom_pattern_indicator') && type(g:bufferline_custom_pattern_indicator) == type([])
                for pattern_pair in g:bufferline_custom_pattern_indicator
                    if len(pattern_pair) == 2
                        let patt = pattern_pair[0]
                        if len(full_name) > 0 && full_name =~ glob2regpat(patt)
                            let hl = pattern_pair[1]
                            break
                        endif
                    endif
                endfor
            endif

            if current_buffer == i
                let hl = hl . 'Active'
            endif

            if is_modified
                let hl = hl . 'Modified'
            endif

            if g:bufferline_pathshorten != 0
                let fname = pathshorten(fname)
            endif
            let fname = substitute(fname, '%', '%%', 'g')

            let skip = 0
            for ex in g:bufferline_excludes
                if match(fname, ex) > -1
                    let skip = 1
                    break
                endif
            endfor

            if !skip
                let name = ''

                if g:bufferline_show_bufnr != 0 && g:bufferline_status_info.count >= g:bufferline_show_bufnr
                    let name = i . ' '
                elseif g:bufferline_show_bufpos != 0
                    let name = added_buffer . ' '
                endif
                let name .= fname . modified
                let name = trim(name)

                if current_buffer == i
                    let name = g:bufferline_active_buffer_left . name . g:bufferline_active_buffer_right
                    let g:bufferline_status_info.current = name
                else
                    let name = name
                endif

                let name = bufferline#truncate_middle(name)
                call add(items, [i, name, hl])
                let added_buffer += 1
            endif
        endif
    endfor

    let built = ''
    let width = &columns - 12
    for item in items
        let fragment = item[1]
        let hl = item[2]
        let sep = g:bufferline_separator
        let new_len = strlen(built) + strlen(fragment) + strlen(sep)
        if new_len > width
            break
        endif

        let idx = match(built, '\V' . g:bufferline_status_info.current)
        let built .= fragment . sep
        if idx >= 0
            let g:bufferline_status_info.before = strpart(built, 0, idx)
            let g:bufferline_status_info.after  = strpart(built, idx + len(g:bufferline_status_info.current))
        endif
        execute 'echohl ' . hl
        execute 'echon '  . string(fragment)
        execute 'echohl Normal'
        execute 'echon " "'
        echohl None
    endfor

    echohl None

    if &updatetime != s:updatetime
        let &updatetime = s:updatetime
    endif
endfunction

function! s:cursorhold_callback()
    call s:echo()
    autocmd! bufferline CursorHold
endfunction

function! s:refresh(updatetime)
    let &updatetime = a:updatetime
    autocmd bufferline CursorHold * call s:cursorhold_callback()
endfunction

function! bufferline#init_echo()
    augroup bufferline
        au!

        " events which output a message which should be immediately overwritten
        autocmd BufWinEnter,WinEnter,InsertLeave,VimResized * call s:refresh(1)
        autocmd BufWrite * call s:refresh(1000)
    augroup END

    autocmd CursorHold * call s:echo()
endfunction
