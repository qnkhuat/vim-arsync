" Vim plugin to handle async rsync synchronisation between hosts
" Title: vim-arsync
" Author: Ken Hasselmann
" Date: 08/2019
" License: MIT

function! LoadConf()
  let l:conf_dict = {}
  let l:file_exists = filereadable('.vim-arsync')
  "each line is key value pair, separte by space, line is joined by space from
  "1st space to end of line
  if l:file_exists
    let l:file = readfile('.vim-arsync')
    for l:line in l:file
      let l:line = substitute(l:line, '\s\+', ' ', 'g')
      let l:line = split(l:line, ' ')
      let l:conf_dict[l:line[0]] = join(l:line[1:], ' ')
    endfor
  else
    echoerr 'No .vim-arsync file found in current directory'
  endif
  return l:conf_dict
endfunction

function! JobHandler(job_id, data, event_type)
  " redraw | echom a:job_id . ' ' . a:event_type
  if a:event_type == 'stdout' || a:event_type == 'stderr'
    " redraw | echom string(a:data)
    if has_key(getqflist({'id' : g:qfid}), 'id')
      call setqflist([], 'a', {'id' : g:qfid, 'lines' : a:data})
    endif
  elseif a:event_type == 'exit'
    if a:data != 0
      copen
    endif
    if a:data == 0
      echo "vim-arsync success."
    endif
    " echom string(a:data)
  endif
endfunction

function! ARsync(direction)
  let l:conf_dict = LoadConf()
  if a:direction == 'down'
    let l:cmd = l:conf_dict['custom_command_down']
  else
    let l:cmd = l:conf_dict['custom_command_up']
  endif
  call setqflist([], ' ', {'title' : 'vim-arsync'})
  let g:qfid = getqflist({'id' : 0}).id
  let l:job_id = async#job#start(cmd, {
        \ 'on_stdout': function('JobHandler'),
        \ 'on_stderr': function('JobHandler'),
        \ 'on_exit': function('JobHandler'),
        \ })
endfunction

function! AutoSync()
  let l:conf_dict = LoadConf()
  if has_key(l:conf_dict, 'auto_sync_up')
    if l:conf_dict['auto_sync_up'] == 1
      if has_key(l:conf_dict, 'sleep_before_sync')
        let g:sleep_time = l:conf_dict['sleep_before_sync']*1000
        autocmd BufWritePost,FileWritePost * call timer_start(g:sleep_time, { -> execute("call ARsync()", "")})
      else
        autocmd BufWritePost,FileWritePost * ARsync
      endif
      " echo 'Setting up auto sync to remote'
    endif
  endif
endfunction

if !executable('rsync')
  echoerr 'You need to install rsync to be able to use the vim-arsync plugin'
  finish
endif

" load if .vim-arsync file exists
if filereadable('.vim-arsync')
  command! ARsyncUp call ARsync('up')
  command! ARsyncDown call ARsync('down')

  augroup vimarsync
    autocmd!
    autocmd VimEnter * call AutoSync()
    autocmd DirChanged * call AutoSync()
  augroup END
endif
