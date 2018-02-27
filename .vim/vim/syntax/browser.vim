" File Name: browser.vim
" Maintainer: Moshe Kaminsky
" Last Modified: Tue 15 Mar 2005 11:24:33 AM IST
" Description: syntax for a browser buffer. part of the browser plugin
" Version: 1.1
"

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

SynMarkDef Link display oneline contains=TOP,Cite keepend
SynMarkDef FollowedLink display oneline contains=TOP keepend
SynMarkDef Form matchgroup=browserInputBoundary oneline display keepend
SynMarkDef Image oneline display keepend
SynMarkDef Bold contains=TOP keepend
SynMarkDef Underline contains=TOP keepend
SynMarkDef Italic contains=TOP keepend
SynMarkDef Teletype contains=TOP keepend
SynMarkDef Strong contains=TOP keepend
SynMarkDef Em contains=TOP keepend
SynMarkDef Code contains=TOP keepend
SynMarkDef Kbd contains=TOP keepend
SynMarkDef Samp contains=TOP keepend
SynMarkDef Var contains=TOP keepend
SynMarkDef Cite contains=TOP keepend
SynMarkDef Definition contains=TOP keepend
SynMarkDef Header1 contains=TOP keepend display 
      \nextgroup=browserHeaderUL skipnl skipwhite
SynMarkDef Header2 contains=TOP keepend display 
      \nextgroup=browserHeaderUL skipnl skipwhite
SynMarkDef Header3 contains=TOP keepend display 
      \nextgroup=browserHeaderUL skipnl skipwhite
SynMarkDef Header4 contains=TOP keepend display 
      \nextgroup=browserHeaderUL skipnl skipwhite
SynMarkDef Header5 contains=TOP keepend display 
      \nextgroup=browserHeaderUL skipnl skipwhite
SynMarkDef Header6 contains=TOP keepend display 
      \nextgroup=browserHeaderUL skipnl skipwhite

syntax region browserPre matchgroup=browserIgnore start=/\~>$/ end=/^<\~\s*$/ 
      \contains=TOP keepend
syntax match browserHeaderUL /^\s*====*\s*$/ display contained
syntax match browserHeaderUL /^\s*----*\s*$/ display contained
syntax match browserHeaderUL /^\s*^^^^*\s*$/ display contained
syntax match browserHeaderUL /^\s*++++*\s*$/ display contained
syntax match browserHeaderUL /^\s*""""*\s*$/ display contained
syntax match browserHeaderUL /^\s*\.\.\.\.*\s*$/ display contained

" The head
syntax region browserHead matchgroup=browserHeadTitle 
      \start=/^Document header:.*{{{$/ end=/^}}}$/ 
      \contains=browserHeadField keepend
syntax region browserHeadField matchgroup=browserHeadKey 
      \start=/^  [^:]*:/ end=/$/ oneline display contained

" Forms
syntax region browserTextField matchgroup=browserTFstart 
      \start=+\]>+ end=+$+ oneline display
syntax match browserRadioSelected /(\*)/hs=s+1,he=e-1 display
syntax region browserTextArea matchgroup=browserTABorder 
      \start=/^ *--- Click to edit the text area ----* {{{$/ 
      \end=/^ *}}} --*$/ keepend

syntax sync fromstart

if version >= 508 || !exists("did_c_syn_inits")
  if version < 508
    let did_c_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  SynMarkLink Header1 DiffChange
  SynMarkLink Header2 DiffAdd
  SynMarkLink Header3 DiffDelete
  SynMarkLink Header4 DiffText
  SynMarkLink Header5 Exception
  SynMarkLink Header6 StorageClass
  HiLink browserHeaderUL PreProc
  HiLink browserIgnore Ignore
  HiLink browserPre Identifier
  HiLink browserHeadTitle Title
  HiLink browserHeadKey Type
  HiLink browserHeadField Constant
  HiLink browserTextField DiffAdd
  HiLink browserTFstart Folded
  HiLink browserTAborder Folded
  HiLink browserTextArea Repeat
  HiLink browserRadioSelected Label
  HiLink browserInputBoundary Delimiter

  SynMarkLink Link Underlined
  SynMarkLink FollowedLink LineNr
  SynMarkLink Form Label
  SynMarkLink Image Special
  SynMarkHighlight Bold term=bold cterm=bold gui=bold
  SynMarkHighlight Underline term=underline cterm=underline gui=underline
  SynMarkHighlight Italic term=italic cterm=italic gui=italic
  SynMarkLink Teletype Special
  SynMarkHighlight Strong term=standout cterm=standout gui=standout
  SynMarkHighlight Em term=bold,italic cterm=bold,italic gui=bold,italic
  SynMarkLink Code Identifier
  SynMarkLink Kbd Operator
  SynMarkHighlight Samp term=inverse cterm=inverse gui=inverse
  SynMarkLink Var Repeat
  SynMarkLink Definition Define
  SynMarkLink Cite Constant

  delcommand HiLink
endif


let b:current_syntax = 'browser'

