let s:updatetime = &updatetime
let s:window_start = 0

function! bufferline#truncate_middle(str) abort
    let maxlen = 40
    let keep_right = 9
    if strlen(a:str) <= maxlen
        return a:str
    endif
    let keep_left = maxlen - keep_right - 1
    let left = strpart(a:str, 0, keep_left)
    let right = strpart(a:str, strlen(a:str) - keep_right, keep_right)
    return left . '…' . right
endfunction

function! s:fixed_position_modify(items)
    let current = bufnr('%')
    while len(a:items) > 0 && a:items[g:bufferline_fixed_index - 1][0] != current
        let first = remove(a:items, 0)
        call add(a:items, first)
    endwhile
endfunction

function! s:apply_window_rotation(line, current_buffer_pos)
    let width = &columns - 12
    if g:bufferline_rotate == 2
        let current_buffer_start = a:current_buffer_pos[0]
        let current_buffer_end = a:current_buffer_pos[1]

        if current_buffer_start >= 0
            if current_buffer_start < s:window_start
                let s:window_start = current_buffer_start
            endif

            if current_buffer_end >= (s:window_start + width)
                let s:window_start = current_buffer_end - width + 1
            endif

            if s:window_start < 0
                let s:window_start = 0
            endif

            let max_start = strlen(a:line) - width
            if max_start > 0 && s:window_start > max_start
                let s:window_start = max_start
            endif
        endif

        return strpart(a:line, s:window_start, width)
    else
        return strpart(a:line, 0, width)
    endif
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

    if (g:bufferline_rotate == 1) && len(items) > g:bufferline_fixed_index
        call s:fixed_position_modify(items)
    endif

    let built = ''
    let width = &columns - 12
    let current_buffer_pos = [-1, -1]

    for item in items
        let fragment = item[1]
        let hl = item[2]
        let sep = g:bufferline_separator
        let new_len = strlen(built) + strlen(fragment) + strlen(sep)
        if new_len > width && g:bufferline_rotate != 2
            break
        endif

        if item[0] == current_buffer
            let current_buffer_pos[0] = strlen(built)
            let current_buffer_pos[1] = strlen(built) + strlen(fragment) + strlen(sep) - 1
        endif

        let built .= fragment . sep

        if g:bufferline_rotate != 2
            let idx = match(built, '\V' . g:bufferline_status_info.current)
            if idx >= 0
                let g:bufferline_status_info.before = strpart(built, 0, idx)
                let g:bufferline_status_info.after  = strpart(built, idx + len(g:bufferline_status_info.current))
            endif

            execute 'echohl ' . hl
            execute 'echon ' . string(fragment)
            execute 'echohl Normal'
            execute 'echon ' . string(sep)
            echohl None
        endif
    endfor

    if g:bufferline_rotate == 2
        let display_line = s:apply_window_rotation(built, current_buffer_pos)
        let max_width = &columns - 12

        let display_pos = 0
        let visible_chars = 0
        let pos = 0

        let sep = g:bufferline_separator
        let win_start = s:window_start
        let win_end   = s:window_start + width - 1
        let pos       = 0

        for item in items
            let fragment       = item[1]
            let hl             = item[2]
            let item_start     = pos
            let item_end       = pos + strlen(fragment) - 1

            let ovl_start = max([item_start, win_start])
            let ovl_end   = min([item_end,   win_end])

            if ovl_start <= ovl_end
                let local_off  = ovl_start - item_start
                let local_len  = ovl_end   - ovl_start + 1
                let piece      = strpart(fragment, local_off, local_len)

                execute 'echohl ' . hl
                execute 'echon '   . string(piece)
                execute 'echohl Normal'
                execute 'echon ' . string(sep)
            endif

            let pos += strlen(fragment) + strlen(sep)
            if item_end >= win_end
                break
            endif
        endfor
    endif

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
        " Initial setup - use refresh to establish the autocmd
        call s:refresh(1)
    augroup END
endfunction
