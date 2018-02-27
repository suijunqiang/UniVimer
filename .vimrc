"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" _
" __ | 
" / | /
" __ | 
" by Amix - http://amix.dk/
"
" Maintainer: Amir Salihefendic <amix3k at gmail.com>
" Version: 2.0
" Last Change: 12/08/06 13:39:28
" Fixed (win32 compatible) by: redguardtoo <chb_sh at gmail.com>
"
" Sections:
" ----------------------
" *> General
" *> Colors and Font
" *> Fileformat
" *> VIM userinterface
" ------ *> Statusline
" *> Visual
" *> Moving around and tab
" *> General Autocommand
" *> Parenthesis/bracket expanding
" *> General Abbrev
" *> Editing mappings etc.
" *> Command-line config
" *> Buffer realted
" *> Files and backup
" *> Folding
" *> Text option
" ------ *> Indent
" *> Spell checking
" *> Plugin configuration
" ------ *> Yank ring
" ------ *> File explorer
" ------ *> Minibuffer
" ------ *> Tag list (ctags) - not used
" ------ *> LaTeX Suite thing
" *> Filetype generic
" ------ *> Todo
" ------ *> VIM
" ------ *> HTML related
" ------ *> Ruby & PHP section
" ------ *> Python section
" ------ *> Cheetah section
" ------ *> Java section
" ------ *> JavaScript section
" ------ *> C mapping
" ------ *> SML
" ------ *> Scheme binding
" *> Snippet
" ------ *> Python
" ------ *> javaScript
" *> Cope
" *> MISC
"
" Tip:
" If you find anything that you can't understand than do this:
" help keyword OR helpgrep keyword
" Example:
" Go into command-line mode and type helpgrep nocompatible, ie.
" :helpgrep nocompatible
" then press <leader>c to see the results, or :botright cw
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Get out of VI's compatible mode..
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle 'gmarik/vundle'
set nocompatible

function! MySys()
return "win32"
endfunction
"Set shell to be bash
if MySys() == "linux" || MySys() == "mac"
set shell=bash
else
"I have to run win32 python without cygwin
"set shell=E:\cygwin\bin\sh
endif

"Sets how many lines of history VIM har to remember
set history=400

"Enable filetype plugin
if has("eval")
filetype plugin on
filetype indent on
endif

"Set to auto read when a file is changed from the outside
set autoread

"Have the mouse enabled all the time:
set mouse=a

"Set mapleader
let mapleader = ","
let g:mapleader = ","

"Fast saving
nmap <leader>w :w!<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Font
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Enable syntax hl
syntax on

"Set font to Monaco 10pt
if MySys() == "mac"
 set gfn=Bitstream Vera Sans Mono:h14
 set nomacatsui
 set termencoding=macroman
elseif MySys() == "linux"
 set gfn=Monospace 11
 "set encoding=utf-8
endif

"internationalization
"I only work in Win2k Chinese version
if has("multi_byte")
"set termencoding=chinese
set encoding=utf-8
set fileencodings=ucs-bom,utf-8,chinese
endif

"if you use vim in tty, 
"'uxterm -cjk' or putty with option 'Treat CJK ambiguous characters as wide' on
if has("ambiwidth")
set ambiwidth=double
endif

if has("gui_running")
set guioptions+=m
set guioptions+=T
set guioptions+=l
set guioptions+=L
set guioptions+=r
set guioptions+=R
set guioptions+=setm

if MySys()=="win32"
"start gvim maximized
"解决菜单乱码  
"
source $VIMRUNTIME/delmenu.vim  
source $VIMRUNTIME/menu.vim  

set fileencoding=chinese
language messages zh_CN.utf-8
if has("autocmd")
"au GUIENTER * simalt ~x
endif
endif
"let psc_style='cool'
"colorscheme ps_color
"colorscheme default
else
"set background=dark
"colorscheme default
endif

"Some nice mapping to switch syntax (useful if one mixes different languages in one file)
map <leader>1 :set syntax=cheetah<cr>
map <leader>2 :set syntax=xhtml<cr>
map <leader>3 :set syntax=python<cr>
map <leader>4 :set ft=javascript<cr>
map <leader>$ :syntax sync fromstart<cr>

