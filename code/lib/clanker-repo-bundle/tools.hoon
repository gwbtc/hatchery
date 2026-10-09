::  lib/tools for a REPO clanker's tools nexus: the shared tool types and
::  helpers every bundle carries, the clanker helpers (+clanker-up,
::  +rel-path, +reserved, +ensure-dirs), and at the bottom the repo ones:
::  +repo-root reads the working tree's absolute path from the clanker's
::  config.json ("repo"), +walk-files flattens a peeked subtree. The tree
::  itself is outside the clanker; the host's weir grants the peek.
::
|%
::  Tool execution result
::
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
      [%mime =mime]
  ==
::  Tool process state: args + step tag + step-specific data.
::
+$  tool-state
  $:  tool=@t
      args=(map @t json)
      step=@tas
      data=json
      update=(unit json)
  ==
::  Parameter schema for tool discovery (MCP, Claude API, etc.)
::
+$  parameter-type
  $?  %string
      %number
      %boolean
      %array
      %object
  ==
::
+$  parameter-def
  $:  type=parameter-type
      description=@t
  ==
::  Tool definition: everything needed to advertise + execute a tool.
::
+$  tool
  $_  ^?
  |%
  ++  name         *@t
  ++  description  *@t
  ++  parameters   *(map @t parameter-def)
  ++  required     *(list @t)
  ++  handler      *tool-handler
  --
::
+$  tool-handler  _*form:(fiber:fiber:nexus ,tool-result)
::  +so-loose: a lenient string decoder for a parameter typed %number.
::
++  so-loose
  |=  j=json
  ^-  @t
  ?+  j  (so:dejs:format j)
    [%n *]  p.j
  ==
