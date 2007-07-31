" Author:  Eric Van Dewoestine
" Version: $Revision$
"
" Description: {{{
"   see http://eclim.sourceforge.net/vim/php/search.html
"
" License:
"
" Copyright (c) 2005 - 2006
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"      http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.
"
" }}}

" Global Varables {{{
  if !exists("g:EclimPhpSearchSingleResult")
    " possible values ('split', 'edit', 'lopen')
    let g:EclimPhpSearchSingleResult = "split"
  endif
" }}}

" Script Varables {{{
  let s:search_element =
    \ '-command php_find_definition -p "<project>" -f "<file>" -o <offset>'
  let s:search_pattern = '-command php_search -n "<project>" <args>'
  let s:include_paths = '-command php_include_paths -p "<project>"'
  let s:options = ['-p', '-t', '-s']
  let s:scopes = ['all', 'project']
  let s:types = [
      \ 'class',
      \ 'function',
      \ 'constant'
    \ ]
" }}}

" Search (...) {{{
" Executes a search.
function! eclim#php#search#Search (...)
  let argline = ""
  let index = 1
  while index <= a:0
    if index != 1
      let argline = argline . " "
    endif
    let argline = argline . a:{index}
    let index = index + 1
  endwhile

  if !eclim#project#IsCurrentFileInProject(1)
    return
  endif
  "let in_project = eclim#project#IsCurrentFileInProject(0)
  "if !in_project
  "  return s:SearchAlternate(argline, 0)
  "endif

  let project = eclim#project#GetCurrentProjectName()

  let search_cmd = s:search_pattern
  let search_cmd = substitute(search_cmd, '<project>', project, '')
  let search_cmd = substitute(search_cmd, '<args>', argline, '')
  " quote the search pattern
  let search_cmd =
    \ substitute(search_cmd, '\(.*-p\s\+\)\(.\{-}\)\(\s\|$\)\(.*\)', '\1"\2"\3\4', '')
  let result =  eclim#ExecuteEclim(search_cmd)
  let results = split(result, '\n')
  if len(results) == 1 && results[0] == '0'
    return
  endif

  if !empty(results)
    call eclim#util#SetLocationList(eclim#util#ParseLocationEntries(results))
    " if only one result and it's for the current file, just jump to it.
    " note: on windows the expand result must be escaped
    if len(results) == 1 && results[0] =~ escape(expand('%:p'), '\') . '|'
      if results[0] !~ '|1 col 1|'
        lfirst
      endif

    " single result in another file.
    elseif len(results) == 1 && g:EclimPhpSearchSingleResult != "lopen"
      let entry = getloclist(0)[0]
      exec g:EclimPhpSearchSingleResult . ' ' . bufname(entry.bufnr)
      call eclim#util#GoToBufferWindowOrOpen
        \ (bufname(entry.bufnr), g:EclimPhpSearchSingleResult)

      call cursor(entry.lnum, entry.col)
    else
      lopen
    endif
  else
    let searchedFor = substitute(argline, '.*-p \(.\{-}\)\( .*\|$\)', '\1', '')
    call eclim#util#EchoInfo("Pattern '" . searchedFor . "' not found.")
  endif

endfunction " }}}

" FindDefinition () {{{
" Finds the defintion of the element under the cursor.
function eclim#php#search#FindDefinition ()
  if !eclim#project#IsCurrentFileInProject(1)
    return
  endif

  " update the file.
  call eclim#util#ExecWithoutAutocmds('silent update')

  let project = eclim#project#GetCurrentProjectName()
  let file = eclim#project#GetProjectRelativeFilePath(expand("%:p"))
  let offset = eclim#util#GetCurrentElementOffset()

  let search_cmd = s:search_element
  let search_cmd = substitute(search_cmd, '<project>', project, '')
  let search_cmd = substitute(search_cmd, '<file>', file, '')
  let search_cmd = substitute(search_cmd, '<offset>', offset, '')

  let result =  eclim#ExecuteEclim(search_cmd)
  let results = split(result, '\n')
  if len(results) == 1 && results[0] == '0'
    return
  endif

  if !empty(results)
    call eclim#util#SetLocationList(eclim#util#ParseLocationEntries(results))

    " if only one result and it's for the current file, just jump to it.
    " note: on windows the expand result must be escaped
    if len(results) == 1 && results[0] =~ escape(expand('%:p'), '\') . '|'
      if results[0] !~ '|1 col 1|'
        lfirst
      endif

    " single result in another file.
    elseif len(results) == 1 && g:EclimPhpSearchSingleResult != "lopen"
      let entry = getloclist(0)[0]
      call eclim#util#GoToBufferWindowOrOpen
        \ (bufname(entry.bufnr), g:EclimPhpSearchSingleResult)

      call cursor(entry.lnum, entry.col)
    else
      lopen
    endif
  else
    call eclim#util#EchoInfo("Element not found.")
  endif
endfunction " }}}

" FindInclude () {{{
" Finds the include file under the cursor
function eclim#php#search#FindInclude ()
  if !eclim#project#IsCurrentFileInProject(1)
    return
  endif

  let file = substitute(getline('.'),
    \ ".*\\<\\(require\\|include\\)\\s*[(]\\?['\"]\\([^'\"]*\\)['\"].*", '\2', '')

  let project = eclim#project#GetCurrentProjectName()
  let command = s:include_paths
  let command = substitute(command, '<project>', project, '')
  let result =  eclim#ExecuteEclim(command)
  let paths = split(result, '\n')

  let results = split(globpath('.,' . join(paths, ','), file), '\n')

  if !empty(results)
    call eclim#util#SetLocationList(eclim#util#ParseLocationEntries(results))

    " single result in another file.
    if len(results) == 1 && g:EclimPhpSearchSingleResult != "lopen"
      let entry = getloclist(0)[0]
      call eclim#util#GoToBufferWindowOrOpen
        \ (bufname(entry.bufnr), g:EclimPhpSearchSingleResult)
    else
      lopen
    endif
  else
    call eclim#util#EchoInfo("File not found.")
  endif
endfunction " }}}

" SearchContext () {{{
" Executes a contextual search.
function! eclim#php#search#SearchContext ()
  if getline('.')[col('.') - 1] == '$'
    call cursor(line('.'), col('.') + 1)
    let cnum = eclim#util#GetCurrentElementColumn()
    call cursor(line('.'), col('.') - 1)
  else
    let cnum = eclim#util#GetCurrentElementColumn()
  endif

  if getline('.') =~ "\\<\\(require\\|include\\)\\s*[(]\\?['\"][^'\"]*\\%" . cnum . "c"
    call eclim#php#search#FindInclude()
    return
  elseif getline('.') =~ '\<class\s\+\%' . cnum . 'c'
    call eclim#util#EchoInfo("TODO: Search class references")
    return
  elseif getline('.') =~ '\<function\s\+\%' . cnum . 'c'
    call eclim#util#EchoInfo("TODO: Search function references")
    return
  elseif getline('.') =~ "\\<define\\s*(['\"]\\%" . cnum . "c"
    call eclim#util#EchoInfo("TODO: Search constant references")
    return
  "elseif getline('.') =~ '\<var\s\+[$]\?\%' . cnum . 'c'
  "  call eclim#util#EchoInfo("TODO: Search var references")
  "  return
  endif

  call eclim#php#search#FindDefinition()

endfunction " }}}

" CommandCompletePhpSearch(argLead, cmdLine, cursorPos) {{{
" Custom command completion for PhpSearch
function! eclim#php#search#CommandCompletePhpSearch (argLead, cmdLine, cursorPos)
  let cmdLine = strpart(a:cmdLine, 0, a:cursorPos)
  let cmdTail = strpart(a:cmdLine, a:cursorPos)
  let argLead = substitute(a:argLead, cmdTail . '$', '', '')
  if cmdLine =~ '-s\s\+[a-z]*$'
    let scopes = deepcopy(s:scopes)
    call filter(scopes, 'v:val =~ "^' . argLead . '"')
    return scopes
  elseif cmdLine =~ '-t\s\+[a-z]*$'
    let types = deepcopy(s:types)
    call filter(types, 'v:val =~ "^' . argLead . '"')
    return types
  elseif cmdLine =~ '\s\+[-]\?$'
    let options = deepcopy(s:options)
    let index = 0
    for option in options
      if a:cmdLine =~ option
        call remove(options, index)
      else
        let index += 1
      endif
    endfor
    return options
  endif
  return []
endfunction " }}}

" vim:ft=vim:fdm=marker
