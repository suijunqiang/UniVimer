" File Name: mappings.vim
" Maintainer: Moshe Kaminsky <kaminsky@math.huji.ac.il>
" Last Update: November 02, 2004
" Description: mappings for browser windows. Part of the browser plugin
" Version: 1.1

BrowserMap  Follow
BrowserMap g<LeftMouse> Follow
BrowserMap <C-LeftMouse> Follow
BrowserMap  Back
BrowserMap g<RightMouse> Back
BrowserMap <C-RightMouse> Back
BrowserMap <Tab> NextLink
BrowserMap <S-Tab> PrevLink
BrowserMap <C-N> NextChoice
BrowserMap <C-P> PrevChoice
BrowserMap <S-Up> TextScrollDown
BrowserMap <S-Down> TextScrollUp
BrowserMap <CR> Click
BrowserMap <space> <C-F> scroll page down
BrowserMap b <C-B> scroll page up
BrowserMap q :q<CR> quit the browser window
BrowserMap <C-R> Reload
BrowserMap H Help
imap <silent> <buffer> <Tab> <Esc><Tab>
imap <silent> <buffer> <S-Tab> <Esc><S-Tab>
imap <silent> <buffer> <CR> <Esc>:BrowserSubmit<CR>

cnoremap <buffer> <C-G> <C-R>=BrowserGetUri()<CR>
nmap <buffer> <LocalLeader>g :Browse <C-G>

if &l:wrap
  nnoremap <buffer> j gj
  nnoremap <buffer> k gk
endif

nnoremap <silent> <buffer> <RightMouse> 
      \<LeftMouse>:perl VIM::Browser::buildMenu<CR><RightMouse>

