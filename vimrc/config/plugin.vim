let s:script_dir = fnamemodify(resolve(expand('<sfile>:p')), ':p:h')

function! NERDTreeInitAsNeeded()
    redir => bufoutput
    buffers!
    redir END
    let idx = stridx(bufoutput, "NERD_tree")
    if idx > -1
        NERDTreeMirror
        NERDTreeFind
        wincmd l
    endif
endfunction

function! <SID>AddCscopeFiles()
    set nocscopeverbose " suppress 'duplicate connection' error
    let l:dir = getcwd()
    while l:dir != expand('~') && l:dir != '/'
        let l:file = l:dir . '/cscope.out'
        if filereadable(l:file)
            execute 'cscope add ' . l:file
            echo 'added ' . l:file
            break
        endif
        let l:dir = resolve(fnamemodify(l:dir . '/..', ':p:h'))
    endwhile
    set cscopeverbose
endfunction

function! LoadCscope()
  let db = findfile("cscope.out", ".;")
  if (!empty(db))
    let path = strpart(db, 0, match(db, "/cscope.out$"))
    set nocscopeverbose " suppress 'duplicate connection' error
    exe "cs add " . db . " " . path
    set cscopeverbose
  endif
endfunction

if filereadable(expand("~/.vim/bundle/vim-colors-solarized/colors/solarized.vim"))
    let g:solarized_termcolors=256
    let g:solarized_termtrans=1
    let g:solarized_contrast="normal"
    let g:solarized_visibility="normal"
    color solarized             " Load a colorscheme
endif

