/<  tools  /lib/tools.hoon
::  repo_deploy: make the repository's working tree live, the way this
::  repository deploys. The clanker's config.json "deploy" (copied there
::  by the forge from the repo's config) says which:
::
::    {"kind": "version", "file": "code/version.json"}
::      a /desk follows this tree's code and deploys when that file's
::      number rises: the deploy is the bump
::    {"kind": "clay", "desk": "grubbery", "dir": "desk"}
::      the tree's <dir> is a Clay desk (the kernel): every text file
::      under it that differs from what Clay holds is written, as one
::      Clay commit, the way a Unix |commit does. Files Clay has that
::      the tree lacks are left alone.
::
=>  |%
    ::  +clay-path: "a/b/foo.hoon" as Clay spells it: /a/b/foo/hoon
    ++  clay-path
      |=  rel=path
      ^-  (unit path)
      ?~  rel  ~
      =/  name=tape  (trip (rear rel))
      =/  r=tape  (flop name)
      =/  dot=(unit @ud)  (find "." r)
      ?~  dot  ~
      =/  ext=@ta   (crip (flop (scag u.dot r)))
      =/  stem=@ta  (crip (flop (slag +(u.dot) r)))
      ?:  |(=('' ext) =('' stem))  ~
      `(welp (snip `path`rel) ~[stem ext])
    --
!:
^-  tool:tools
|%
++  name  'repo_deploy'
++  description
  '''
  Make the repository's working tree live, the way this repository
  deploys (its deploy config): for a tree a desk follows, bump its
  code/version.json; for the kernel, commit the tree's desk into the
  Clay desk. Run it after a commit, never on uncommitted work. The
  deploy reloads the code this clanker runs on, so your turn may be
  interrupted and resumed. Returns what was deployed.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  cfg=(each json @t)  bind:m  repo-config:tools
  ?:  ?=(%| -.cfg)  (pure:m [%error p.cfg])
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  dep=json  ?.(?=([%o *] p.cfg) ~ (fall (~(get by p.p.cfg) 'deploy') ~))
  ?.  ?=([%o *] dep)
    (pure:m [%error 'this repository has no deploy config (the forge sets one from the shell\'s stock list)'])
  =/  js  |=(k=@t ^-(@t =/(v (~(get by p.dep) k) ?:(?=([~ %s *] v) p.u.v ''))))
  =/  kind=@t  (js 'kind')
  ::  === version: bump the followed file ===
  ?:  =('version' kind)
    =/  file=@t  =/(f=@t (js 'file') ?:(=('' f) 'code/version.json' f))
    =/  full=(each path @t)  (repo-path:tools p.root file)
    ?:  ?=(%| -.full)  (pure:m [%error p.full])
    ;<  txt=(unit @t)  bind:m  (read-text-at:tools p.full)
    ?~  txt  (pure:m [%error (crip "no {(trip file)} in the tree to bump")])
    =/  jon=(unit json)  (de:json:html u.txt)
    =/  cur=(unit @ud)
      ?.  ?=([~ %o *] jon)  ~
      =/  v  (~(get by p.u.jon) 'version')
      ?.  ?=([~ %n *] v)  ~
      (rush p.u.v dem)
    ?~  cur  (pure:m [%error (crip "{(trip file)} is not \{\"version\": N}")])
    =/  next=@ud  +(u.cur)
    =/  out=@t  (crip "\{\"version\": {(a-co:co next)}}\0a")
    ;<  err=(unit @t)  bind:m  (write-text-at:tools p.root p.full out)
    ?^  err  (pure:m [%error (crip "write failed: {(trip u.err)}")])
    (pure:m [%text (crip "Deployed: {(trip file)} {(a-co:co u.cur)} -> {(a-co:co next)}. The following desk re-syncs the tree and reloads its apps.")])
  ::  === clay: commit the tree's desk dir into a Clay desk ===
  ?.  =('clay' kind)  (pure:m [%error (crip "unknown deploy kind: {(trip kind)}")])
  =/  desk=@t  (js 'desk')
  =/  dir=@t   (js 'dir')
  ?:  =('' desk)  (pure:m [%error 'clay deploy needs a desk name'])
  =/  dek=@tas  (crip (trip desk))
  =/  subdir=(each path @t)  (rel-path:tools dir)
  ?:  ?=(%| -.subdir)  (pure:m [%error p.subdir])
  =/  base=path  (weld p.root p.subdir)
  ;<  bv=view:nexus  bind:m  (peek:io [%& %| base] ~)
  ?.  ?=([%ball *] bv)  (pure:m [%error (crip "no {(trip dir)}/ in the tree")])
  ::  a Clay desk has a sys.kelvin at its root; refuse anything else so a
  ::  partial or wrong tree never lands on the kernel
  ?.  ?&(?=(^ fil.ball.bv) (~(has by contents.u.fil.ball.bv) %'sys.kelvin'))
    (pure:m [%error (crip "{(trip dir)}/ is not a desk (no sys.kelvin); refusing to deploy")])
  =/  texts=(list [p=path t=@t])  (walk-texts:tools ball.bv /)
  ;<  initial=cass:clay  bind:m  (clay-case:io dek)
  ::  what differs from Clay: a missing file, or one whose stored noun
  ::  does not read back as the tree's text. Text marks store the cord
  ::  (hoon, js, css, html, svg); md and txt store a wain, joined back
  ::  with its newlines; the few marks whose noun is neither (json,
  ::  bill, kelvin, docket) always go in, and Clay drops a write that
  ::  changes nothing
  ;<  files=(list [path (unit mime)])  bind:m
    =/  mf  (fiber:fiber:nexus ,(list [path (unit mime)]))
    =|  acc=(list [path (unit mime)])
    |-  ^-  form:mf
    ?~  texts  (pure:mf (flop acc))
    =/  cp=(unit path)  (clay-path p.i.texts)
    ?~  cp  $(texts t.texts)
    ;<  has=?  bind:mf  (clay-exists:io dek u.cp)
    ;<  same=?  bind:mf
      =/  ms  (fiber:fiber:nexus ,?)
      ?.  has  (pure:ms %.n)
      ;<  cur=*  bind:ms  (clay-read:io dek u.cp)
      ?:  ?=(@ cur)  (pure:ms =(cur t.i.texts))
      =/  lines=(unit wain)  (mole |.(;;(wain cur)))
      ?~  lines  (pure:ms %.n)
      (pure:ms =((of-wain:format u.lines) t.i.texts))
    ?:  same  $(texts t.texts)
    =/  name=@ta  (rear p.i.texts)
    =/  =mime  [(mite-of:tools name) (as-octs:mimes:html t.i.texts)]
    $(texts t.texts, acc [[u.cp `mime] acc])
  ?~  files
    (pure:m [%text (crip "Nothing to deploy: Clay desk %{(trip desk)} already matches {(trip dir)}/ (at {(a-co:co ud.initial)}).")])
  ;<  ~  bind:m  (clay-info:io dek files)
  ::  the commit lands on a later event: wait for the revision to move
  ::  (a write that changed nothing never moves it; ten seconds is that)
  ;<  final=cass:clay  bind:m
    =/  mc  (fiber:fiber:nexus ,cass:clay)
    =|  tries=@ud
    |-  ^-  form:mc
    ;<  now=cass:clay  bind:mc  (clay-case:io dek)
    ?:  |((gth ud.now ud.initial) (gte tries 10))  (pure:mc now)
    ;<  ~  bind:mc  (sleep:io ~s1)
    $(tries +(tries))
  ::  (the ?~ above narrowed files to a cell; scag wants the list type)
  =/  all=(list [path (unit mime)])  files
  =/  listed=tape
    %-  zing
    %+  turn  (scag 40 all)
    |=([p=path *] "\0a  {(spud p)}")
  =/  more=tape  ?:((gth (lent all) 40) "\0a  ... and {(a-co:co (sub (lent all) 40))} more" "")
  %-  pure:m
  :-  %text
  %-  crip
  "Deployed {(a-co:co (lent files))} file(s) into Clay desk %{(trip desk)}: {(a-co:co ud.initial)} -> {(a-co:co ud.final)}.{listed}{more}"
--
