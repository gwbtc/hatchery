/<  tools  /lib/tools.hoon
::  read_itinerary: the trip's itinerary document (pins, zones,
::  categories, schedule, todos) as JSON text. The trip is the one this
::  clanker was made for: its config.json's "repo" is the trip dir.
::
!:
^-  tool:tools
|%
++  name  'read_itinerary'
++  description  'Read the itinerary document in full. Returns its JSON: name, desc, dates, tz, center, zoom, categories, pins, zones, schedule, todos.'
++  parameters
  ^-  (map @t parameter-def:tools)
  ~
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  dr=(each road:tarball @t)  bind:m  trip-doc:tools
  ?:  ?=(%| -.dr)  (pure:m [%error p.dr])
  ;<  fv=view:nexus  bind:m  (peek:io p.dr `[/ %json])
  ?.  ?=([%file *] fv)
    (pure:m [%error 'No itinerary document in this trip'])
  =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.fv)))) *json)
  (pure:m [%text (en:json:html jon)])
--
