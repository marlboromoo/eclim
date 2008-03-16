" Author:  Eric Van Dewoestine
" Version: $Revision$
"
" Description: {{{
"   Functions for working with version control systems.
"
" License:
"
" Copyright (c) 2005 - 2008
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

runtime autoload/eclim/vcs/util.vim

" Global Variables {{{
  if !exists('g:EclimVcsLogMaxEntries')
    let g:EclimVcsLogMaxEntries = 50
  endif
" }}}

" Annotate([revision]) {{{
function! eclim#vcs#command#Annotate (...)
  if exists('b:vcs_annotations')
    call s:AnnotateOff()
    return
  endif

  let path = exists('b:vcs_props') ? b:vcs_props.path : expand('%:p')
  let revision = len(a:000) > 0 ? a:000[0] : ''
  let key = 'annotate_' . path . '_' . revision
  let cached = eclim#cache#Get(key)
  if has_key(cached, 'content')
    let annotations = cached.content
  else
    let dir = fnamemodify(path, ':h')
    let cwd = getcwd()
    if isdirectory(dir)
      exec 'lcd ' . dir
    endif
    try
      let Annotate = eclim#vcs#util#GetVcsFunction('GetAnnotations')
      if type(Annotate) != 2
        call eclim#util#EchoError('Current file is not under cvs or svn version control.')
        return
      endif
      let annotations = Annotate(revision)
      call eclim#cache#Set(key, annotations,
        \ {'path': path, 'revision': revision})
    finally
      exec 'lcd ' . cwd
    endtry
  endif

  call s:ApplyAnnotations(annotations)
endfunction " }}}

" ChangeSet(path, revision) {{{
" Opens a buffer with change set info for the supplied revision.
function! eclim#vcs#command#ChangeSet (path, revision)
  if a:path == ''
    call eclim#util#EchoError('File is not under version control.')
    return
  endif

  let path = substitute(a:path, '\', '/', 'g')
  let revision = a:revision
  if revision == ''
    let revision = eclim#vcs#util#GetRevision(path)
    if type(revision) != 1 && revision == 0
      call eclim#util#Echo('Unable to determine file revision.')
      return
    endif
  endif

  let key = 'changeset_' . path . '_' . revision
  let cached = eclim#cache#Get(key)
  if has_key(cached, 'content')
    let info = {'changeset': cached.content, 'props': cached.metadata.props}
  else
    let cwd = getcwd()
    let dir = fnamemodify(path, ':h')
    if isdirectory(dir)
      exec 'lcd ' . dir
    endif
    try
      let ChangeSet = eclim#vcs#util#GetVcsFunction('ChangeSet')
      if type(ChangeSet) != 2
        return
      endif
      let info = ChangeSet(revision)
    finally
      exec 'lcd ' . cwd
    endtry
    let info.props = has_key(info, 'props') ? info.props : {}
    let info.props.view = 'changeset'
    let info.props.path = path
    let info.props.revision = revision
    call eclim#cache#Set(key, info.changeset,
      \ {'path': path, 'revision': revision, 'props': info.props})
  endif

  call s:TempWindow(info.changeset)
  call s:LogSyntax()
  call s:LogMappings()

  let b:vcs_props = info.props
  exec 'lcd ' . escape(info.props.root_dir, ' ')

  call s:HistoryPush('eclim#vcs#command#ChangeSet', [path, a:revision])
endfunction " }}}

