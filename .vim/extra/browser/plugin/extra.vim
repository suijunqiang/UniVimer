" File Name: extra.vim
" Author: Moshe Kaminsky
" Original Date: Sat 12 Mar 2005 11:05:05 AM IST
" Last modified: Sat 12 Mar 2005 11:12:12 AM IST
" Description: TODO

"""" searching """"
command! -bang -bar -nargs=+ -complete=custom,BrowserSearchSrvComplete 
          \SearchUsing call BrowserSearchUsing(<q-bang>, <q-args>)

if ! exists('g:browser_search_engine')
  let g:browser_search_engine = 'google'
endif

command! -bang -bar -nargs=* Search 
        \call BrowserSearchUsing(<q-bang>, 
                                \g:browser_search_engine . ' ' . <q-args>)

if !exists('g:browser_keyword_search')
  let g:browser_keyword_search = 'dictionary'
endif

command! -bang -bar -nargs=* Keyword 
        \call BrowserSearchUsing(<q-bang>, 
                                \g:browser_keyword_search . ' ' .<q-args>)


"""" vim site stuff """"

" search for a script/tip
command! -bar -bang -nargs=+ -complete=custom,BrowserVimSearchTypes VimSearch 
      \call BrowserVimSearch(<q-bang>,  <q-args>)

function! BrowserVimSearch(Bang, Args)
  if a:Bang == '!'
    let g:browser_sidebar = 'VimSearch'
  endif
  perl <<EOF
  VIM::Browser::setup();
  local $_ = VIM::Eval('a:Args');
  my $type = $1 if s/^\s*(\w+)//o;
  $type = '' if $type eq 'script';
  my $uri = 'http://vim.sourceforge.net/' .
    ( $type eq 'tip' ? 
      'tips/tip_search_results.php?' :
      "scripts/script_search_results.php?script_type=$type&" ) . 'keywords=';
  VIM::Browser::browse("$uri $_");
EOF
  let g:browser_sidebar = 0
endfunction
  
function! BrowserSearchUsing(Bang, Args)
  let service = matchstr(a:Args, '^[^ ]*')
  let words = substitute(a:Args, '^[^ ]* *', '', '')
  if ! strlen(words)
    let words = expand('<cword>')
  endif
  if a:Bang == '!'
    let g:browser_sidebar = service
  endif
  execute 'Browse :_search:' . service . ' ' . words
  let g:browser_sidebar = 0
endfunction