if has('cscope')
     "If 'cscoperelative' is set, then in absence of a prefix given to cscope
     "(prefix is the argument of -P option of cscope), basename of cscope.out 
     "location (usually the project root directory) will be used as the prefix
     "to construct an absolute path. The default is off. Note: This option is 
     "only effective when cscope (cscopeprg) is initialized without a prefix 
     "path (-P).
    set cscoperelative

    nmap <F5> :!find . -iname '*.c' -o -iname '*.cpp' -o -iname '*.h' -o -iname '*.hpp' > /tmp/cscope.files<CR>
  \:!cscope -b -i /tmp/cscope.files -f cscope.out<CR>
  \:cs kill -1<CR>:cs add cscope.out<CR>

    noremap <Leader>fs :cs find s <C-R>=expand("<cword>")<CR><CR>
    noremap <Leader>fg :cs find g <C-R>=expand("<cword>")<CR><CR>
    noremap <Leader>fc :cs find c <C-R>=expand("<cword>")<CR><CR>
    noremap <Leader>ft :cs find t <C-R>=expand("<cword>")<CR><CR>
    noremap <Leader>fe :cs find e <C-R>=expand("<cword>")<CR><CR>
    noremap <Leader>ff :cs find f <C-R>=expand("<cfile>")<CR><CR>
    noremap <Leader>fi :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
    noremap <Leader>fd :cs find d <C-R>=expand("<cword>")<CR><CR>
    " Using 'CTRL-spacebar' then a search type makes the vim window
    " split horizontally, with search result displayed in
    " the new window.
    noremap <C-Space>s :scs find s <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space>g :scs find g <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space>c :scs find c <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space>t :scs find t <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space>e :scs find e <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space>f :scs find f <C-R>=expand("<cfile>")<CR><CR>
    noremap <C-Space>i :scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
    noremap <C-Space>d :scs find d <C-R>=expand("<cword>")<CR><CR>

    " Hitting CTRL-space *twice* before the search type does a vertical
    " split instead of a horizontal one
    noremap <C-Space><C-Space>s \:vert scs find s <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space><C-Space>g \:vert scs find g <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space><C-Space>c \:vert scs find c <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space><C-Space>t \:vert scs find t <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space><C-Space>e \:vert scs find e <C-R>=expand("<cword>")<CR><CR>
    noremap <C-Space><C-Space>i \:vert scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
    noremap <C-Space><C-Space>d \:vert scs find d <C-R>=expand("<cword>")<CR><CR>

    nnoremap <leader>ac :call <SID>AddCscopeFiles()<CR>

    "au VimEnter * call <SID>AddCscopeFiles()
	au BufEnter /* call LoadCscope()

    set nocscopeverbose
endif

" NerdTree {
if isdirectory(expand("~/.vim/bundle/nerdtree"))
    let NERDTreeWinPos="right"
    let NERDTreeShowBookmarks=1
    let NERDTreeIgnore=['\.py[cd]$', '\~$', '\.swo$', '\.swp$', '^\.git$', '^\.hg$', '^\.svn$', '\.bzr$']
    let NERDTreeChDirMode=0
    let NERDTreeQuitOnOpen=1
    let NERDTreeMouseMode=2
    let NERDTreeShowHidden=1
    let NERDTreeKeepTreeInNewTab=1

    noremap <leader>nf :NERDTreeFind<CR>
    noremap <leader>nt :NERDTreeToggle<CR>
endif
" }

" Tabularize {
if isdirectory(expand("~/.vim/bundle/tabular"))
    noremap <Leader>b& :Tabularize /&<CR>
    vnoremap <Leader>b& :Tabularize /&<CR>
    noremap <Leader>b= :Tabularize /^[^=]*\zs=<CR>
    vnoremap <Leader>b= :Tabularize /^[^=]*\zs=<CR>
    noremap <Leader>b=> :Tabularize /=><CR>
    vnoremap <Leader>b=> :Tabularize /=><CR>
    noremap <Leader>b: :Tabularize /:<CR>
    vnoremap <Leader>b: :Tabularize /:<CR>
    noremap <Leader>b:: :Tabularize /:\zs<CR>
    vnoremap <Leader>b:: :Tabularize /:\zs<CR>
    noremap <Leader>b, :Tabularize /,<CR>
    vnoremap <Leader>b, :Tabularize /,<CR>
    noremap <Leader>b,, :Tabularize /,\zs<CR>
    vnoremap <Leader>b,, :Tabularize /,\zs<CR>
    noremap <Leader>b<Bar> :Tabularize /<Bar><CR>
    vnoremap <Leader>b<Bar> :Tabularize /<Bar><CR>
endif
" }

" UndoTree {
if isdirectory(expand("~/.vim/bundle/undotree/"))
    " If undotree is opened, it is likely one wants to interact with it.
    let g:undotree_SetFocusWhenToggle=1
endif
" }

if isdirectory(expand("~/.vim/bundle/sessionman.vim/"))
    noremap <leader>sc :SessionClose<CR>
    noremap <leader>sl :SessionList<CR>
    noremap <leader>so :SessionOpen<CR>
    noremap <leader>ss :SessionSave<CR>
endif

if isdirectory(expand("~/.vim/bundle/matchit.zip"))
    let b:match_ignorecase = 1
endif

" TagBar {
if isdirectory(expand("~/.vim/bundle/tagbar/"))
    let g:tagbar_left = 1
    let g:tagbar_width = 28
    nnoremap <silent> <leader>tg :TagbarToggle<CR>
endif
"}

" Fugitive {
if isdirectory(expand("~/.vim/bundle/vim-fugitive/"))
    nnoremap <silent> <leader>gs :Gstatus<CR>
    nnoremap <silent> <leader>gd :Gdiff<CR>
    nnoremap <silent> <leader>gc :Gcommit<CR>
    nnoremap <silent> <leader>gb :Gblame<CR>
    nnoremap <silent> <leader>gl :Glog<CR>
    nnoremap <silent> <leader>gp :Git push<CR>
    nnoremap <silent> <leader>gr :Gread<CR>
    nnoremap <silent> <leader>gw :Gwrite<CR>
    nnoremap <silent> <leader>ge :Gedit<CR>
    nnoremap <silent> <leader>gi :Git add -p %<CR>
    nnoremap <silent> <leader>gg :SignifyToggle<CR>
endif
"}

" YouCompleteMe {
    let g:acp_enableAtStartup = 0

    " enable completion from tags
    let g:ycm_collect_identifiers_from_tags_files = 1

    let g:ycm_global_ycm_extra_conf = s:script_dir . '/ycm_extra_conf_cpp.py'

    " remap Ultisnips for compatibility for YCM
    let g:UltiSnipsSnippetDirectories=['ultisnips']
    let g:UltiSnipsSnippetsDir = '~/.vim/ultisnips'
    let g:UltiSnipsExpandTrigger = '<C-j>'
    let g:UltiSnipsJumpForwardTrigger = '<C-j>'
    let g:UltiSnipsJumpBackwardTrigger = '<C-k>'

    nnoremap <leader>yt :let g:ycm_auto_trigger=0<CR>                " turn off YCM
    nnoremap <leader>yT :let g:ycm_auto_trigger=1<CR>                "turn on YCM

    let g:ycm_python_binary_path = '/usr/bin/python3'
    let g:ycm_confirm_extra_conf = 0
    let g:ycm_open_loclist_on_ycm_diags = 1
    let g:ycm_disable_for_files_larger_than_kb = 640
    let g:ycm_filetype_whitelist = { 'cpp': 1, 'c' : 1, 'py' : 1, 'go' : 1 }  
	let g:ycm_complete_in_comments = 1 
	let g:ycm_seed_identifiers_with_syntax = 1 

    " Disable the neosnippet preview candidate window
    " When enabled, there can be too much visual noise
    " especially when splits are used.
    set completeopt-=preview

    set conceallevel=2 concealcursor=i

    nnoremap <leader>yd :YcmCompleter GoToDefinition<CR>
    nnoremap <leader>yc :YcmCompleter GoToDeclaration<CR>
    nnoremap <leader>ye :YcmCompleter GoToDefinitionElseDeclaration<CR>
    nnoremap <leader>yi :YcmCompleter GoToInclude<CR>
    nnoremap <Leader>yf :YcmForceCompileAndDiagnostics<CR>
    nnoremap <Leader>yg :YcmDiag<CR>

    " Enable omni completion.
    autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
    autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
    autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
    autocmd FileType python setlocal omnifunc=jedi#completions
    "autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
    autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
" }

"{ jedi
	let g:jedi#goto_command = "<leader>jg"
	let g:jedi#goto_assignments_command = "<leader>ja"
	let g:jedi#goto_definitions_command = "<Leader>jd"
	let g:jedi#documentation_command = "K"
	let g:jedi#usages_command = "<leader>ju"
	let g:jedi#completions_command = "<C-Space>"
	let g:jedi#rename_command = "<leader>jr"
" }

if isdirectory(expand("~/.vim/bundle/python-mode"))
    let g:pymode_lint_checkers = ['pyflakes']
    let g:pymode_trim_whitespaces = 0
    let g:pymode_options = 0
    let g:pymode_rope = 0
    let g:pymode_python = 'python3'
endif
" }

" ctrlp {
if isdirectory(expand("~/.vim/bundle/ctrlp.vim/"))
    " I like buffer as the default.
    let g:ctrlp_cmd = 'CtrlPBuffer'

    let g:ctrlp_working_path_mode = 'ra'
    nnoremap <silent> <Leader>pc :CtrlPCurFile<CR>
    nnoremap <silent> <Leader>pm :CtrlPMRU<CR>

    let g:ctrlp_custom_ignore = {
        \ 'dir':  '\v[\/]\.(git|hg|svn)$',
        \ 'file': '\.exe$\|\.so$\|\.dll$\|\.pyc$\|\.o$\|\.a$' }

    let s:ctrlp_fallback = 'find %s -type f'
    if exists("g:ctrlp_user_command")
        unlet g:ctrlp_user_command
    endif
    let g:ctrlp_user_command = {
        \ 'types': {
            \ 1: ['.git', 'cd %s && git ls-files . --cached --exclude-standard --others'],
            \ 2: ['.hg', 'hg --cwd %s locate -I .'],
        \ },
        \ 'fallback': s:ctrlp_fallback
    \ }

    if isdirectory(expand("~/.vim/bundle/ctrlp-funky/"))
        " CtrlP extensions
        let g:ctrlp_extensions = ['funky']

        "funky
        nnoremap <Leader>fu :CtrlPFunky<Cr>
    endif

    let g:ctrlp_buffer_func = { 'enter': 'MyCtrlPMappings' }

    func! MyCtrlPMappings()
        nnoremap <buffer> <silent> <c-@> :call <sid>DeleteBuffer()<cr>
    endfunc

    func! s:DeleteBuffer()
        let line = getline('.')
        let bufid = line =~ '\[\d\+\*No Name\]$' ? str2nr(matchstr(line, '\d\+'))
            \ : fnamemodify(line[2:], ':p')
        exec "bd" bufid
        exec "norm \<F5>"
    endfunc
endif
"}

" GoLang {
    let g:go_highlight_functions = 1
    let g:go_highlight_methods = 1
    let g:go_highlight_structs = 1
    let g:go_highlight_operators = 1
    let g:go_highlight_build_constraints = 1
    let g:go_fmt_command = "goimports"
    let g:syntastic_go_checkers = ['golint', 'govet', 'errcheck']
    let g:syntastic_mode_map = { 'mode': 'active', 'passive_filetypes': ['go'] }
    au FileType go nmap <Leader>s <Plug>(go-implements)
    au FileType go nmap <Leader>i <Plug>(go-info)
    au FileType go nmap <Leader>e <Plug>(go-rename)
    au FileType go nmap <leader>r <Plug>(go-run)
    au FileType go nmap <leader>b <Plug>(go-build)
    au FileType go nmap <leader>t <Plug>(go-test)
    au FileType go nmap <Leader>gd <Plug>(go-doc)
    au FileType go nmap <Leader>gv <Plug>(go-doc-vertical)
    au FileType go nmap <leader>co <Plug>(go-coverage)
" }

" indent_guides {
if isdirectory(expand("~/.vim/bundle/vim-indent-guides/"))
    let g:indent_guides_start_level = 2
    let g:indent_guides_guide_size = 1
    let g:indent_guides_enable_on_vim_startup = 1
endif
" }

if isdirectory(expand("~/.vim/bundle/denite.nvim/"))
    noremap <leader>ub :Denite buffer<CR>
    noremap <leader>uf :Denite file<CR>
endif

if executable('ag')
    let g:ackprg = 'ag --vimgrep'
    noremap <leader>aw :Ack <cword><CR>
    noremap <leader>ap :Ack <cword> ..<CR>
endif

" Wildfire {
let g:wildfire_objects = {
        \ "*" : ["i'", 'i"', "i)", "i]", "i}", "ip"],
        \ "html,xml" : ["at"],
        \ }

let g:solarized_contrast="high"
let g:solarized_visibility="high"

let g:snips_author = 'Richy Mong <RichyMong@gmail.com>'

" Instead of reverting the cursor to the last position in the buffer, we
" set it to the first line when editing a git commit message
au FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])
