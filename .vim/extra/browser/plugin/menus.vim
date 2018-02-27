" File Name: menus.vim
" Author: Moshe Kaminsky
" Original Date: Sat 12 Mar 2005 11:24:03 AM IST
" Last modified: Sat 12 Mar 2005 11:24:03 AM IST
" Description: TODO

" the toolbar
aunmenu ToolBar.FindPrev
aunmenu ToolBar.FindNext
aunmenu ToolBar.Redo

menu icon=Back 1.1 ToolBar.FindPrev :Back<CR>
tmenu ToolBar.FindPrev Back
menu icon=Forward 1.1 ToolBar.FindNext :Forward<CR>
tmenu ToolBar.FindNext Forward
menu icon=Reload 1.1 ToolBar.Redo :Reload<CR>
tmenu ToolBar.Redo Reload
menu 1.1 ToolBar.-sep- :

