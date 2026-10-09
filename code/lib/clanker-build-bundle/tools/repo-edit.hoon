/<  tools  /lib/tools.hoon
::  repo_edit: an exact-string edit of one text file in the repository's
::  working tree. old_string must occur exactly once (or replace_all).
::
!:
=<  ^-  tool:tools
    |%
++  name  'repo_edit'
++  description
  '''
  Edit a text file in the repository's working tree by exact string
  replacement: old_string is replaced by new_string. old_string must match
  exactly once, including whitespace and indentation (set replace_all to
  change every occurrence). path is relative to the repo root. Read the
  file first (repo_read) so the match is exact. This changes the checkout
  only; use repo_git to stage, commit and push.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the repo root']]
      ['old_string' [%string 'the exact text to replace']]
      ['new_string' [%string 'the replacement text']]
      ['replace_all' [%boolean 'replace every occurrence (default: false, exactly one match required)']]
  ==
++  required  ~['path' 'old_string' 'new_string']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)  (deg /path so:dejs:format)
  =/  old=(unit @t)  (deg /'old_string' so:dejs:format)
  =/  new=(unit @t)  (deg /'new_string' so:dejs:format)
  =/  all=?  (fall (deg /'replace_all' bo:dejs:format) %.n)
  ?~  rel  (pure:m [%error 'Missing required argument: path'])
  ?~  old  (pure:m [%error 'Missing required argument: old_string'])
  ?~  new  (pure:m [%error 'Missing required argument: new_string'])
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  full=(each path @t)  (repo-path:tools p.root u.rel)
  ?:  ?=(%| -.full)  (pure:m [%error p.full])
  ?:  =(p.root p.full)  (pure:m [%error 'path names the repo root, not a file'])
  ;<  txt=(unit @t)  bind:m  (read-text-at:tools p.full)
  ?~  txt  (pure:m [%error (crip "No such text file in the repo: {(trip u.rel)}")])
  =/  res=(each tape @tas)  (tape-replace:tools (trip u.txt) (trip u.old) (trip u.new) all)
  ?:  ?=(%| -.res)
    %-  pure:m
    :-  %error
    ?+  p.res  'edit failed'
      %empty-search  'old_string must not be empty'
      %not-found     (crip "old_string not found in {(trip u.rel)}")
      %not-unique    (crip "old_string occurs more than once in {(trip u.rel)}; include more context, or set replace_all")
    ==
  ;<  err=(unit @t)  bind:m  (write-text-at:tools p.root p.full (crip p.res))
  ?^  err  (pure:m [%error (crip "write failed: {(trip u.err)}")])
  (pure:m [%text (crip "Edited {(trip u.rel)} in the working tree; not yet committed.")])
--
|%
--