" Diff(path, revision) {{{
" Diffs the current file against the current or supplied revision.
function! eclim#vcs#command#Diff (path, revision)
  if a:path == ''
    call eclim#util#EchoError('File is not under version control.')
    return
  endif

  let path = substitute(a:path, '\', '/', 'g')
  let revision = a:revision
  if revision == ''
    let revision = eclim#vcs#util#GetRevision(path)
    if revision == ''
      call eclim#util#Echo('Unable to determine file revision.')
      return
    endif
  endif

  let filename = expand('%:p')
  let buf1 = bufnr('%')

  call eclim#vcs#command#ViewFileRevision(path, revision, 'bel vertical split')
  diffthis

  let b:filename = filename
  augroup vcs_diff
    autocmd! BufUnload <buffer>
    call eclim#util#GoToBufferWindowRegister(b:filename)
    autocmd BufUnload <buffer> diffoff
  augroup END

  exec bufwinnr(buf1) . 'winc w'
  diffthis
endfunction " }}}

" Info() {{{
" Retrieves and echos info on the current file.
function eclim#vcs#command#Info ()
  let cwd = getcwd()
  let dir = expand('%:p:h')
  exec 'lcd ' . dir
  try
    let Info = eclim#vcs#util#GetVcsFunction('Info')
    if type(Info) == 2
      call Info()
    endif
  finally
    exec 'lcd ' . cwd
  endtry
endfunction " }}}

" ListDir(path) {{{
" Opens a buffer with a directory listing of versioned files.
function! eclim#vcs#command#ListDir (path)
  let cwd = getcwd()
  let path = substitute(a:path, '\', '/', 'g')
  if isdirectory(path)
    exec 'lcd ' . path
  endif
  try
    let ListDir = eclim#vcs#util#GetVcsFunction('ListDir')
    if type(ListDir) != 2
      return
    endif
    let info = ListDir(path)
  finally
    exec 'lcd ' . cwd
  endtry

  call s:TempWindow(info.list)
  call s:LogSyntax()
  call s:LogMappings()

  let b:vcs_props = info.props
  let b:vcs_props.view = 'dir'
  let b:vcs_props.path = path
  exec 'lcd ' . escape(info.props.root_dir, ' ')

  call s:HistoryPush('eclim#vcs#command#ListDir', [path])
endfunction " }}}

" Log(path) {{{
" Opens a buffer with the contents of the log for the supplied url.
function! eclim#vcs#command#Log (path)
  if a:path == ''
    call eclim#util#EchoError('File is not under version control.')
    return
  endif

  let path = substitute(a:path, '\', '/', 'g')
  let key = 'log_' . path . '_' . g:EclimVcsLogMaxEntries
  let cached = eclim#cache#Get(key, function('eclim#vcs#util#IsCacheValid'))
  if has_key(cached, 'content')
    let info = {'log': cached.content, 'props': cached.metadata.props}
  else
    let cwd = getcwd()
    let dir = fnamemodify(path, ':h')
    if isdirectory(dir)
      exec 'lcd ' . dir
    endif
    try
      let Log = eclim#vcs#util#GetVcsFunction('Log')
      if type(Log) != 2
        return
      endif
      let info = Log(path)
    finally
      exec 'lcd ' . cwd
    endtry
    if g:EclimVcsLogMaxEntries > 0 && len(info.log) == g:EclimVcsLogMaxEntries
      call add(info.log, '------------------------------------------')
      call add(info.log, 'Note: entries limited to ' . g:EclimVcsLogMaxEntries . '.')
      call add(info.log, '      let g:EclimVcsLogMaxEntries = ' . g:EclimVcsLogMaxEntries)
    endif
    let info.props = has_key(info, 'props') ? info.props : {}
    let info.props.view = 'log'
    let info.props.path = path
    call eclim#cache#Set(key, info.log, {
      \  'path': path,
      \  'revision': eclim#vcs#util#GetRevision(path),
      \  'props': info.props
      \ })
  endif

  call s:TempWindow(info.log)
  call s:LogSyntax()
  call s:LogMappings()

  let b:vcs_props = info.props
  exec 'lcd ' . escape(info.props.root_dir, ' ')

  call s:HistoryPush('eclim#vcs#command#Log', [path])
endfunction " }}}

" ViewFileRevision(path, revision, open_cmd) {{{
" Open a read only view for the revision of the supplied version file.
function! eclim#vcs#command#ViewFileRevision (path, revision, open_cmd)
  if a:path == ''
    call eclim#util#EchoError('File is not under version control.')
    return
  endif

  let path = substitute(a:path, '\', '/', 'g')
  let revision = a:revision
  if revision == ''
    let revision = eclim#vcs#util#GetRevision(path)
    if revision == ''
      call eclim#util#Echo('Unable to determine file revision.')
      return
    endif
  endif

  let props = exists('b:vcs_props') ? b:vcs_props : {}

  if exists('b:filename')
    call eclim#util#GoToBufferWindow(b:filename)
  endif
  let vcs_file = 'vcs_' . revision . '_' . fnamemodify(path, ':t')

  "let saved = &eventignore
  "let &eventignore = 'BufNewFile' " doing this causes issues for php files
  "try
    let open_cmd = a:open_cmd != '' ? a:open_cmd : 'split'
    if has('win32') || has('win64')
      let vcs_file = substitute(vcs_file, ':', '_', 'g')
    endif
    call eclim#util#GoToBufferWindowOrOpen(vcs_file, open_cmd)
  "finally
  "  let &eventignore = saved
  "endtry

  setlocal noreadonly
  setlocal modifiable
  let saved = @"
  silent 1,$delete
  let @" = saved

  let b:vcs_props = copy(props)
  let b:vcs_props.view = 'cat'

  " load in content
  let key = 'cat_' . path . '_' . revision
  let cached = eclim#cache#Get(key)
  if has_key(cached, 'content')
    let lines = cached.content
  else
    let cwd = getcwd()
    let dir = fnamemodify(path, ':h')
    if has_key(props, 'root_dir')
      let dir = b:vcs_props.root_dir . '/' . dir
    endif
    if isdirectory(dir)
      exec 'lcd ' . dir
    endif
    try
      let ViewFileRevision = eclim#vcs#util#GetVcsFunction('ViewFileRevision')
      if type(ViewFileRevision) != 2
        return
      endif
      let lines = ViewFileRevision(path, revision)
      call eclim#cache#Set(key, lines, {'path': path, 'revision': revision})
    finally
      exec 'lcd ' . cwd
    endtry
  endif

  call append(1, lines)
  silent 1,1delete
  call cursor(1, 1)

  setlocal nomodified
  setlocal readonly
  setlocal nomodifiable
  setlocal noswapfile
  setlocal nobuflisted
  setlocal buftype=nofile
  setlocal bufhidden=delete
  doautocmd BufReadPost
endfunction " }}}

" s:ApplyAnnotations(annotations) {{{
function! s:ApplyAnnotations (annotations)
  let defined = eclim#display#signs#GetDefined()
  let index = 1
  for annotation in a:annotations
    let user = substitute(annotation, '^.\{-})\s\+\(.*\)', '\1', '')
    let user_abbrv = user[:1]
    if index(defined, user) == -1
      call eclim#display#signs#Define(user, user_abbrv, g:EclimInfoHighlight)
      call add(defined, user_abbrv)
    endif
    call eclim#display#signs#Place(user, index)
    let index += 1
  endfor
  let b:vcs_annotations = a:annotations

  augroup vcs_annotate
    autocmd!
    autocmd CursorHold <buffer> call <SID>AnnotateInfo()
  augroup END
endfunction " }}}

" s:AnnotateInfo() {{{
function! s:AnnotateInfo ()
  if exists('b:vcs_annotations') && len(b:vcs_annotations) >= line('.')
    call eclim#util#WideMessage('echo', b:vcs_annotations[line('.') - 1])
  endif
endfunction " }}}

" s:AnnotateOff() {{{
function! s:AnnotateOff ()
  if exists('b:vcs_annotations')
    let defined = eclim#display#signs#GetDefined()
    for annotation in b:vcs_annotations
      let user = substitute(annotation, '^.*)\s\+\(.*\)', '\1', '')
      if index(defined, user) != -1
        let signs = eclim#display#signs#GetExisting(user)
        for sign in signs
          call eclim#display#signs#Unplace(sign.id)
        endfor
        call eclim#display#signs#Undefine(user)
        call remove(defined, index(defined, user))
      endif
    endfor
    unlet b:vcs_annotations
  endif
  augroup vcs_annotate
    autocmd!
  augroup END
endfunction " }}}

" s:FollowLink () {{{
function! s:FollowLink ()
  let line = getline('.')
  let link = substitute(
    \ getline('.'), '.*|\(.\{-}\%' . col('.') . 'c.\{-}\)|.*', '\1', '')
  if link == line
    return
  endif

  let view = exists('b:vcs_props') && has_key(b:vcs_props, 'view') ?
    \ b:vcs_props.view : ''

  " link to folder
  if line('.') == 1
    let line = getline('.')
    let path = substitute(
      \ line, '.\{-}/\(.\{-}\%' . col('.') . 'c.\{-}\)|.*', '\1', '')
    if path == line
      let path = ''
    else
      let path = substitute(path, '| / |', '/', 'g')
      let path = substitute(path, '\(^\s\+\||\)', '', 'g')
    endif

    call eclim#vcs#command#ListDir(path)

  " link to file or dir in directory listing view.
  elseif view == 'dir'
    let line = getline(1)

    let path = ''
    if line != '/'
      let path = substitute(line, '.\{-}/ |\?\(.*\)', '\1', '')
      let path = substitute(path, '\(| / |\|| / \)', '/', 'g')
      let path = substitute(path, '\(^\s\+\||\)', '', 'g')
      let path .= '/'
    endif
    let path .= link

    if path =~ '/$'
      call eclim#vcs#command#ListDir(path)
    else
      call eclim#vcs#command#Log(path)
    endif

  " link to file or dir in change set view.
  elseif link !~ '^#' && view == 'changeset'
    let revision = b:vcs_props.revision
    if link == 'M'
      let file = substitute(line, '\s*|M|\s*|\(.\{-}\)|.*', '\1', '')
      let r2 = eclim#vcs#util#GetPreviousRevision(file, revision)
      call eclim#vcs#command#ViewFileRevision(file, revision, '')
      let buf1 = bufnr('%')

      call eclim#vcs#command#ViewFileRevision(file, r2, 'bel vertical split')
      diffthis
      exec bufwinnr(buf1) . 'winc w'
      diffthis
    else
      call eclim#vcs#command#Log(link)
    endif

  " link to view a change set
  elseif link =~ '^[0-9][0-9a-f.:]\+$'
    let file = s:GetBreadcrumbPath()
    call eclim#vcs#command#ChangeSet(b:vcs_props.path, link)

  " link to view / annotate a file
  elseif link == 'view' || link == 'annotate'
    let file = s:GetBreadcrumbPath()
    let revision = substitute(getline('.'), 'Revision: \(.\{-}\) .*', '\1', '')
    let revision = substitute(revision, '\(^|\||$\)', '', 'g')

    call eclim#vcs#command#ViewFileRevision(file, revision, '')
    if link == 'annotate'
      call eclim#vcs#command#Annotate(revision)
    endif

  " link to diff one version against previous
  elseif link =~ '^previous .*$'
    let file = s:GetBreadcrumbPath()
    let r1 = substitute(getline(line('.') - 2), 'Revision: \(.\{-}\) .*', '\1', '')
    let r1 = substitute(r1, '\(^|\||$\)', '', 'g')
    let r2 = substitute(link, 'previous \(.*\)', '\1', '')

    call eclim#vcs#command#ViewFileRevision(file, r1, '')
    let buf1 = bufnr('%')
    call eclim#vcs#command#ViewFileRevision(file, r2, 'bel vertical split')
    diffthis
    exec bufwinnr(buf1) . 'winc w'
    diffthis

  " link to diff against working copy
  elseif link == 'working copy'
    let file = s:GetBreadcrumbPath()
    let revision = substitute(
      \ getline(line('.') - 2), 'Revision: |\?\([0-9.]\+\)|\?.*', '\1', '')

    let filename = b:filename
    call eclim#vcs#command#ViewFileRevision(file, revision, 'bel vertical split')
    diffthis

    let b:filename = filename
    augroup vcs_diff
      autocmd! BufUnload <buffer>
      call eclim#util#GoToBufferWindowRegister(b:filename)
      autocmd BufUnload <buffer> diffoff
    augroup END

    call eclim#util#GoToBufferWindow(filename)
    diffthis

  " link to bug / feature report
  elseif link =~ '^#\d\+$'
    let cwd = getcwd()
    let dir = fnamemodify(b:filename, ':h')
    exec 'lcd ' . dir
    try
      let url = eclim#project#util#GetProjectSetting('org.eclim.project.vcs.tracker')
    finally
      exec 'lcd ' . cwd
    endtry

    if url == '0'
      return
    endif

    if url == ''
      call eclim#util#EchoWarning(
        \ "Link to bug report / feature request requires project setting " .
        \ "'org.eclim.project.vcs.tracker'.")
      return
    elseif type(url) == 0 && url == 0
      return
    endif

    let url = substitute(url, '<id>', link[1:], 'g')
    call eclim#web#OpenUrl(url)
  endif
endfunction " }}}

" s:GetBreadcrumbPath() {{{
function! s:GetBreadcrumbPath ()
  let path = substitute(getline(1), ' / ', '/', 'g')
  let path = substitute(path, '.\{-}/\(.*\)', '\1', '')
  let path = substitute(path, '^|', '', 'g')
  let path = substitute(path, '\(|/|\||/\||\)', '/', 'g')
  return path
endfunction " }}}

" s:HistoryPop() {{{
function! s:HistoryPop ()
  if exists('w:vcs_history') && len(w:vcs_history) > 1
    call remove(w:vcs_history, -1) " remove current page entry
    exec w:vcs_history[-1]
    call remove(w:vcs_history, -1) " remove entry added by going back
  endif
endfunction " }}}

" s:HistoryPush(command) {{{
function! s:HistoryPush (name, args)
  if !exists('w:vcs_history')
    let w:vcs_history = []
  endif

  let command = 'call ' . a:name . '('
  let index = 0
  for arg in a:args
    if index != 0
      let command .= ', '
    endif
    let command .= '"' . arg . '"'
    let index += 1
  endfor
  let command .= ')'
  call add(w:vcs_history, command)
endfunction " }}}

" s:LogMappings() {{{
function! s:LogMappings ()
  nnoremap <silent> <buffer> <cr> :call <SID>FollowLink()<cr>
  nnoremap <silent> <buffer> <c-o> :call <SID>HistoryPop()<cr>
endfunction " }}}

" s:LogSyntax() {{{
function! s:LogSyntax ()
  set ft=vcs_log
  hi link VcsDivider Constant
  hi link VcsHeader Identifier
  hi link VcsLink Label
  syntax match VcsDivider /^-\+$/
  syntax match VcsLink /|\S.\{-}\S|/
  syntax match VcsHeader /^\(Revision\|Modified\|Diff\|Changed paths\):/
endfunction " }}}

" s:TempWindow (lines) {{{
function! s:TempWindow (lines)
  let filename = expand('%:p')
  if expand('%') == '[vcs_log]' && exists('b:filename')
    let filename = b:filename
  endif

  call eclim#util#TempWindow('[vcs_log]', a:lines)

  let b:filename = filename
  augroup eclim_temp_window
    autocmd! BufUnload <buffer>
    call eclim#util#GoToBufferWindowRegister(b:filename)
  augroup END
endfunction " }}}

" vim:ft=vim:fdm=marker