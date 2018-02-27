" File Name: browser_extra.vim
" Maintainer: Moshe Kaminsky
" Last Update: November 12, 2004
" Description: extra browser commands. Part of the browser plugin.
" Version: 1.1

" don't run twice or when 'compatible' is set
if exists('g:browser_extra_version') || &compatible
  finish
endif
let g:browser_extra_version = g:browser_plugin_version

let g:browser_plugin_load = g:browser_plugin_load . ',extra.vim'

"""" searching """"
BrowserCommand -bang -bar -nargs=+ -complete=custom,BrowserSearchSrvComplete 
          \SearchUsing

BrowserCommand -bang -bar -nargs=* Search 

vnoremap <unique> <silent> <C-S> 
      \<C-C>:
      \call <SID>saveReg('s')<CR>gv"sy:
      \Search <C-R>s<CR>:
      \let @s=<SID>saveReg('s')<CR>

nnoremap <unique> <C-S> :Search<CR>

function! <SID>saveReg(reg)
  let res = exists('s:saved_' . a:reg) ? s:saved_{a:reg} : ''
  let s:saved_{a:reg} = getreg(a:reg)
  return res
endfunction

BrowserCommand -bang -bar -nargs=* Keyword 

nnoremap <unique> <C-K> :Keyword<CR>

" search using google
command! -bang -bar -nargs=* Google SearchUsing<bang> google <args>

" dictionary search
command! -bang -bar -nargs=? Dictionary SearchUsing<bang> dictionary <args>

command! -bang -bar -nargs=* Thesaurus SearchUsing<bang> thesaurus <args> 

"""" vim site stuff """"

" search for a script/tip
BrowserCommand -bar -bang -nargs=+ -complete=custom,BrowserVimSearchTypes 
      \VimSearch 

" go to a given script/tip by number
command! -bar -nargs=1 VimScript 
      \Browse http://vim.sourceforge.net/scripts/script.php?script_id= <args>
command! -bar -nargs=1 VimTip 
      \Browse http://vim.sourceforge.net/tips/tip.php?tip_id= <args>

" completion

function! BrowserVimSearchTypes(...)
  return "script\ncolorscheme\nftplugin\ngame\nindent\nsyntax\nutility\ntip"
endfunction

function! BrowserSearchSrvComplete(Arg, CmdLine, Pos)
  let result = BrowserCompleteBrowse(':_search:', a:CmdLine, a:Pos)
  let result = substitute(result, ':_search:', '', 'g')
  return result
endfunction