"Highlight current
"if has("gui_running")
"if has("cursorline")
set cursorline
"hi cursorline guibg=#FFF685
hi cursorline guibg=#87CEFA
"hi CursorColumn guibg=#333333
"endif
"endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Fileformat
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Favorite filetype
set ffs=unix,dos,mac

nmap <leader>fd :se ff=dos<cr>
nmap <leader>fu :se ff=unix<cr>



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => VIM userinterface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Set 7 lines to the curors - when moving vertical..
set so=7

"Turn on WiLd menu
set wildmenu

"Always show current position
set ruler

"The commandbar is 2 high
set cmdheight=2

"Show line number
set nu

"Do not redraw, when running macros.. lazyredraw
set lz

"Change buffer - without saving
set hid

"Set backspace
set backspace=eol,start,indent

"Bbackspace and cursor keys wrap to
set whichwrap+=<,>,h,l

"Ignore case when searching
"set ignorecase
set incsearch

"Set magic on
set magic

"No sound on errors.
set noerrorbells
set novisualbell
set t_vb=

"show matching bracet
set showmatch

"How many tenths of a second to blink
set mat=4

"Highlight search thing
set hlsearch

""""""""""""""""""""""""""""""
" => Statusline
""""""""""""""""""""""""""""""
"Always hide the statusline
set laststatus=2

function! CurDir()
let curdir = substitute(getcwd(), '/Users/amir/', "~/", "g")
return curdir
endfunction

"Format the statusline
set statusline=
set statusline+=%f "path to the file in the buffer, relative to current directory
set statusline+=\ %h%1*%m%r%w%0* " flag
set statusline+=\ [%{strlen(&ft)?&ft:'none'}, " filetype
set statusline+=%{&encoding}, " encoding
set statusline+=%{&fileformat}] " file format
set statusline+=\ CWD:%r%{CurDir()}%h
set statusline+=\ Line:%l/%L


