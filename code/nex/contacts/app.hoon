::  contacts nexus: identity and contact management
::
::  /profiles.jobj-store — jobj-store keyed by ship name
::  /overlays.jobj-store — jobj-store keyed by ship name
::
::  Road resolution pattern:
::
::    Fibers run from different depths (/main.sig vs /ui/requests/[id]).
::    To address files at the nexus root, use nex-road:io to compute
::    a road from the calling fiber's rail — NEVER hardcode step counts.
::    A literal [%| 0 ...] or [%| 2 ...] breaks the moment the file
::    moves to a different directory depth.
::
::    nex-road:io is pure: it takes the caller's rail and a target lane,
::    and computes the relative road automatically.  All load/save helpers
::    here take the caller's rail and resolve internally.
::
/<  cui  /lib/contacts-ui.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Contacts'
            info+s+'Identity & contact management'
            color+s+'#4a90d9'
            href+s+'/grubbery/contacts'
        ==
      =/  icon=mime
        :-  /image/'svg+xml'
        %-  as-octs:mimes:html
        '''
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        '''
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'contacts'] ['description' s+'Identity & contact management']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'profiles.jobj-store'] [[/ %jobj-store] *(map @t (map @t json))]]
          [%fall %& [/ %'overlays.jobj-store'] [[/ %jobj-store] *(map @t (map @t json))]]
          [%fall %| /ui empty-dir:loader]
          [%fall %& [/ui %'main.sig'] [[/ %sig] ~]]
          [%fall %| /ui/requests empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /main.sig: granular CRUD for jobj fields
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%contacts /main: failed")
        ;<  ~  bind:m  (sync-ames rail)
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?.  =(%json name.p.sage)
          ~&  >  [%contacts %unknown-mark name.p.sage]
          $
        =/  jon=json  !<(json q.sage)
        ?.  ?=([%o *] jon)  $
        =/  act=(unit json)  (~(get by p.jon) 'action')
        ?.  ?=([~ %s @] act)  $
        =/  action=@t  p.u.act
        ?:  =(%'sync-ames' action)
          ;<  ~  bind:m  (sync-ames rail)
          $
        =/  who=(unit json)  (~(get by p.jon) 'ship')
        ?.  ?=([~ %s @] who)  $
        =/  ship=@t  p.u.who
        ?~  (slaw %p ship)  $
        ?+    action  $
            ::  %put: set fields on overlay
            ::
            %'put'
          =/  fields=(unit json)  (~(get by p.jon) 'fields')
          ?.  ?=([~ %o *] fields)  $
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  existing=(map @t json)  (fall (~(get by overlays) ship) ~)
          =/  merged=(map @t json)  (~(uni by existing) p.u.fields)
          =/  new-overlays=(map @t (map @t json))  (~(put by overlays) ship merged)
          ;<  ~  bind:m  (save-overlays rail new-overlays)
          $
            ::  %del: delete specific fields from overlay
            ::
            %'del'
          =/  fields=(unit json)  (~(get by p.jon) 'fields')
          ?.  ?=([~ %a *] fields)  $
          =/  keys=(list @t)
            %+  murn  p.u.fields
            |=(=json ?.(?=([%s @] json) ~ `p.json))
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  existing=(map @t json)  (fall (~(get by overlays) ship) ~)
          =/  pruned=(map @t json)
            |-  ?~  keys  existing
            $(keys t.keys, existing (~(del by existing) i.keys))
          =/  new-overlays=(map @t (map @t json))  (~(put by overlays) ship pruned)
          ;<  ~  bind:m  (save-overlays rail new-overlays)
          $
            ::  %wipe: delete entire contact
            ::
            %'wipe'
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  new-overlays=(map @t (map @t json))  (~(del by overlays) ship)
          ;<  ~  bind:m  (save-overlays rail new-overlays)
          $
        ==
          ::  /ui/main.sig: HTTP endpoint
          ::
          [[%ui ~] %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%contacts /ui/main: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/contacts])
        (http-dispatch:io %contacts)
          ::  /ui/requests/*: individual HTTP request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%contacts /ui/requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  prefix=path  /grubbery/contacts
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        =/  method=@t  method.request.req
        ::
        ::  GET / — contacts page
        ::
        ?:  ?&(=(%'GET' method) =(~ suffix))
          ;<  profiles=(map @t (map @t json))  bind:m  (load-profiles rail)
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  page=manx  (contacts-page:cui profiles overlays)
          ;<  ~  bind:m  (send-html eyre-id page)
          (pure:m ~)
        ::
        ::  GET /api/profiles — all profiles as JSON
        ::
        ?:  ?&(=(%'GET' method) =(/api/profiles suffix))
          ;<  profiles=(map @t (map @t json))  bind:m  (load-profiles rail)
          =/  body=@t
            %-  en:json:html
            [%o (~(run by profiles) |=((map @t json) [%o +<]))]
          ;<  ~  bind:m  (send-json eyre-id body)
          (pure:m ~)
        ::
        ::  GET /api/overlays — all overlays as JSON
        ::
        ?:  ?&(=(%'GET' method) =(/api/overlays suffix))
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  body=@t
            %-  en:json:html
            [%o (~(run by overlays) |=((map @t json) [%o +<]))]
          ;<  ~  bind:m  (send-json eyre-id body)
          (pure:m ~)
        ::
        ::  POST /api/sync-ames — import ames peers as contacts
        ::
        ?:  ?&(=(%'POST' method) =(/api/'sync-ames' suffix))
          ;<  ~  bind:m  (sync-ames rail)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ::  POST /api/overlay/[ship] — put fields into overlay
        ::
        ?:  ?&(=(%'POST' method) ?=([%api %overlay @ ~] suffix))
          =/  who=@ta  i.t.t.suffix
          ?~  (slaw %p who)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid ship name')])
            (pure:m ~)
          =/  bod=(unit @t)  ?~(body.request.req ~ `q.u.body.request.req)
          ?~  bod
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
            (pure:m ~)
          =/  jon=(unit json)  (de:json:html u.bod)
          ?~  jon
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
            (pure:m ~)
          ?.  ?=([%o *] u.jon)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Must be JSON object')])
            (pure:m ~)
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  existing=(map @t json)  (fall (~(get by overlays) who) ~)
          =/  merged=(map @t json)  (~(uni by existing) p.u.jon)
          =/  new-overlays=(map @t (map @t json))  (~(put by overlays) who merged)
          ;<  ~  bind:m  (save-overlays rail new-overlays)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ::  DELETE /api/overlay/[ship] — wipe overlay
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %overlay @ ~] suffix))
          =/  who=@ta  i.t.t.suffix
          ?~  (slaw %p who)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid ship name')])
            (pure:m ~)
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  new-overlays=(map @t (map @t json))  (~(del by overlays) who)
          ;<  ~  bind:m  (save-overlays rail new-overlays)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ::  DELETE /api/overlay/[ship]/[field] — delete single overlay field
        ::
        ?:  ?&(=(%'DELETE' method) ?=([%api %overlay @ @ ~] suffix))
          =/  who=@ta  i.t.t.suffix
          ?~  (slaw %p who)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid ship name')])
            (pure:m ~)
          =/  field=@t  i.t.t.t.suffix
          ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays rail)
          =/  existing=(map @t json)  (fall (~(get by overlays) who) ~)
          =/  pruned=(map @t json)  (~(del by existing) field)
          =/  new-overlays=(map @t (map @t json))  (~(put by overlays) who pruned)
          ;<  ~  bind:m  (save-overlays rail new-overlays)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::
        ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
      ==
    --
