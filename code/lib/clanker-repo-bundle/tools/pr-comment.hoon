/<  tools  /lib/tools.hoon
::  pr_comment: a comment on a pull request's thread, posted through the
::  ship's GitHub proxy under the account it holds. Public, and under
::  the ship owner's name: what is posted is the owner's word.
::
!:
=<  ^-  tool:tools
    |%
++  name  'pr_comment'
++  description
  '''
  Post a comment on a pull request's conversation on GitHub. number is
  the PR number on this repository; body is the comment as GitHub
  markdown. The comment is public and appears under the ship owner's
  GitHub account. Returns the comment's URL.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['number' [%number 'the pull request number']]
      ['body' [%string 'the comment, GitHub markdown']]
  ==
++  required  ~['number' 'body']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  num=(unit @ud)  (bind (deg /number so-loose:tools) |=(t=@t (fall (rush t dem) 0)))
  ?:  |(?=(~ num) =(0 u.num))  (pure:m [%error 'number must be a pull request number'])
  =/  body=@t  (fall (deg /body so:dejs:format) '')
  ?:  =('' body)  (pure:m [%error 'body must not be empty'])
  ;<  cfg=(each json @t)  bind:m  repo-config:tools
  ?:  ?=(%| -.cfg)  (pure:m [%error p.cfg])
  =/  repo=(each @t @t)  (github-repo:tools p.cfg)
  ?:  ?=(%| -.repo)  (pure:m [%error p.repo])
  =/  pax=@t  (crip "/repos/{(trip p.repo)}/issues/{(a-co:co u.num)}/comments")
  ;<  res=(each @t @t)  bind:m
    (github-call:tools p.cfg 'POST' pax '' `(pairs:enjs:format ~[['body' s+body]]))
  ?:  ?=(%| -.res)  (pure:m [%error p.res])
  =/  made=json  (fall (de:json:html p.res) *json)
  =/  url=tape
    ?.  ?=([%o *] made)  ""
    =/  v  (~(get by p.made) 'html_url')
    ?:(?=([~ %s *] v) (trip p.u.v) "")
  (pure:m [%text (crip "posted on PR #{(a-co:co u.num)}: {url}")])
--
|%
--
