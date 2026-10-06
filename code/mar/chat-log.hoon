::  chat-log: a clanker chat's event log. A json array of events
::  {k: input | response | results | interrupt, ...}, appended one per
::  step of a turn; the agent assembles the model's request from it.
::  Its own mark so the explorer opens it in the chat viewer (its
::  viewers.json maps chat-log to clanker's viewer.js); the data is
::  plain json, and it reads and writes as json.
::
|_  log=json
++  grab
  |%
  ++  noun  ^json
  ++  json  |=(a=^json a)
  --
++  grow
  |%
  ++  noun  log
  ++  json  log
  ++  mime  [/application/json (as-octs:mimes:html (en:json:html log))]
  --
++  grad  %json
--