::
++  mimes-to-bole
  |=  a=(axal (map @ta mime))
  ^-  bole:tarball
  =/  files=(map @ta [=bask:tarball gain=?])
    ?~  fil.a  ~
    %-  ~(run by u.fil.a)
    |=(=mime `[bask:tarball ?]`[[[/ %hoon] q.q.mime] %.y])
  =/  kids=(map @ta bole:tarball)
    %-  ~(urn by dir.a)
    |=([* kid=(axal (map @ta mime))] (mimes-to-bole kid))
  [`[~ ~ %.n files] kids]
::
++  seed-tools
  |=  srcs=(axal (map @ta mime))
  ^-  bole:tarball
  =/  lib-bole=bole:tarball  (mimes-to-bole srcs)
  =/  code-nex=bole:tarball  [`[`[/ %code] ~ %.n ~] (malt ~[[%lib lib-bole]])]
  [`[`[/ %tools] ~ %.n ~] (malt ~[[%code code-nex]])]
::
++  merge-boles
  |=  [base=bole:tarball over=bole:tarball]
  ^-  bole:tarball
  :-  ^-  (unit pulp:tarball)
      ?~  fil.over  fil.base
      ?~  fil.base  fil.over
      %-  some
      :^    ?~(neck.u.fil.over neck.u.fil.base neck.u.fil.over)
          ?~(weir.u.fil.over weir.u.fil.base weir.u.fil.over)
        gain.u.fil.over
      (~(uni by contents.u.fil.base) contents.u.fil.over)
  ^-  (map @ta bole:tarball)
  =/  keys=(set @ta)  (~(uni in ~(key by dir.base)) ~(key by dir.over))
  %-  ~(gas by *(map @ta bole:tarball))
  %+  turn  ~(tap in keys)
  |=  k=@ta
  ^-  [@ta bole:tarball]
  =/  b=(unit bole:tarball)  (~(get by dir.base) k)
  =/  o=(unit bole:tarball)  (~(get by dir.over) k)
  :-  k
  ?~  b  (need o)
  ?~  o  u.b
  (merge-boles u.b u.o)
::
++  strip-hoon
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".hoon" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
::
++  seg-to-name
  |=  s=@ta
  ^-  @t
  (crip (turn (trip s) |=(c=@tD ?:(=('-' c) '_' c))))
::
++  name-to-seg
  |=  t=tape
  ^-  @ta
  (crip (turn t |=(c=@tD ?:(=('_' c) '-' c))))
::
++  split-name
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  acc=(list tape)
  |-
  ?~  t  (flop [(flop cur) acc])
  ?:  ?&  =('_' i.t)
          ?=(^ t.t)
          =('_' i.t.t)
      ==
    $(t t.t.t, acc [(flop cur) acc], cur ~)
  $(t t.t, cur [i.t cur])
::
++  derive-name
  |=  [sub=path file=@ta]
  ^-  @t
  =/  segs=(list @ta)  (snoc sub (strip-hoon file))
  %-  crip
  %-  zing
  %+  join  "__"
  (turn segs |=(s=@ta (trip (seg-to-name s))))
::
++  name-to-place
  |=  name=@t
  ^-  [sub=path arm=@ta]
  =/  parts=(list tape)  (split-name (trip name))
  =/  segs=(list @ta)  (turn parts name-to-seg)
  ?~  segs  [~ %$]
  [(snip `(list @ta)`segs) (rear segs)]
::
++  glob-match
  |=  [pat=tape txt=tape]
  ^-  ?
  ?~  pat  =(txt ~)
  ?:  =(i.pat '*')
    ?|  (glob-match t.pat txt)
        ?&(?=(^ txt) (glob-match pat t.txt))
    ==
  ?~  txt  %.n
  ?&(=(i.pat i.txt) (glob-match t.pat t.txt))
::
++  parse-path
  |=  t=@t
  ^-  (each path @t)
  =/  pax=(unit path)  (rush t stap)
  ?~  pax
    [%| (crip "Invalid path: {(trip t)} (must start with /)")]
  [%& u.pax]
::
++  is-text-blot
  |=  name=@tas
  ^-  ?
  %-  ~(has in `(set @tas)`(sy ~[%json %txt %hoon %html %css %js %csv %xml %md %sig]))
  name
::
++  norm-mite
  |=  =mite
  ^-  ^mite
  ?.  ?=([@ ~] mite)  mite
  =/  t=tape  (trip i.mite)
  ?~  sl=(find "/" t)  mite
  ~[(crip (scag u.sl t)) (crip (slag +(u.sl) t))]
::
++  is-text-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?:  =('text' i.mite)  %.y
  ?.  =('application' i.mite)  %.n
  ?~  t.mite  %.n
  (~(has in (sy ~['json' 'xml' 'javascript' 'x-javascript' 'ecmascript'])) i.t.mite)
::
++  is-multimodal-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?|  =('image' i.mite)
      =([~['application' 'pdf']] mite)
  ==
::
++  mite-to-cord
  |=  =mite
  ^-  @t
  (crip (zing (join "/" (turn mite trip))))
::
++  render-mime
  |=  out=mime
  ^-  tool-result
  =.  p.out  (norm-mite p.out)
  ?:  (is-text-mime p.out)
    [%text (crip (trip q.q.out))]
  ?:  (is-multimodal-mime p.out)
    [%mime out]
  [%text (crip (trip q.q.out))]
::
++  render-grub-content
  |=  =view:nexus
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?>  ?=([%file *] view)
  ?:  ?=(%| -.q.sang.view)
    =/  =boom:tarball  p.q.sang.view
    =/  rendered=tape
      %-  zing
      %+  turn  (flop tang.boom)
      |=(=tank (weld ~(ram re tank) "\0a"))
    (pure:m [%error (crip "BOOM (mark %{(trip name.p.sang.view)})\0a{rendered}")])
  =/  =sage:tarball  (need-sage:tarball sang.view)
  =/  blot-text=@t
    (crip "[mark: {(spud (snoc path.p.sage name.p.sage))}]")
  ;<  result=tool-result  bind:m
    ?:  (is-text-blot name.p.sage)
      ?+  name.p.sage
        (pure:m [%text !<(@t q.sage)])
          %json  (pure:m [%text (en:json:html !<(json q.sage))])
          %txt   (pure:m [%text (of-wain:format !<(wain q.sage))])
          %hoon  (pure:m [%text !<(@t q.sage)])
      ==
    ?:  =(%mime name.p.sage)
      (pure:m (render-mime !<(mime q.sage)))
    ;<  convert=(unit tube:clay)  bind:m
      (get-tube:io [%& %| /code] [p.sage [/ %mime]])
    ?~  convert
      (pure:m [%error (crip "No conversion from {(trip name.p.sage)} to mime")])
    =/  out=mime  !<(mime (u.convert q.sage))
    (pure:m (render-mime out))
  ?:  ?=(%error -.result)  (pure:m result)
  ?:  ?=(%mime -.result)
    (pure:m [%mime mime.result])
  (pure:m [%text (crip "{(trip blot-text)}\0a{(trip text.result)}")])
::
++  tape-replace
  |=  [txt=tape old=tape new=tape all=?]
  ^-  (each tape @tas)
  =/  old-len=@ud  (lent old)
  ?:  =(0 old-len)  [%| %empty-search]
  =/  idx=(unit @ud)  (find old txt)
  ?~  idx  [%| %not-found]
  ?.  all
    =/  after=@ud  (add u.idx old-len)
    =/  rest=tape  (slag after txt)
    ?^  (find old rest)  [%| %not-unique]
    :-  %&
    :(weld (scag u.idx txt) new (slag after txt))
  =|  acc=tape
  =/  src=tape  txt
  |-
  =/  hit=(unit @ud)  (find old src)
  ?~  hit  [%& (weld acc src)]
  %=  $
    acc  :(weld acc (scag u.hit src) new)
    src  (slag (add u.hit old-len) src)
  ==
::
::  Clanker helpers. A tool runs inside <clanker>/tools/runs/<id>; the
::  clanker is the nearest ancestor whose neck is [/clanker %agent].
::
++  clanker-up
  =/  m  (fiber:fiber:nexus ,(unit @ud))
  ^-  form:m
  ;<  agent=road:tarball  bind:m
    (ancestor-road:io [/clanker %agent] [%| /])
  ?.  ?=(%| -.agent)  (pure:m ~)
  (pure:m `-.p.agent)
::  +rel-path: a relative "a/b/c" (or "") into a path, refusing anything
::  that could climb out of the root it is joined to.
++  rel-path
  |=  rel=@t
  ^-  (each path @t)
  ?:  =('' rel)  [%& ~]
  =/  t=tape  (trip rel)
  =/  t=tape  ?~(t t ?:(=('/' i.t) t.t t))
  =/  t=tape  ?~(t t ?:(=('/' (rear t)) (snip `tape`t) t))
  ?~  t  [%& ~]
  =/  segs=(list @ta)
    =/  rest=tape  t
    =|  acc=(list @ta)
    =|  cur=tape
    |-  ^-  (list @ta)
    ?~  rest  (flop [(crip (flop cur)) acc])
    ?:  =('/' i.rest)  $(rest t.rest, acc [(crip (flop cur)) acc], cur ~)
    $(rest t.rest, cur [i.rest cur])
  ?:  (lien segs |=(s=@ta |(=('' s) =('..' s) =('.' s))))
    [%| 'path must not contain empty, "." or ".." segments']
  [%& segs]
::
++  reserved
  |=  p=path
  ^-  ?
  ?~  p  %.n
  |(=(%tools i.p) =(%chats i.p))
::
++  ensure-dirs
  |=  [up=@ud dir=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  at=path  /
  |-
  ?~  dir  (pure:m ~)
  =/  here=path  (snoc at i.dir)
  ;<  v=view:nexus  bind:m  (peek:io [%| up %| here] ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] v)  (pure:m ~)
    (make:io [%| up %| here] &+[`[~ ~ %.n ~] ~])
  $(at here, dir t.dir)
::
++  join-mime
  |=  p=path
  ^-  tape
  ?~  p  "application/octet-stream"
  (trip (rap 3 (join '/' `(list @t)`p)))
::
::  Repo helpers. A repo clanker's config.json names the working tree it
::  reads: "repo": "/apps/.../data/tree" (an absolute path in this ship's
::  namespace). The host that made the clanker also gave its weir a peek
::  road on that tree; nothing here widens that.
::
::  +repo-config: this clanker's config.json, or why not.
++  repo-config
  =/  m  (fiber:fiber:nexus ,(each json @t))
  ^-  form:m
  ;<  up=(unit @ud)  bind:m  clanker-up
  ?~  up  (pure:m [%| 'not running inside a clanker'])
  ;<  v=view:nexus  bind:m  (peek:io [%| u.up %& / %'config.json'] `[/ %json])
  ?.  ?=([%file *] v)  (pure:m [%| 'this clanker has no config.json'])
  (pure:m [%& (fall (mole |.(!<(json (need-vase:tarball sang.v)))) [%o ~])])
::  +config-path: an absolute path named by a config key, or why not.
++  config-path
  |=  [cfg=json key=@t]
  ^-  (each path @t)
  =/  val=@t
    ?.  ?=([%o *] cfg)  ''
    =/  r  (~(get by p.cfg) key)
    ?:(?=([~ %s *] r) p.u.r '')
  ?:  =('' val)  [%| (crip "this clanker has no {(trip key)} in its config")]
  =/  pax=(unit path)  (rush val stap)
  ?~  pax  [%| (crip "the {(trip key)} in this clanker's config is not a path")]
  [%& u.pax]
::  +repo-root: the tree's absolute path, or why not.
++  repo-root
  =/  m  (fiber:fiber:nexus ,(each path @t))
  ^-  form:m
  ;<  cfg=(each json @t)  bind:m  repo-config
  ?:  ?=(%| -.cfg)  (pure:m cfg)
  (pure:m (config-path p.cfg 'repo'))
::  +read-text-at: a text file at an absolute path, or ~.
++  read-text-at
  |=  pax=path
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ?~  pax  (pure:m ~)
  ;<  v=view:nexus  bind:m  (peek:io [%& %& (snip `path`pax) (rear pax)] ~)
  ?.  ?=([%file *] v)  (pure:m ~)
  (pure:m (file-text sang.v))
::  +read-json-at: a json file at an absolute path, or ~.
++  read-json-at
  |=  pax=path
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ?~  pax  (pure:m ~)
  ;<  v=view:nexus  bind:m  (peek:io [%& %& (snip `path`pax) (rear pax)] `[/ %json])
  ?.  ?=([%file *] v)  (pure:m ~)
  ?:  (is-boom:tarball sang.v)  (pure:m ~)
  (pure:m (mole |.(!<(json (need-vase:tarball sang.v)))))
::  +repo-path: a relative path from the model, bounded to the tree.
++  repo-path
  |=  [root=path rel=@t]
  ^-  (each path @t)
  =/  r=(each path @t)  (rel-path rel)
  ?:  ?=(%| -.r)  r
  [%& (weld root p.r)]
::  +file-text: a file grub's text, when it is text: a mime of a text
::  type, or a known text blot. ~ for binary, broken, or absent.
++  file-text
  |=  s=sang:tarball
  ^-  (unit @t)
  ?:  (is-boom:tarball s)  ~
  =/  =sage:tarball  (need-sage:tarball s)
  ?:  =(%mime name.p.sage)
    =/  mim=mime  !<(mime q.sage)
    ?.  (is-text-mime (norm-mite p.mim))  ~
    `(crip (trip q.q.mim))
  ?:  (is-text-blot name.p.sage)
    ?+  name.p.sage  `!<(@t q.sage)
      %json  `(en:json:html !<(json q.sage))
      %txt   `(of-wain:format !<(wain q.sage))
    ==
  ~
::  +file-size: bytes, for the listing.
++  file-size
  |=  s=sang:tarball
  ^-  tape
  ?:  (is-boom:tarball s)  "(broken)"
  =/  =sage:tarball  (need-sage:tarball s)
  ?.  =(%mime name.p.sage)  "[{(trip name.p.sage)}]"
  =/  mim=mime  !<(mime q.sage)
  "({(join-mime (norm-mite p.mim))}, {(a-co:co p.q.mim)} bytes)"
::  +walk-texts: every TEXT file under a peeked ball, as [relative-path
::  text], in name order, depth first; binary and broken files are left
::  out.
++  walk-texts
  |=  [b=ball:tarball at=path]
  ^-  (list [p=path t=@t])
  =/  here=(list [p=path t=@t])
    ?~  fil.b  ~
    =/  names=(list @ta)  (sort ~(tap in ~(key by contents.u.fil.b)) aor)
    %+  murn  names
    |=  n=@ta
    ^-  (unit [path @t])
    =/  txt=(unit @t)  (file-text sang:(~(got by contents.u.fil.b) n))
    ?~  txt  ~
    `[(snoc at n) u.txt]
  =/  kids=(list @ta)  (sort ~(tap in ~(key by dir.b)) aor)
  =/  below=(list [p=path t=@t])
    %-  zing
    %+  turn  kids
    |=  n=@ta
    ^-  (list [p=path t=@t])
    (walk-texts (~(got by dir.b) n) (snoc at n))
  (weld here below)
::  +repo-dir: the repo instance that owns the tree: the tree is the
::  forge's <repo>.git_repo/data/tree, so the instance is two up. Its
::  run.git-action is the git lane a build tool pokes.
++  repo-dir
  |=  root=path
  ^-  path
  ?:  (lth (lent root) 2)  root
  (snip (snip `path`root))
::  +mite-of: a text mime type from a file's extension.
++  mite-of
  |=  name=@ta
  ^-  mite
  =/  t=tape  (trip name)
  =/  r=tape  (flop t)
  =/  dot=(unit @ud)  (find "." r)
  =/  ext=@t  ?~(dot '' (crip (flop (scag u.dot r))))
  ?+  ext  /text/plain
    %md    /text/markdown
    %json  /application/json
    %html  /text/html
    %css   /text/css
    %js    /text/javascript
    %hoon  /text/x-hoon
    %svg   ~['image' 'svg+xml']
    %csv   /text/csv
    %xml   /application/xml
  ==
::  +ensure-dirs-under: make every missing directory along `dir`, which
::  lies under `root` (a directory known to exist, inside the weir). The
::  walk starts AT root: walking from the namespace root would peek
::  directories above the weir and be vetoed.
++  ensure-dirs-under
  |=  [root=path dir=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =(root (scag (lent root) dir))  (pure:m ~)
  =/  at=path  root
  =/  rest=path  (slag (lent root) dir)
  |-
  ?~  rest  (pure:m ~)
  =/  here=path  (snoc at i.rest)
  ;<  v=view:nexus  bind:m  (peek:io [%& %| here] ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] v)  (pure:m ~)
    (make:io [%& %| here] &+[`[~ ~ %.n ~] ~])
  $(at here, rest t.rest)
::  +write-text-at: write a text file at an absolute path under `root`
::  (create or overwrite, as mime of a type from the extension), or why
::  not.
++  write-text-at
  |=  [root=path pax=path txt=@t]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ?~  pax  (pure:m `'no file named')
  =/  dir=path  (snip `path`pax)
  =/  name=@ta  (rear pax)
  =/  =mime  [(mite-of name) (as-octs:mimes:html txt)]
  ;<  v=view:nexus  bind:m  (peek:io [%& %& dir name] ~)
  ?:  ?=([%file *] v)
    ;<  ~  bind:m  (over:io [%& %& dir name] [[/ %mime] mime])
    (pure:m ~)
  ;<  ~  bind:m  (ensure-dirs-under root dir)
  ;<  err=(unit tang)  bind:m  (make-soft:io [%& %& dir name] |+[[[/ %mime] mime] ~])
  ?~  err  (pure:m ~)
  (pure:m `(of-wain:format (turn (flop u.err) |=(t=tank (crip (zing (wash [0 120] t)))))))
::  +lines: a text split on newlines.
++  lines
  |=  t=@t
  ^-  (list tape)
  =/  s=tape  (trip t)
  =|  cur=tape
  =|  acc=(list tape)
  |-  ^-  (list tape)
  ?~  s  (flop [(flop cur) acc])
  ?:  =('\0a' i.s)  $(s t.s, acc [(flop cur) acc], cur ~)
  $(s t.s, cur [i.s cur])
--
