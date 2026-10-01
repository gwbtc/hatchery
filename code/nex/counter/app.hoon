::  counter nexus: many auto-incrementing counters identified by @da
::
/&  man  ../../man/counter/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %| /counters empty-dir:loader]
          [%over %& [/ui/views %'page.html'] [[/ %html] (crip (en-xml:html (counter-page ~)))]]
          [%fall %& [/ui %'main.sig'] [[/ %sig] ~]]
          [%fall %| /ui/requests empty-dir:loader]
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'counter'] ['description' s+'A simple tick-up counter']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /counters/*: each counter ticks up every second
          ::
          [[%counters ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%counter: process failed")
        |-
        ;<  count=@ud  bind:m  (get-state-as:io ,@ud)
        ;<  ~  bind:m  (sleep:io ~s1)
        ;<  ~  bind:m  (replace:io +(count))
        $
          ::  /ui/views/page.html: render full page HTML once, persist
          ::
          [[%ui %views ~] %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/views/page: failed")
        ;<  init=wave:nexus  bind:m
          (keep:io /ctrs (cord-to-road:tarball '../../counters/') ~)
        |-
        ;<  upd=wave:nexus  bind:m  (take-news:io /ctrs)
        ;<  =view:nexus  bind:m  (peek:io (cord-to-road:tarball '../../counters/') ~)
        ?.  ?=([%ball *] view)  $
        =/  counters=(list [@ta @ud])
          (lump-counters (fall fil.ball.view *lump:tarball))
        =/  page=manx  (counter-page counters)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html page)))
        $
          ::  /ui/main.sig: bind HTTP endpoint and dispatch requests
          ::  into /ui/requests/. URL derived from tree position.
          ::
          [[%ui ~] %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/main: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/counters])
        (http-dispatch:io %counter)
          ::  /ui/requests/*: individual request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  prefix=path  /grubbery/counters
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        =/  method=@t  method.request.req
        ::  the app's own API, addressed relative to this fiber: the page
        ::  cannot know its absolute root (it may be a desk install), so it
        ::  never names one. /counters is two levels up from /ui/requests.
        ?:  ?=([%api %list ~] suffix)
          ;<  cv=view:nexus  bind:m  (peek:io [%| 2 %| /counters] ~)
          =/  counters=(list [@ta @ud])
            ?.  ?=([%ball *] cv)  ~
            (lump-counters (fall fil.ball.cv *lump:tarball))
          =/  jon=json
            :-  %o
            %-  ~(gas by *(map @t json))
            (turn counters |=([n=@ta v=@ud] [`@t`n (numb:enjs:format v)]))
          =/  body=octs  (as-octs:mimes:html (en:json:html jon))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `body])
          (pure:m ~)
        ?:  &(=('PUT' method) ?=([%api %counter @ ~] suffix))
          ;<  ~  bind:m  (make:io [%| 2 %& /counters i.t.t.suffix] |+[[[/ %ud] 0] ~])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ?:  &(=('DELETE' method) ?=([%api %counter @ ~] suffix))
          ;<  *  bind:m  (cull-soft:io [%| 2 %& /counters i.t.t.suffix])
          ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
          (pure:m ~)
        ::  Serve counter page from view grub
        ;<  =view:nexus  bind:m  (peek:io [%| 2 %& /ui/views %'page.html'] `[/ %mime])
        ?.  ?=([%file *] view)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'View not ready')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.view))
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
::  weir.json: what counter ACTUALLY reaches outside its own tree. Own-tree
::  access (/counters, /ui, /requests) is exempt — it never crosses counter's
::  boundary weir. All it needs foreign is three /sys services.
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship — every fiber uses get-time / get-our')
          (line '/sys/behn/' 'set a timer to tick each counter up every second')
          (line '/sys/eyre/' 'bind its HTTP route and send page responses')
      ==
  ==
::  HTTP response door (road from /ui/requests/* to /ui/main.sig)
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  +lump-counters: the counters in a directory lump — every %ud file
::
++  lump-counters
  |=  =lump:tarball
  ^-  (list [@ta @ud])
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  ?.  ?=(%ud name.p.sang)  ~
  `[name !<(@ud (need-vase:tarball sang))]
::
++  counter-page
  |=  counters=(list [@ta @ud])
  ^-  manx
  =/  js=tape
    ;:  weld
      "var API='/grubbery/counters/api';"
      "document.getElementById('create').onclick=function()\{fetch(API+'/counter/'+Date.now().toString(36),\{method:'PUT'})};"
      "function removeCounter(n)\{var e=document.getElementById('c-'+n);if(e)e.remove();if(!document.querySelector('.counter'))document.getElementById('counters').textContent='No counters'}"
      "function deleteCounter(n)\{fetch(API+'/counter/'+n,\{method:'DELETE'});removeCounter(n)}"
      "function upsertCounter(n,v)\{var b=document.getElementById('counters');var e=document.getElementById('c-'+n);if(!e)\{if(b.textContent==='No counters')b.textContent='';e=document.createElement('div');e.id='c-'+n;e.className='counter fc fh g2 p2 b1 br1 jcsb';b.appendChild(e)}e.innerHTML='<div class=\"fc-col\"><span class=\"s7 bold\">'+v+'</span><span class=\"s9 muted\">'+n+'</span></div><button class=\"p-1 b1 br1 hover pointer s9\" onclick=\"deleteCounter(\\x27'+n+'\\x27)\">Delete</button>'}"
      "async function poll()\{try\{var r=await fetch(API+'/list');var m=await r.json();var seen=\{};for(var n in m)\{seen[n]=1;upsertCounter(n,m[n])}var es=document.querySelectorAll('.counter');for(var i=0;i<es.length;i++)\{var id=es[i].id.slice(2);if(!seen[id])removeCounter(id)}}catch(x)\{}setTimeout(poll,1000)}poll()"
    ==
  ;html
    ;head
      ;title: Grubbery Counters
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  "body \{ font-family: monospace; max-width: 600px; margin: 0 auto; padding: 2rem; } .counter \{ margin-bottom: 0.5rem; } .muted \{ opacity: 0.5; } .fc \{ display: flex; } .fh \{ flex-direction: row; } .fc-col \{ display: flex; flex-direction: column; } .g2 \{ gap: 0.5rem; } .p2 \{ padding: 0.5rem; } .p-1 \{ padding: 0.25rem 0.5rem; } .b1 \{ border: 1px solid #ccc; } .br1 \{ border-radius: 4px; } .jcsb \{ justify-content: space-between; align-items: center; } .s7 \{ font-size: 1.2rem; } .s9 \{ font-size: 0.8rem; } .bold \{ font-weight: bold; } .hover:hover \{ background: #eee; } .pointer \{ cursor: pointer; } .mb2 \{ margin-bottom: 1rem; }"
      ==
    ==
    ;body
      ;h1: Grubbery Counters
      ;button#create.mb2.p2.b1.br1.hover.pointer: + New Counter
      ;div#counters
        ;*  ?~  counters
              =/  empty=manx  ;span: No counters
              ~[empty]
            %+  turn  counters
            |=  [name=@ta val=@ud]
            =/  n=tape  (trip name)
            =/  v=tape  (a-co:co val)
            ;div.counter.fc.fh.g2.p2.b1.br1.jcsb(id "c-{n}")
              ;div.fc-col
                ;span.s7.bold: {v}
                ;span.s9.muted: {n}
              ==
              ;button.p-1.b1.br1.hover.pointer.s9(onclick "deleteCounter('{n}')"): Delete
            ==
      ==
      ;script
        ;+  ;/  js
      ==
    ==
  ==
--
