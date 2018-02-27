" File Name: browser.vim
" Maintainer: Moshe Kaminsky
" Last Modified: Tue 15 Mar 2005 11:22:42 AM IST
" Description: settings for a browser buffer. part of the browser plugin
" Version: 1.1

" make sure the browser buffers are not associated with any files
setlocal buftype=nofile
setlocal nobuflisted
setlocal bufhidden=hide
setlocal noswapfile
" folding is used only for the header fields
setlocal foldmethod=marker
" the only editing that should be going on is text inputs in forms. Make sure 
" we don't get any extra lines there
setlocal formatoptions=
if ! exists('w:browser_status_msg')
  let w:browser_status_msg=''
endif
setlocal statusline=%{w:browser_status_msg}

if g:browser_page_modifiable
  if maparg('<Esc>', 'i')
    iunmap <Esc>
  endif
else
  setlocal nomodifiable
  inoremap <buffer> <silent> <Esc> <Esc>:setlocal nomodifiable<CR>
endif

setlocal linebreak
if strlen(g:browser_sidebar) > 1
  setlocal nowrap
endif

"""" mappings """"""
" This are "virtual" <Plug> mappings. The actual default key mappings are in 
" ftplugin/browser/mappings.vim

command! -nargs=+ BrowserDefMap call s:DefMap(<q-args>)

function! s:DefMap(args)
  perl <<EOF
  $VIM::Browser::args = VIM::Eval('a:args');
  package VIM::Browser;
  if ( $args =~ /^(\S+)\s+([^;]+?)\s*;\s*(.*)$/ ) {
    my ($name, $val, $help) = ($1, $2, $3);
    $Help{$name} = $help;
    doCommand("nnoremap <silent> <buffer> <Plug>Browser$name $val");
  }
EOF
endfunction

perl undef %VIM::Browser::MappedTo;

BrowserDefMap Follow :BrowserFollow<CR> ; follow link under the cursor
BrowserDefMap Back :execute v:count1 . 'BrowserBack'<CR> ; go back n pages
BrowserDefMap NextLink :execute v:count1 . 'BrowserNextLink'<CR> ; 
      \jump to the next link on the page
BrowserDefMap PrevLink :execute v:count1 . 'BrowserPrevLink'<CR> ;
      \jump to the previous link on the page
BrowserDefMap NextChoice :execute v:count1 . 'BrowserNextChoice'<CR> ; 
      \select the next choice in the current radio button or option
BrowserDefMap PrevChoice :execute v:count1 . 'BrowserPrevChoice'<CR> ; 
      \select the previous choice in the current radio button or option
BrowserDefMap TextScrollDown :execute v:count1 . 'BrowserTextScrollDown'<CR>; 
      \scroll text-area text down
BrowserDefMap TextScrollUp :execute v:count1 . 'BrowserTextScrollUp'<CR> ; 
      \scroll text-area text up
BrowserDefMap Click :BrowserClick<CR> ; click form input
BrowserDefMap Reload :BrowserReload<CR> ; reload the current page
BrowserDefMap Help :BrowserHelp<CR> ; show this message

delcommand BrowserDefMap
delfunction s:DefMap

