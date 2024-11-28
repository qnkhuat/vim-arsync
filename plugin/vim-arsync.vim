" Vim plugin to handle async rsync synchronisation between hosts
" Title: vim-arsync
" Author: Ken Hasselmann
" Date: 08/2019
" License: MIT

function! LoadConf()
  let l:conf_dict = {}
  let l:file_exists = filereadable('.vim-arsync')

  if l:file_exists > 0
    let l:conf_options = readfile('.vim-arsync')
    for i in l:conf_options
      let l:var_name = substitute(i[0:stridx(i, ' ')], '^\s*\(.\{-}\)\s*$', '\1', '')
      if l:var_name == 'ignore_path'
        let l:var_value = eval(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''))
        " echo substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', '')
      elseif l:var_name == 'remote_passwd'
        " Do not escape characters in passwords.
        let l:var_value = substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', '')
      else
        let l:var_value = escape(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''), '%#!')
      endif
      let l:conf_dict[l:var_name] = l:var_value
    endfor
  endif
  if !has_key(l:conf_dict, "local_path")
    let l:conf_dict['local_path'] = getcwd()
  endif
  if !has_key(l:conf_dict, "remote_port")
    let l:conf_dict['remote_port'] = 22
  endif
  if !has_key(l:conf_dict, "remote_or_local")
    let l:conf_dict['remote_or_local'] = "remote"
  endif
  if !has_key(l:conf_dict, "local_options")
    let l:conf_dict['local_options'] = "-var"
  endif
  if !has_key(l:conf_dict, "remote_options")
    let l:conf_dict['remote_options'] = "-vuazr"
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

function! ShowConf()
  let l:conf_dict = LoadConf()
  echo l:conf_dict
  echom string(getqflist())
endfunction

function! ARsync(direction)
  let l:conf_dict = LoadConf()
  let l:cmd = l:conf_dict['custom_command']
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
        autocmd BufWritePost,FileWritePost * call timer_start(g:sleep_time, { -> execute("call ARsync('up')", "")})
      else
        autocmd BufWritePost,FileWritePost * ARsyncUp
      endif
      " echo 'Setting up auto sync to remote'
    endif
  endif
endfunction

if !executable('rsync')
  echoerr 'You need to install rsync to be able to use the vim-arsync plugin'
  finish
endif

command! ARsyncUp call ARsync('up')
command! ARsyncUpDelete call ARsync('upDelete')
command! ARsyncDown call ARsync('down')
command! ARshowConf call ShowConf()

augroup vimarsync
  autocmd!
  autocmd VimEnter * call AutoSync()
  autocmd DirChanged * call AutoSync()
augroup END
