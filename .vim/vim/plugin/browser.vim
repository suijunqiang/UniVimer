" File Name: browser.vim
" Maintainer: Moshe Kaminsky <kaminsky@math.huji.ac.il>
" Last Modified: Tue 15 Mar 2005 11:47:17 AM IST
" Description: web browser plugin for vim
" Version: 1.1
" GetLatestVimScripts: 1128 1 synmark.vim
"

" don't run twice or when 'compatible' is set
if exists('g:browser_plugin_version') || &compatible
  finish
endif
let g:browser_plugin_version = 1.1

let g:browser_sidebar = 0

"""""""""""""" commands """""""""""""""""""
" long commands. The short versions from version 0.1 are in browser_short.vim

command! -nargs=+ BrowserCommand call BrowserDefCmd(<q-args>)

function! BrowserDefCmd(args)
  let cmd = substitute(a:args, '^.*\<\(\S\+\)$', '\1', '')
  execute 'command! ' . a:args . ' call BrowserInit() | ' . cmd . ' <args>'
endfunction

" opening
BrowserCommand -bar -nargs=* -complete=custom,s:CompleteBrowse Browse

" history
command! -bang -bar -nargs=? BrowserHistory 
      \if strlen(<q-bang>) | 
      \  BrowserSideBar BrowserHistory <args> | 
      \else | 
      \  Browse history://<args> | 
      \endif

" bookmarks
BrowserCommand -bar -nargs=1 -bang -complete=custom,s:CompleteBkmkFile 
      \BrowserAddrBook
BrowserCommand -bar -nargs=? -complete=custom,s:CompleteBkmkFile 
      \BrowserListBookmarks
command! -bang -bar -nargs=? -complete=custom,s:CompleteBkmkFile 
      \BrowserBookmarksPage if strlen(<q-bang>) | 
      \BrowserSideBar BrowserBookmarksPage <args> | 
      \else | Browse :<args>: | endif

" other
command! -bar -nargs=+ -complete=command BrowserSideBar 
      \let g:browser_sidebar = matchstr(<q-args>, '^\S*') | 
      \<args> | let g:browser_sidebar = 0


"""" init the browser """"
let g:browser_plugin_load = 'main.vim'
function! BrowserInit()
  if &verbose > 0 || ( exists('g:browser_verbosity_level') && 
                      \g:browser_verbosity_level > 1 )
    echomsg 'Initializing browser plugin...'
  endif
  exec 'runtime!' .  substitute(g:browser_plugin_load, 
                               \'\(^\|,\)', ' browser/plugin/', 'g')
endfunction

command -bar BrowserInit call BrowserInit()

"""" completion """"
function! s:CompleteBkmkFile(...)
  call BrowserInit()
  return BrowserCompleteBkmkFile(a:1, a:2, a:3)
endfunction

function! s:CompleteBrowse(Arg, CmdLine, Pos)
  call BrowserInit()
  return BrowserCompleteBrowse(a:Arg, a:CmdLine, a:Pos)
endfunction

