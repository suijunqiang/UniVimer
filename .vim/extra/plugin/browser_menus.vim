" File Name: browser_menus.vim
" Maintainer: Moshe Kaminsky
" Last Update: November 13, 2004
" Description: browser menus. Part of the browser plugin
" Version: 1.1

" don't run twice or when 'compatible' is set
if exists('g:browser_menus_version') || &compatible
  finish
endif
let g:browser_menus_version = g:browser_plugin_version
let g:browser_plugin_load = g:browser_plugin_load . ',menus.vim'

" the context menu
menu .1 PopUp.Search\ The\ Web :Search<CR>
vmenu .1 PopUp.Search\ The\ Web :Search<CR>