|%
::  +weir-json: the roads contacts reaches — the permission ask the user
::  consents to in their shell.
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship — get-time / get-our')
          (line '/sys/eyre/' 'bind /grubbery/contacts and serve its page')
          (line '/sys/scry/' 'scry ames peers to import them as contacts — sync-ames')
      ==
  ==
::  +sync-ames: scry ames peers and write all into single overlays grub
::
++  sync-ames
  |=  from=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ;<  peers=(map ship ?(%alien %known))  bind:m
    (typed-scry:io (map ship ?(%alien %known)) %ames-peers /ax//peers)
  ;<  overlays=(map @t (map @t json))  bind:m  (load-overlays from)
  =/  new-overlays=(map @t (map @t json))
    %+  roll  ~(tap by peers)
    |=  [[=ship val=?(%alien %known)] acc=(map @t (map @t json))]
    ?:  =(ship our)  acc
    =/  who=@t  (scot %p ship)
    =/  existing=(map @t json)  (fall (~(get by acc) who) ~)
    =/  merged=(map @t json)
      %-  ~(uni by existing)
      %-  ~(gas by *(map @t json))
      :~  ['source' s+'ames']
          ['ames' s+val]
      ==
    (~(put by acc) who merged)
  ~&  [%contacts %sync-ames %peers ~(wyt by peers)]
  (save-overlays from new-overlays)
::
::  Store read/write helpers
::
++  load-profiles
  |=  from=rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t (map @t json)))
  ^-  form:m
  ;<  view=view:nexus  bind:m
    (peek:io (nex-road:io from [%& / %'profiles.jobj-store']) `[/ %jobj-store])
  =/  store=(map @t (map @t json))
    ?.  ?=([%file *] view)  ~
    ?:  (is-boom:tarball sang.view)  ~
    !<((map @t (map @t json)) (need-vase:tarball sang.view))
  (pure:m store)
::
++  load-overlays
  |=  from=rail:tarball
  =/  m  (fiber:fiber:nexus ,(map @t (map @t json)))
  ^-  form:m
  ;<  view=view:nexus  bind:m
    (peek:io (nex-road:io from [%& / %'overlays.jobj-store']) `[/ %jobj-store])
  =/  store=(map @t (map @t json))
    ?.  ?=([%file *] view)  ~
    ?:  (is-boom:tarball sang.view)  ~
    !<((map @t (map @t json)) (need-vase:tarball sang.view))
  (pure:m store)
::
++  save-overlays
  |=  [from=rail:tarball store=(map @t (map @t json))]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (nex-road:io from [%& / %'overlays.jobj-store']) [[/ %jobj-store] store])
::
++  save-profiles
  |=  [from=rail:tarball store=(map @t (map @t json))]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (over:io (nex-road:io from [%& / %'profiles.jobj-store']) [[/ %jobj-store] store])
::
::  HTTP helpers
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  send-html
  |=  [eyre-id=@ta page=manx]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  htm=@t  (crip (en-xml:html page))
  (send-simple:srv eyre-id [[200 ~[['content-type' 'text/html']]] `(as-octs:mimes:html htm)])
::
++  send-json
  |=  [eyre-id=@ta body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html body)])
--
