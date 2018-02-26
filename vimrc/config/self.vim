" Allow to trigger background
function! MyToggleBG()
    let s:tbg = &background
    " Inversion
    if s:tbg == "dark"
        set background=light
    else
        set background=dark
    endif
endfunction

function! Change2SymbolLinkDirectory()
    let l:dir = fnamemodify(resolve(expand('%:p')), ':p:h')
    lcd l:dir
endfunction

function! MyResCur()
    if line("'\"") <= line("$")
        silent! normal! g`"
        return 1
    endif
endfunction

function! MyInitializeDirectories()
    let parent = $HOME . '/.vim/tmp'
    let prefix = 'vim'
    let dir_list = {
                \ 'backup': 'backupdir',
                \ 'views': 'viewdir',
                \ 'swap': 'directory' }

    if has('persistent_undo')
        let dir_list['undo'] = 'undodir'
    endif

    let common_dir = parent . '/.' . prefix

    for [dirname, settingname] in items(dir_list)
        let directory = common_dir . dirname . '/'
        if exists("*mkdir")
            if !isdirectory(directory)
                call mkdir(directory, "p")
            endif
        endif
        if !isdirectory(directory)
            echo "Warning: Unable to create backup directory: " . directory
            echo "Try: mkdir -p " . directory
        else
            let directory = substitute(directory, " ", "\\\\ ", "g")
            exec "set " . settingname . "=" . directory
        endif
    endfor
endfunction

function! s:MyStripTrailingWhitespace()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " do the business:
    %s/\s\+$//e
    " clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction

function! s:MyRunShellCommand(cmdline)
    botright new

    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal noswapfile
    setlocal nowrap
    setlocal filetype=shell
    setlocal syntax=shell

    call setline(1, a:cmdline)
    call setline(2, substitute(a:cmdline, '.', '=', 'g'))
    execute 'silent $read !' . escape(a:cmdline, '%#')
    setlocal nomodifiable
endfunction

command! -complete=file -nargs=+ MyShell call s:MyRunShellCommand(<q-args>)

function! MyWrapRelativeMotion(key, ...)
    let vis_sel=""
    if a:0
        let vis_sel="gv"
    endif
    if &wrap
        execute "normal!" vis_sel . "g" . a:key
    else
        execute "normal!" vis_sel . a:key
    endif
endfunction

" Opens the according header or source files in the same directory.
" Needed to be improved if the files don't lie in the same directory.
function! <SID>EditHeaderSourceFile()
    let l:items = split(expand('%:t'), '\.')
    if len(items) != 2
        return
    endif

    let l:supported_ext = ['c', 'cpp', 'cc', 'h', 'hpp']
    let l:index = index(l:supported_ext, l:items[1])
    if l:index < 0
        return
    endif

    if l:index > 2
        let l:fpath = map(l:supported_ext[0:2], 'l:items[0] . "." . v:val')
    else
        let l:fpath = map(l:supported_ext[3:], 'l:items[0] . "." . v:val')
    endif

    for file in l:fpath
        if filereadable(file)
            silent execute 'edit ' . file
            break
        endif
    endfor
endfunction

" Make '\' align well after all but the last line of a macro
function! <SID>MyMacroLineConcatenate() range
    let l:maxlen = 0
    let l:lines = {}
    for i in range(a:firstline, a:lastline)
        let l:line = substitute(getline(i), '[ \t\r]\+$', '', '')
        let l:len = strlen(l:line)
        if l:line[l:len - 1] == '\'
            let l:line = strpart(l:line, 0, l:len - 1)
        endif
        let l:line = substitute(l:line, '[ \r\t]\+$', '', '')
        let l:len = strlen(l:line)
        let l:lines[i] = l:line
        if l:len > l:maxlen
            let l:maxlen = l:len
        endif
    endfor
    for [l:lineno, l:line] in items(l:lines)
        let l:line = l:lines[l:lineno]
        let l:len = strlen(l:line)
        let l:line .= repeat(' ', l:maxlen - l:len + 1) . '\'
        call setline(l:lineno, l:line)
    endfor
endfunction

function! <SID>MyInsertLeadingLineNumber() range
    let l:number = a:lastline - a:firstline + 1
    let l:align = strlen(l:number)
    let l:index = 1
    for i in range(a:firstline, a:lastline)
        let l:leading = l:index . repeat(' ', l:align - strlen(l:index) + 1)
        let l:line = l:leading . getline(i)
        call setline(i, l:line)
        let l:index += 1
    endfor
endfunction

" Make a line align with the next line
function! <SID>MyAlignLine(...) range
    if a:0 == 1
        let l:refline = prevnonblank(a:firstline - 1)
    else
        let l:refline = nextnonblank(a:lastline + 1)
    endif

    let l:indent = indent(l:refline)

    let l:char = getchar()
    if l:char
        let l:pos = stridx(getline(l:refline), nr2char(l:char))
        if l:pos >= 0
            let l:indent = l:pos + 1
        endif
    endif

    let l:linenos = range(a:firstline, a:lastline)
    if len(l:linenos) <= 1
        let l:linenos = range(line('.'), line('.') + v:count)
    endif

    for i in range(a:firstline, a:lastline)
        let l:line = substitute(getline(i), "^[ \t]*", "", "")
        let l:line = repeat(' ', l:indent) . l:line
        call setline(i, l:line)
    endfor

endfunction

" Move the end line cpp comments above the line
function! <SID>MyMoveEndCommentAboveLine() range
    let l:nr_ins = 0
    for l:lineno in range(a:firstline, a:lastline)
        let l:lineno += l:nr_ins
        let l:lindent = indent(l:lineno)
        let l:line = getline(l:lineno)
        let l:sep = stridx(l:line, ';')
        if l:sep < 0 || l:sep == strlen(l:line)
            continue
        endif
        call setline(l:lineno, strpart(l:line, 0, l:sep + 1))
        
        let l:newline = substitute(strpart(l:line, l:sep + 1), "^[ \t]*", "", "")
        let l:newline = repeat(' ', l:lindent) . l:newline
        let l:lines = [l:newline]
        if l:lineno > 1
            if l:lineno - 1 == prevnonblank(l:lineno - 1)
                call insert(l:lines, '', 0)
            endif
        endif
        call append(l:lineno - 1, l:lines)
        let l:nr_ins += len(l:lines)
    endfor
endfunction

" Remove beginning N characters
function! <SID>MyRemoveBeginningN() range
    for l:lineno in range(a:firstline, a:lastline)
        let l:line = getline(l:lineno)
        call setline(l:lineno, l:line[v:count:])
    endfor
endfunction

" Align function arguments split
function! <SID>MyAlignCFunctionArgs() range
    let l:lineno = line('.')
    let l:line = getline(l:lineno)
    if strlen(l:line) < 80
        return
    endif
    if l:line =~ '[^()]\+(.*)'
        let l:pos = stridx(l:line, '(')
        let l:argslist = strpart(l:line, l:pos + 1)
        let l:items = split(l:argslist, ',\zs')
        let l:lines = []
        for l:arg in l:items[1:]
            call add(l:lines, repeat(' ', l:pos) . l:arg)
        endfor
        if len(l:lines) > 0
            call setline(l:lineno, strpart(l:line, 0, l:pos + 1) . l:items[0])
            call append(l:lineno, l:lines)
        endif
    endif
endfunction

nnoremap <silent> <Leader>me :call <SID>EditHeaderSourceFile()<CR>
vnoremap <silent> <Leader>mi :call <SID>MyInsertLeadingLineNumber()<CR>
vnoremap <silent> <Leader>ml :silent call <SID>MyMacroLineConcatenate()<CR>

nnoremap <silent> <Leader>mn :call <SID>MyAlignLine()<CR>
nnoremap <silent> <Leader>mp :call <SID>MyAlignLine("previous")<CR>
vnoremap <silent> <Leader>mn :call <SID>MyAlignLine()<CR>
vnoremap <silent> <Leader>mp :call <SID>MyAlignLine("previous")<CR>

vnoremap <silent> <Leader>mc :call <SID>MyMoveEndCommentAboveLine()<CR>
nnoremap <silent> <Leader>mc :call <SID>MyMoveEndCommentAboveLine()<CR>

vnoremap <silent> <Leader>md :call <SID>MyRemoveBeginningN()<CR>
nnoremap <silent> <Leader>md :call <SID>MyRemoveBeginningN()<CR>

nnoremap <silent> <Leader>ma :call <SID>MyAlignCFunctionArgs()<CR>

" Wrapped lines goes down/up to next row, rather than next line in file.
noremap j gj
noremap k gk

" Yank from the cursor to the end of the line, to be consistent with C and D.
nnoremap Y y$

" Easier horizontal scrolling
noremap zl zL
noremap zh zH

" Easier formatting
nnoremap <silent> <leader>q gwip
" Code folding options
nnoremap <leader>f0 :set foldlevel=0<CR>
nnoremap <leader>f1 :set foldlevel=1<CR>
nnoremap <leader>f2 :set foldlevel=2<CR>
nnoremap <leader>f3 :set foldlevel=3<CR>
nnoremap <leader>f4 :set foldlevel=4<CR>
nnoremap <leader>f5 :set foldlevel=5<CR>
nnoremap <leader>f6 :set foldlevel=6<CR>
nnoremap <leader>f7 :set foldlevel=7<CR>
nnoremap <leader>f8 :set foldlevel=8<CR>
nnoremap <leader>f9 :set foldlevel=9<CR>

" Visual shifting (does not exit Visual mode)
vnoremap < <gv
vnoremap > >gv

" Allow using the repeat operator with a visual selection (!)
" http://stackoverflow.com/a/8064607/127816
vnoremap . :normal .<CR>

" Default range is the whole buffer.
command! -range=% MLC  <line1>,<line2>call <SID>MyMacroLineConcatenate()

" self unplugin-related keymap. Thest start 's' is for self.
nnoremap <C-Q> :qa!<CR>
nnoremap <Leader>sq   :wqa<CR>          " save all changes and exit
nnoremap <Leader>cq   :qa!<CR>          " discard all changes and exit
nnoremap <Leader>sp   :set paste!<CR>                  " toggle paste
nnoremap <Leader>sn   :set number! relativenumber!<CR> " toggle number options
nnoremap <leader>se :e!<CR>
nnoremap <Leader>rts :%s/ \+$//ge<CR>                  " remove trailing spaces
nnoremap <Leader>s<Space> i <Esc>2li <Esc>

nnoremap <Leader>nh :nohlsearch<CR>
nnoremap <Leader>/ ?
nnoremap <Leader>rl :edit!<CR>G

nnoremap <silent> <Leader>bu :buffers<CR>
nnoremap <silent> <Leader>bf :bfirst<CR>
nnoremap <silent> <Leader>bl :blast<CR>
nnoremap <silent> <Leader>bn :bnext<CR>
nnoremap <silent> <Leader>bp :bprevious<CR>

nnoremap <silent> <Leader>tb :tabs<CR>
nnoremap <silent> <Leader>tc :tabclose<CR>
nnoremap <silent> <Leader>tf :tabfirst<CR>
nnoremap <silent> <Leader>tl :tablast<CR>
nnoremap <silent> <Leader>tn :tabnext<CR>
nnoremap <silent> <Leader>tp :tabprevious<CR>
nnoremap <silent> <Leader>th :tab help<CR>

nnoremap <silent> <Leader>lo :lopen<CR>
nnoremap <silent> <Leader>ln :lnext<CR>
nnoremap <silent> <Leader>lp :lprevious<CR>
nnoremap <silent> <Leader>ld :lolder<CR>
nnoremap <silent> <Leader>le :lnewer<CR>
nnoremap <silent> <Leader>lc :lclose<CR>
nnoremap <silent> <Leader>lw :lwindow<CR>
nnoremap <silent> <Leader>lm :lmake<CR>

nnoremap <silent> <Leader>qo :copen<CR>
nnoremap <silent> <Leader>qn :cnext<CR>
nnoremap <silent> <Leader>qp :cprevious<CR>
nnoremap <silent> <Leader>qc :cclose<CR>

nnoremap <Leader>pd oimport pdb; pdb.set_trace()<Esc>:w<CR>

nnoremap <Leader>dw dd:w<CR>
nnoremap <Leader>uw u:w<CR>

nnoremap <Leader>vc :vimgrep <cword> *.c<CR>
nnoremap <Leader>vp :vimgrep <cword> *.cpp<CR>
nnoremap <Leader>vh :vimgrep <cword> *.h<CR>
nnoremap <Leader>vy :vimgrep <cword> *.py<CR>

nnoremap <c-]> g<c-]>
vnoremap <c-]> g<c-]>

inoremap <C-E> <End>
inoremap <C-A> <Home>
"inoremap <C-j> <Up>
"inoremap <C-k> <Down>
inoremap <C-B> <Left>
inoremap <C-F> <Right>
inoremap <C-I> <C-O>I
inoremap <C-Z> <C-O>u

"nore Map g* keys in Normal, Operator-pending, and Visual+select
noremap $ :call MyWrapRelativeMotion("$")<CR>
noremap <End> :call MyWrapRelativeMotion("$")<CR>
noremap 0 :call MyWrapRelativeMotion("0")<CR>
noremap <Home> :call MyWrapRelativeMotion("0")<CR>
noremap ^ :call MyWrapRelativeMotion("^")<CR>
" Overwrite the operator pending $/<End> mappings from above
" to force inclusive motion with :execute normal!
onoremap $ v:call MyWrapRelativeMotion("$")<CR>
onoremap <End> v:call MyWrapRelativeMotion("$")<CR>
" Overwrite the Visual+select mode mappings from above
" to ensure the correct vis_sel flag is passed to function
vnoremap $ :<C-U>call MyWrapRelativeMotion("$", 1)<CR>
vnoremap <End> :<C-U>call MyWrapRelativeMotion("$", 1)<CR>
vnoremap 0 :<C-U>call MyWrapRelativeMotion("0", 1)<CR>
vnoremap <Home> :<C-U>call MyWrapRelativeMotion("0", 1)<CR>
vnoremap ^ :<C-U>call MyWrapRelativeMotion("^", 1)<CR>

"noremap <C-J> <C-W>j<C-W>_
"noremap <C-K> <C-W>k<C-W>_
noremap <C-L> <C-W>l<C-W>_
noremap <C-H> <C-W>h<C-W>_

" Shortcuts
" Change Working Directory to that of the current file
cnoremap cwd lcd %:p:h
cnoremap cd. lcd %:p:h

" change cwd to the target's directory
nnoremap <leader>fl :lcd <C-R>=fnamemodify(resolve(expand('%:p')), ':p:h')"<CR><CR>

"For when you forget to sudo.. Really Write the file.
cnoremap w!! w !sudo tee % >/dev/null

" Some helpers to edit mode
" http://vimcasts.org/e/14
cnoremap %% <C-R>=fnameescape(expand('%:h')).'/'<cr>
noremap <leader>ew :e %%
noremap <leader>es :sp %%
noremap <leader>ev :vsp %%
noremap <leader>et :tabe %%

noremap <Leader>ec :edit ~/.vimrc<CR>
noremap <Leader>sv :source ~/.vimrc<CR>
noremap <leader>bg :call MyToggleBG()<CR>

noremap <leader>sh :shell<CR>

" Find merge conflict markers
noremap <leader>fc /\v^[<\|=>]{7}( .*\|$)<CR>

" Adjust viewports to the same size
noremap <Leader>= <C-w>=

" Map <Leader>ff to display all lines with keyword under cursor
" and ask which one to jump to
noremap <Leader>ff [I:let nr = input("Which one: ")<Bar>exe "normal " . nr ."[\t"<CR>

autocmd FileType h,hpp,c,cc,cpp,java,go,php,javascript,python,rust,xml,yml,perl,sql
        \ autocmd BufWritePre <buffer> call s:MyStripTrailingWhitespace()

call MyInitializeDirectories()

