/<  tools  /lib/tools.hoon
/<  rss    /lib/rss.hoon
^-  tool:tools
|%
++  name  'feeds_list'
++  description
  'List configured RSS/Atom feeds with title, item count, and last fetch time.'
++  parameters
  ^-  (map @t parameter-def:tools)
  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  cr=road:tarball  bind:m  (ancestor-road:io [/feeds %app] [%& / %'feeds.json'])
  ;<  cfg=view:nexus  bind:m  (peek:io cr `[/ %json])
  =/  urls=(list @t)
    ?.  ?=([%file *] cfg)  ~
    =/  jon=json  !<(json (need-vase:tarball sang.cfg))
    ?.  ?=([%a *] jon)  ~
    (murn p.jon |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  ;<  sr=road:tarball  bind:m  (ancestor-road:io [/feeds %app] [%| /store])
  ;<  sto=view:nexus  bind:m  (peek:io sr ~)
  =/  stores=(list feed-store:rss)
    ?.  ?=([%ball *] sto)  ~
    %+  murn  ~(tap ba:tarball ball.sto)
    |=  [* =sang:tarball]
    ^-  (unit feed-store:rss)
    ?.  =([/ %feed] p.sang)  ~
    ?:  (is-boom:tarball sang)  ~
    `!<(feed-store:rss (need-vase:tarball sang))
  =/  fetched=(set @t)  (silt (turn stores |=(fs=feed-store:rss url.fs)))
  =/  jon=json
    %-  pairs:enjs:format
    :~  :-  'feeds'
        :-  %a
        %+  turn  stores
        |=  fs=feed-store:rss
        %-  pairs:enjs:format
        :~  ['url' s+url.fs]
            ['title' s+title.fs]
            ['items' (numb:enjs:format (lent items.fs))]
            ['fetched' (time:enjs:format fetched.fs)]
        ==
        :-  'pending'
        :-  %a
        %+  murn  urls
        |=  u=@t
        ^-  (unit json)
        ?:  (~(has in fetched) u)  ~
        `[%s u]
    ==
  (pure:m [%text (en:json:html jon)])
--
