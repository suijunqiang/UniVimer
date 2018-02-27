" File Name: short.vim
" Author: Moshe Kaminsky
" Original Date: Sat 12 Mar 2005 11:23:03 AM IST
" Last modified: Sat 12 Mar 2005 11:38:45 AM IST
" Description: TODO

" opening
command! -bar -bang -nargs=* -complete=custom,BrowserCompleteBrowse SBrowse 
      \call BrowserBrowse(<q-args>, <q-bang>)
command! -bar Follow call BrowserFollow()
command! -bar Submit call BrowserSubmit()
command! -bar -nargs=? -complete=dir SaveLink call BrowserSaveLink(<f-args>)
command! -bar -bang Reload call BrowserReload(<q-bang>)

" history
command! -bar -range=1 Back call BrowserBack(<count>)
command! -bar -range=1 Pop call BrowserBack(<count>)
command! -bar -range=1 Forward call BrowserForward(<count>)
command! -bar -range=1 Tag call BrowserForward(<count>)
command! -bar Tags call BrowserHistory()

" bookmarks
command! -bar -nargs=1 -bang Bookmark call BrowserBookmark(<f-args>, <q-bang>)
command! -bar -nargs=1 -bang -complete=custom,BrowserCompleteBkmkFile AddrBook 
      \call BrowserChangeBookmarkFile(<f-args>, <q-bang>)
command! -bar -nargs=? -complete=custom,BrowserCompleteBkmkFile ListBookmarks 
      \call BrowserListBookmarks(<f-args>)

" forms
command! -bar -range=1 NextChoice call BrowserNextChoice(<count>)
command! -bar -range=1 PrevChoice call BrowserPrevChoice(<count>)
command! -bar Click call BrowserClick()
command! -bar -range=1 ScrollUp call BrowserTextScroll(<count>)
command! -bar -range=1 ScrollDown call BrowserTextScroll(-<count>)

" inline images
command! -bar -nargs=? -complete=dir ImageSave 
      \call BrowserImage('save', <f-args>)
command! -bar ImageView call BrowserImage('default')
command! -bar Image call BrowserImage('ask')

" other
command! -bar ShowHeader call BrowserShowHeader()
command! -bar HideHeader call BrowserHideHeader()
command! -bar -bang ViewSource call BrowserViewSource(<q-bang>)
command! -bar -range=1 NextLink call BrowserNextLink(<count>)
command! -bar -range=1 PrevLink call BrowserPrevLink(<count>)
command! -bar CloseSideBar perl VIM::Browser::closeSidebar;