""""""""""""""""""""""""""""""
" => Visual
""""""""""""""""""""""""""""""
" From an idea by Michael Naumann
function! VisualSearch(direction) range
let l:saved_reg = @"
execute "normal! vgvy"
let l:pattern = escape(@", '\/.*$^~[]')
let l:pattern = substitute(l:pattern, " $", "", "")
if a:direction == 'b'
execute "normal ?" . l:pattern . "^M"
else
execute "normal /" . l:pattern . "^M"
endif
let @/ = l:pattern
let @" = l:saved_reg
endfunction

"Basically you press * or # to search for the current selection !! Really useful
vnoremap <silent> * :call VisualSearch('f')<CR>
vnoremap <silent> # :call VisualSearch('b')<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Moving around and tab
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Map space to / and c-space to ?
map <space> /
"map <c-space> ?

"Smart way to move btw. window
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

"Actually, the tab does not switch buffers, but my arrow
"Bclose function ca be found in "Buffer related" section
"map <leader>bd :Bclose<cr>
map <down> <cr>
"Use the arrows to something usefull
"map <right> :bn<cr>
"map <left> :bp<cr>

"Tab configuration
map <leader>tn :tabnew %<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove 
if has("usetab")
set switchbuf=usetab
endif

if has("stal")
set stal=2
endif

"Moving fast to front, back and 2 sides ;)
imap <m-$> <esc>$a
imap <m-0> <esc>0i
imap <D-$> <esc>$a
imap <D-0> <esc>0i


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General Autocommand
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Switch to current dir
map <leader>cd :cd %:p:h<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Parenthesis/bracket expanding
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
vnoremap $1 <esc>`>a)<esc>`<i(<esc>
")
vnoremap $2 <esc>`>a]<esc>`<i[<esc>
vnoremap $3 <esc>`>a}<esc>`<i{<esc>
vnoremap $$ <esc>`>a"<esc>`<i"<esc>
vnoremap $q <esc>`>a'<esc>`<i'<esc>
vnoremap $w <esc>`>a"<esc>`<i"<esc>

"Map auto complete of (, ", ', [
"http://www.vim.org/tips/tip.php?tip_id=153
"
ino ( ()<esc>:let leavechar=")"<cr>i
ino { {}<esc>:let leavechar="}"<cr>i
ino $q ''<esc>:let leavechar="'"<cr>i
ino $w ""<esc>:let leavechar='"'<cr>i
imap <c-l> <esc>:exec "normal f" . leavechar<cr>a

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General Abbrev
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Comment for C like language
if has("autocmd")
au BufNewFile,BufRead *.js,*.htc,*.c,*.tmpl,*.css ino $c /**<cr> **/<esc>O
endif

"My information
ia xdate <c-r>=strftime("%d/%m/%y %H:%M:%S")<cr>
"iab xname Amir Salihefendic

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Editing mappings etc.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Remap VIM 0
map 0 ^

"Move a line of text using control
nmap <M-j> mz:m+<cr>`z
nmap <M-k> mz:m-2<cr>`z
vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z

if MySys() == "mac"
nmap <D-j> <M-j>
nmap <D-k> <M-k>
vmap <D-j> <M-j>
vmap <D-k> <M-k>
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Command-line config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
func! Cwd()
let cwd = getcwd()
return "e " . cwd 
endfunc

func! DeleteTillSlash()
let g:cmd = getcmdline()
if MySys() == "linux" || MySys() == "mac"
let g:cmd_edited = substitute(g:cmd, "\(.*[/]\).*", "\1", "")
else
let g:cmd_edited = substitute(g:cmd, "\(.*[\\]\).*", "\1", "")
endif
if g:cmd == g:cmd_edited
if MySys() == "linux" || MySys() == "mac"
let g:cmd_edited = substitute(g:cmd, "\(.*[/]\).*/", "\1", "")
else
let g:cmd_edited = substitute(g:cmd, "\(.*[\\]\).*[\\]", "\1", "")
endif
endif 
return g:cmd_edited
endfunc

func! CurrentFileDir(cmd)
return a:cmd . " " . expand("%:p:h") . "/"
endfunc

"cno $q <C->eDeleteTillSlash()<cr>
"cno $c e <C->eCurrentFileDir("e")<cr>
"cno $tc <C->eCurrentFileDir("tabnew")<cr>
cno $th tabnew ~/
cno $td tabnew ~/Desktop/

"Bash like
cno <C-A> <Home>
cno <C-E> <End>
cno <C-K> <C-U>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Buffer realted
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Fast open a buffer by search for a name
"map <c-q> :sb 

"Open a dummy buffer for paste
map <leader>q :e ~/buffer<cr>

"Restore cursor to file position in previous editing session
set viminfo='10,"100,:20,%,n~/.viminfo

" Buffer - reverse everything ... :)
map <F9> ggVGg?

" Don't close window, when deleting a buffer
command! Bclose call <SID>BufcloseCloseIt()

function! <SID>BufcloseCloseIt()
let l:currentBufNum = bufnr("%")
let l:alternateBufNum = bufnr("#")

if buflisted(l:alternateBufNum)
buffer #
else
bnext
endif

if bufnr("%") == l:currentBufNum
new
endif

if buflisted(l:currentBufNum)
execute "bdelete! ".l:currentBufNum
endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Files and backup
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Turn backup off
set nobackup
set nowb
"set noswapfile
set noar


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Folding
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Enable folding, I find it very useful
set fen
set fdl=0


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text option
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" python script
"set expandtab
set shiftwidth=2
set softtabstop=2
set tabstop=2
set backspace=2
set smarttab
set lbr
"set tw=500

""""""""""""""""""""""""""""""
" => Indent
""""""""""""""""""""""""""""""
"Auto indent
set ai

"Smart indet
set si

"C-style indenting
set cindent

"Wrap line
set wrap


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Spell checking
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
map <leader>sn ]
map <leader>sp [
map <leader>sa zg
map <leader>s? z=


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugin configuration
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""""""""""""""""""""""""""""""
" mark setting
""""""""""""""""""""""""""""""
 nmap <silent> <leader>hl <Plug>MarkSet
 vmap <silent> <leader>hl <Plug>MarkSet
 nmap <silent> <leader>hh <Plug>MarkClear
 vmap <silent> <leader>hh <Plug>MarkClear
 nmap <silent> <leader>hr <Plug>MarkRegex
 vmap <silent> <leader>hr <Plug>MarkRegex

""""""""""""""""""""""""""""""
" => Yank Ring
""""""""""""""""""""""""""""""
map <leader>y :YRShow<cr>

""""""""""""""""""""""""""""""
" => File explorer
""""""""""""""""""""""""""""""
"Split vertically
let g:explVertical=1

"Window size
let g:explWinSize=35

let g:explSplitLeft=1
let g:explSplitBelow=1

"Hide some file
let g:explHideFiles='^.,.*.class$,.*.swp$,.*.pyc$,.*.swo$,.DS_Store$'

"Hide the help thing..
let g:explDetailedHelp=0


""""""""""""""""""""""""""""""
" => Minibuffer
""""""""""""""""""""""""""""""
let g:miniBufExplModSelTarget = 1
let g:miniBufExplorerMoreThanOne = 0
let g:miniBufExplModSelTarget = 0
let g:miniBufExplUseSingleClick = 1
let g:miniBufExplMapWindowNavVim = 1
let g:miniBufExplVSplit = 25
let g:miniBufExplSplitBelow=1

"WindowZ
map <c-w><c-t> :WMToggle<cr>

let g:bufExplorerSortBy = "name"

"set ctags serch patch
set tags=tags;
set autochdir

if MySys() == "windows"
		let Tlist_Ctags_Cmd = '"'.$VIMRUNTIME.'/ctags.exe"'
elseif MySys()=="linux"
		let Tlist_Ctags_Cmd = '/usr/bin/ctags'
endif

let Tlist_Show_One_File = 1
let Tlist_Exit_OnlyWindow = 1
let Tlist_Use_Right_Window = 1
let Tlist_File_Fold_Auto_Close = 1
let Tlist_Auto_Open = 0
let Tlist_Auto_Update = 1
let Tlist_Hightlight_Tag_On_BufEnter = 1
let Tlist_Enable_Fold_Column = 0
let Tlist_Process_File_Always = 1
let Tlist_Display_Prototype = 0
let Tlist_Compact_Format = 1

""""""""""""""""""""""""""""""
" => Tag list (ctags) - not used
""""""""""""""""""""""""""""""
let Tlist_Ctags_Cmd = "/usr/bin/ctags"
let Tlist_Sort_Type = "name"
let Tlist_Show_Menu = 1
map <leader>t :Tlist<cr>
"map <F3> :Tlist<cr>

"NERD_tree plugin setting swap
"map <F4> :NERDTree<CR> 
nnoremap <silent><F4> :NERDTreeToggle<CR>
nnoremap <silent><F3> :TlistToggle<CR>
"imap <F4> <ESC> :NERDTreeToggle<CR>
"map BufExplorer cmd list"
nmap <leader>bfe :BufExplorer<cr>
nmap <leader>bfeh :BufExplorerHorizontalSplit<cr>
nmap <leader>bfev :BufExplorerVerticalSplit<cr> 
"let g:LookupFile_TagExpr='"./filenametags"'
""""""""""""""""""""""""""""""
" lookupfile setting
""""""""""""""""""""""""""""""
let g:LookupFile_MinPatLength = 2               "最少输入2个字符才开始查找
let g:LookupFile_PreserveLastPattern = 0        "不保存上次查找的字符串
let g:LookupFile_PreservePatternHistory = 1     "保存查找历史
let g:LookupFile_AlwaysAcceptFirst = 1          "回车打开第一个匹配项目
let g:LookupFile_AllowNewFiles = 0              "不允许创建不存在的文件
if filereadable("./filenametags")                "设置tag文件的名字
    let g:LookupFile_TagExpr = '"./filenametags"'
endif
nmap <silent> <leader>lk :LUTags<cr> 



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" cscope setting
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has("cscope")
set csprg=/usr/bin/cscope
set csto=1
set cst
set nocsverb
" add any database in current directory
if filereadable("cscope.out")
      cs add cscope.out
endif
set csverb
endif

nmap <C-@>s :cs find s <C-R>=expand("<cword>")<CR><CR>
nmap <C-@>g :cs find g <C-R>=expand("<cword>")<CR><CR>
nmap <C-@>c :cs find c <C-R>=expand("<cword>")<CR><CR>
nmap <C-@>t :cs find t <C-R>=expand("<cword>")<CR><CR>
nmap <C-@>e :cs find e <C-R>=expand("<cword>")<CR><CR>
nmap <C-@>f :cs find f <C-R>=expand("<cfile>")<CR><CR>
nmap <C-@>i :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
nmap <C-@>d :cs find d <C-R>=expand("<cword>")<CR><CR>

"映射LUBufs为,ll
"nnoremap <silent> <F5> :LookupFile<CR>   
"nnoremap <silent> ll :LUBufs<CR>    
"nnoremap <silent> <leader>lw :LUWalk<CR>   

" FuzzyFinder
"map <C-p> :FuzzyFinderFile<CR>
" FuzzyFinder open with directory of current directory (not directory of
" buffer)
"nnoremap <C-p> :FuzzyFinderFile <C-r>=fnamemodify(getcwd(), ':p')<CR><CR> 
" FuzzyFinder open with directory of the current buffer
nnoremap <C-p> :FuzzyFinderFile <C-r>=expand('%:~:.')[:-1-len(expand('%:~:.:t'))]<CR><CR> 
inoremap <C-p> <Esc>:FuzzyFinderFile <C-r>=expand('%:~:.')[:-1-len(expand('%:~:.:t'))]<CR><CR> 
vnoremap <C-p> <Esc>:FuzzyFinderFile <C-r>=expand('%:~:.')[:-1-len(expand('%:~:.:t'))]<CR><CR> 

""""""""""""""""""""""""""""""
" => LaTeX Suite thing
""""""""""""""""""""""""""""""
"set grepprg=grep\ -r\ -s\ -n 
let g:Tex_DefaultTargetFormat="pdf"
let g:Tex_ViewRule_pdf='xpdf'

if has("autocmd")
"Binding
au BufRead *.tex map <silent><leader><space> :w!<cr> :silent! call Tex_RunLaTeX()<cr>

"Auto complete some things ;)
au BufRead *.tex ino $i indent 
au BufRead *.tex ino $* cdot 
au BufRead *.tex ino $i item 
au BufRead *.tex ino $m [<cr>]<esc>O
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Filetype generic
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Todo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"au BufNewFile,BufRead *.todo so ~/vim_local/syntax/amido.vim

""""""""""""""""""""""""""""""
" => VIM
""""""""""""""""""""""""""""""
if has("autocmd")
au BufRead,BufNew *.vim map <buffer> <leader><space> :w!<cr>:source %<cr>
endif

""""""""""""""""""""""""""""""
" => HTML related
""""""""""""""""""""""""""""""
" HTML entities - used by xml edit plugin
let xml_use_xhtml = 1
"let xml_no_auto_nesting = 1

"To HTML
let html_use_css = 0
let html_number_lines = 0
let use_xhtml = 1


""""""""""""""""""""""""""""""
" => Ruby & PHP section
""""""""""""""""""""""""""""""
""""""""""""""""""""""""""""""
" => Python section
""""""""""""""""""""""""""""""
""Run the current buffer in python - ie. on leader+space
"au BufNewFile,BufRead *.py so ~/vim_local/syntax/python.vim
"au BufNewFile,BufRead *.py map <buffer> <leader><space> :w!<cr>:!python %<cr>
"au BufNewFile,BufRead *.py so ~/vim_local/plugin/python_fold.vim

""Set some bindings up for 'compile' of python
"au BufNewFile,BufRead *.py set makeprg=python -c "import py_compile,sys; sys.stderr=sys.stdout; py_compile.compile(r'%')"
"au BufNewFile,BufRead *.py set efm=%C %.%#,%A File "%f"\, line %l%.%#,%Z%[%^ ]%\@=%m
"au BufNewFile,BufRead *.py nmap <buffer> <F8> :w!<cr>:make<cr>

""Python iMap
"au BufNewFile,BufRead *.py set cindent
"au BufNewFile,BufRead *.py ino <buffer> $r return 
"au BufNewFile,BufRead *.py ino <buffer> $s self 
"au BufNewFile,BufRead *.py ino <buffer> $c ##<cr>#<space><cr>#<esc>kla
"au BufNewFile,BufRead *.py ino <buffer> $i import 
"au BufNewFile,BufRead *.py ino <buffer> $p print 
"au BufNewFile,BufRead *.py ino <buffer> $d """<cr>"""<esc>O

""Run in the Python interpreter
"function! Python_Eval_VSplit() range
" let src = tempname()
" let dst = tempname()
" execute ": " . a:firstline . "," . a:lastline . "w " . src
" execute ":!python " . src . " > " . dst
" execute ":pedit! " . dst
"endfunction
"au BufNewFile,BufRead *.py vmap <F7> :call Python_Eval_VSplit()<cr> 


""""""""""""""""""""""""""""""
" => Cheetah section
"""""""""""""""""""""""""""""""

"""""""""""""""""""""""""""""""
" => Java section
"""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""
" => JavaScript section
"""""""""""""""""""""""""""""""
"au BufNewFile,BufRead *.js so ~/vim_local/syntax/javascript.vim
"function! JavaScriptFold() 
" set foldmethod=marker
" set foldmarker={,}
" set foldtext=getline(v:foldstart)
"endfunction
"au BufNewFile,BufRead *.js call JavaScriptFold()
"au BufNewFile,BufRead *.js imap <c-t> console.log();<esc>hi
"au BufNewFile,BufRead *.js imap <c-a> alert();<esc>hi
"au BufNewFile,BufRead *.js set nocindent
"au BufNewFile,BufRead *.js ino <buffer> $r return 

"au BufNewFile,BufRead *.js ino <buffer> $d //<cr>//<cr>//<esc>ka<space> 
"au BufNewFile,BufRead *.js ino <buffer> $c /**<cr><space><cr>**/<esc>ka


if has("eval") && has("autocmd")
fun! <SID>abbrev_cpp()
iabbrev <buffer> cci const_iterator
iabbrev <buffer> ccl cla
iabbrev <buffer> cco const
iabbrev <buffer> cdb \bug
iabbrev <buffer> cde \throw
iabbrev <buffer> cdf /** \file<CR><CR>/<Up>
iabbrev <buffer> cdg \ingroup
iabbrev <buffer> cdn /** \namespace<CR><CR>/<Up>
iabbrev <buffer> cdp \param
iabbrev <buffer> cdt \test
iabbrev <buffer> cdx /**<CR><CR>/<Up>
iabbrev <buffer> cit iterator
iabbrev <buffer> cns namespace
iabbrev <buffer> cpr protected
iabbrev <buffer> cpu public
iabbrev <buffer> cpv private
iabbrev <buffer> csl std::list
iabbrev <buffer> csm std::map
iabbrev <buffer> css std::string
iabbrev <buffer> csv std::vector
iabbrev <buffer> cty typedef
iabbrev <buffer> cun using namespace
iabbrev <buffer> cvi virtual
iabbrev <buffer> #i #include
iabbrev <buffer> #d #define
endfun

fun! <SID>abbrev_java()
iabbrev <buffer> #i import
iabbrev <buffer> #p System.out.println
iabbrev <buffer> #m public static void mainString[] args
endfun

fun! <SID>abbrev_python()
iabbrev <buffer> #i import
iabbrev <buffer> #p print
iabbrev <buffer> #m if __name__=="__main":

endfun

augroup abbreviation
autocmd!
autocmd FileType cpp,c :call <SID>abbrev_cpp()
autocmd FileType java :call <SID>abbrev_java()
autocmd FileType python :call <SID>abbrev_python()
augroup END
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => MISC
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Remove the Windows ^M
"noremap <Leader>m :%s/\r//g<CR>

"Paste toggle - when pasting something in, don't indent.
"set pastetoggle=<F3>

"Remove indenting on empty line
map <F2> :%s/s*$//g<cr>:noh<cr>''

"Super paste
ino <C-v> <esc>:set paste<cr>mui<C-R>+<esc>mv'uV'v=:set nopaste<cr>
let g:tlist_javascript_settings = 'javascript;s:string;a:array;o:object;f:function;m:member'
