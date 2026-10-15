/<  tools  /lib/tools.hoon
::  repo_deploy: make the repository's working tree live, the way this
::  repository deploys. The clanker's config.json "deploy" (copied there
::  by the forge from the repo's config) says which:
::
::    {"kind": "version", "file": "code/version.json"}
::      a /desk follows this tree's code and deploys when that file's
::      number rises: the deploy is the bump
::    {"kind": "clay", "desk": "grubbery", "dir": "desk"}
::      the tree's <dir> is a Clay desk (the kernel): every file under
::      it whose content differs from what Clay holds is written, as
::      one Clay commit, the way a Unix |commit does. Files Clay has
::      that the tree lacks are left alone.
::
::  A deploy reloads the code this very fiber may run on, so it keeps
::  the commit tool's contract: the step and what it needs to finish
::  (the initial revision, the logs so far) are written to this run's
::  state BEFORE the write, and a restart lands at that step and only
::  finishes: reads the final revision, reports. Nothing is deployed
::  twice. The kernel's build output (dill's log stream) is collected
::  while the commit settles, so the answer says what compiled.
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
    ::  +same-as-clay: does the tree's text equal what Clay stores, the
    ::  stored noun compared against the text converted the way the mark
    ::  converts a mime: a cord as is, md/txt split into lines, json parsed
    ++  same-as-clay
      |=  [mark=@tas cur=* txt=@t]
      ^-  ?
      ?:  ?=(@ cur)  =(cur txt)
      ?:  ?=(?(%md %txt) mark)  =(cur (to-wain:format txt))
      ?.  =(%json mark)  %.n
      =/  parsed=(unit json)  (de:json:html txt)
      ?&(?=(^ parsed) =(cur u.parsed))
    ::  the kernel's log stream while the commit settles: the commit
    ::  tool's debounce, with this tool's wires
    +$  deploy-event
      $%  [%timeout ~]
          [%quiet count=@ud]
          [%log ~]
      ==
    ++  take-deploy-event
      =/  m  (fiber:fiber:nexus ,deploy-event)
      ^-  form:m
      |=  input:fiber:nexus
      :+  ~  q.state
      ?+  in  [%skip ~]
          ~  [%wait ~]
          [~ %poke * *]
        ?.  =([/ %timer-wake] p.sage.u.in)  [%skip ~]
        =/  wak=wire  !<(wire q.sage.u.in)
        ?+  wak  [%skip ~]
          [%deploy-timeout ~]   [%done %timeout ~]
          [%deploy-quiet @ ~]   [%done %quiet (slav %ud i.t.wak)]
        ==
          [~ %news [%dill %logs ~] *]
        [%done %log ~]
      ==
    ++  format-told
      |=  log=told:dill
      ^-  tape
      ?-  -.log
          %crud
        =/  lines=wall  (zing (turn (flop q.log) (cury wash [0 80])))
        "ERROR [{<p.log>}]:\0a{(zing (turn lines |=(l=tape "{l}\0a")))}"
          %talk
        =/  lines=wall  (zing (turn p.log (cury wash [0 80])))
        (zing (turn lines |=(l=tape "{l}\0a")))
          %text
        "{p.log}\0a"
      ==
    ++  collect-logs
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      |-
      ;<  ev=deploy-event  bind:m  take-deploy-event
      ?-    -.ev
          %timeout  (pure:m ~)
          %quiet
        ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
        =/  logs=(list json)
          (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
        ?.  =(count.ev (lent logs))  $
        (pure:m ~)
          %log
        ;<  dv=view:nexus  bind:m  (peek:io [%& %& /sys/dill %'logs.dill-told'] ~)
        =/  text=tape
          ?.  ?=([%file *] dv)  ""
          ?.  ?=(%dill-told name.p.sang.dv)  ""
          (format-told !<(told:dill (need-vase:tarball sang.dv)))
        ?:  =(~ text)  $
        ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
        =/  logs=(list json)
          (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
        =/  new-data=json  (~(put jo:json-utils data.st) /logs a+[s+(crip text) logs])
        =/  n=@ud  +((lent logs))
        ;<  ~  bind:m  (replace:io [tool.st args.st step.st new-data ~])
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /deploy-quiet/(scot %ud n) (add now ~s1))
        $
      ==
    ::  +finish-clay: the report, from the run's state alone: the desk,
    ::  the initial revision and the files written are in data; the
    ::  final revision is read now. A restart finishes here.
    ++  finish-clay
      |=  data=json
      =/  m  (fiber:fiber:nexus ,tool-result:tools)
      ^-  form:m
      ?.  ?=([%o *] data)  (pure:m [%error 'deploy state lost (stale run grub); run it again'])
      =/  deg  ~(deg jo:json-utils data)
      =/  desk=@t  (fall (deg /desk so:dejs:format) '')
      =/  initial=@ud  (fall (deg /initial-ud ni:dejs:format) 0)
      =/  count=@ud  (fall (deg /count ni:dejs:format) 0)
      =/  listed=(list @t)  (fall (deg /files (ar:dejs:format so:dejs:format)) ~)
      =/  logs=(list @t)  (fall (deg /logs (ar:dejs:format so:dejs:format)) ~)
      ?:  =('' desk)  (pure:m [%error 'deploy state incomplete; run it again'])
      ;<  final=cass:clay  bind:m  (clay-case:io (crip (trip desk)))
      =/  moved=?  (gth ud.final initial)
      =/  head=tape
        ?:  moved
          "Deployed {(a-co:co count)} file(s) into Clay desk %{(trip desk)}: revision {(a-co:co initial)} -> {(a-co:co ud.final)}."
        "Wrote {(a-co:co count)} file(s) to Clay desk %{(trip desk)}, but the revision stayed at {(a-co:co initial)}: Clay found no change in them (same content)."
      =/  files=tape  (zing (turn listed |=(f=@t "\0a  {(trip f)}")))
      =/  more=tape  ?:((gth count (lent listed)) "\0a  ... and {(a-co:co (sub count (lent listed)))} more" "")
      =/  build=tape
        ?~  logs  ""
        "\0a\0aBuild log:\0a{(roll (flop logs) |=([l=@t a=tape] (weld a (trip l))))}"
      (pure:m [%text (crip "{head}{files}{more}{build}")])
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
  interrupted and resumed; the result still arrives. Returns what was
  deployed, the revision before and after, and the build log.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ::  a restart mid-deploy: the write is done or in flight; only finish
  ?:  =(%deploying step.st)  (finish-clay data.st)
  ?:  =(%bumping step.st)
    =/  deg  ~(deg jo:json-utils data.st)
    =/  file=@t  (fall (deg /file so:dejs:format) 'code/version.json')
    =/  to=@ud  (fall (deg /to ni:dejs:format) 0)
    (pure:m [%text (crip "Deployed: {(trip file)} -> {(a-co:co to)} (this run was resumed after the reload it caused). The following desk re-syncs the tree and reloads its apps.")])
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
    ::  the step first: a reload between the write and the result must
    ::  not bump twice
    ;<  ~  bind:m
      (replace:io [tool.st args.st %bumping (pairs:enjs:format ~[['file' s+file] ['from' (numb:enjs:format u.cur)] ['to' (numb:enjs:format next)]]) ~])
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
  ::  what differs from Clay: a missing file, or stored content that is
  ::  not the tree's text (see +same-as-clay)
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
      (pure:ms (same-as-clay (rear u.cp) cur t.i.texts))
    ?:  same  $(texts t.texts)
    =/  name=@ta  (rear p.i.texts)
    =/  =mime  [(mite-of:tools name) (as-octs:mimes:html t.i.texts)]
    $(texts t.texts, acc [[u.cp `mime] acc])
  ?~  files
    (pure:m [%text (crip "Nothing to deploy: Clay desk %{(trip desk)} already matches {(trip dir)}/ (at revision {(a-co:co ud.initial)}).")])
  =/  all=(list [path (unit mime)])  files
  =/  listed=(list json)  (turn (scag 40 all) |=([p=path *] `json`s+(spat p)))
  =/  data=json
    %-  pairs:enjs:format
    :~  ['desk' s+desk]
        ['initial-ud' (numb:enjs:format ud.initial)]
        ['count' (numb:enjs:format (lent all))]
        ['files' a+listed]
        ['logs' a+~]
    ==
  ::  the step and everything the report needs, BEFORE the write
  ;<  ~  bind:m  (replace:io [tool.st args.st %deploying data ~])
  ;<  *  bind:m  (keep:io /dill/logs [%& %& /sys/dill %'logs.dill-told'] ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /deploy-timeout (add now ~s45))
  ;<  ~  bind:m  (clay-info:io dek all)
  ;<  ~  bind:m  collect-logs
  ;<  ~  bind:m  (drop:io /dill/logs [%& %& /sys/dill %'logs.dill-told'])
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  (finish-clay data.st)
--
