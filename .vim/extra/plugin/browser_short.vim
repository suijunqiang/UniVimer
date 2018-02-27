" File Name: browser_short.vim
" Maintainer: Moshe Kaminsky <kaminsky@math.huji.ac.il>
" Last Update: November 12, 2004
" Description: short versions of browser commands. Part of the browser plugin
" Version: 1.1

" don't run twice or when 'compatible' is set
if exists('g:browser_short_version') || &compatible
  finish
endif
let g:browser_short_version = g:browser_plugin_version
let g:browser_plugin_load = g:browser_plugin_load . ',short.vim'

" history
command! -bang -bar -nargs=? History if strlen(<q-bang>) | 
      \BrowserSideBar History<args> | else | Browse history://<args> | endif

" bookmarks
BrowserCommand -bar -nargs=1 -bang -complete=custom,s:CompleteBkmkFile 
      \AddrBook 
BrowserCommand -bar -nargs=? -complete=custom,s:CompleteBkmkFile 
      \ListBookmarks 

command! -bang -bar -nargs=? -complete=custom,s:CompleteBkmkFile 
      \BookmarksPage if strlen(<q-bang>) | 
      \BrowserSideBar BookmarksPage <args> | 
      \else | Browse :<args>: | endif

" other
command! -bar -nargs=+ -complete=command SideBar 
      \let g:browser_sidebar = matchstr(<q-args>, '^\S*') | 
      \<args> | let g:browser_sidebar = 0

"""" completion """"
function! s:CompleteBkmkFile(...)
  call BrowserInit()
  return BrowserCompleteBkmkFile(a:1, a:2, a:3)
endfunction


