::  clanker agent: ONE clanker, as a nexus. The collection (./app.hoon)
::  mounts one of these per <name>.clanker dir, under a weir that is the
::  clanker's scope. Everything the clanker is lives in its own tree:
::
::    config.json         {name, model, max_tokens, bundle}
::    prompts/main.md     the standing prompt; beside it the words of the
::                        harness (recipes.md, skills.md, tip.txt,
::                        spent.txt, lines.json), the clanker's to edit
::    memories/*.md       what it has learned (its tools write here)
::    skills/*.md         standing instructions, one per file
::    tools.json          the tool policy (optional): which tools run
::                        freely, which ask first, which are withheld
::    chats/<c>/log.chat-log     one append-only event log per chat
::    chats/<c>/system.md        that chat's own prompt (optional): the
::                               clanker is one identity, a chat is one
::                               standing role of it (docs, build, …)
::    chats/<c>/tools.json       that chat's own policy (optional), which
::                               can only tighten the clanker's
::    chats/<c>/<sub>.clanker/   a clanker this chat spawned (nested)
::    tools/              its own tools nexus, seeded from a bundle
::
::  Every turn assembles the request from those files: prompts/main.md,
::  then the chat's own system.md if it has one, then the skills, then the
::  memories, then the chat's events. Tools and memories are the
::  clanker's; a chat narrows the tools by policy, never widens them (a
::  chat that needs MORE is a different clanker, with its own weir). The
::  tools it advertises are whatever its tools nexus lists, so adding a
::  tool is writing a file under tools/code/lib/tools, no schema anywhere.
::
::  The tool policy (tools.json, at the clanker and/or a chat):
::    {"default": "ask", "allow": ["repo_read"], "deny": ["write_file"]}
::  Per tool NAME, nothing finer (a tool whose uses deserve different
::  answers is two tools). A matching deny wins, then a matching allow,
::  else the default; with no file at all everything is allowed. The
::  chat's verdict and the clanker's combine as the stricter of the two.
::    deny   the tool is not advertised to the model at all
::    allow  runs as it comes
::    ask    advertised; when the model calls it the turn pauses on an
::           %ask event, the chat pane offers run/decline per use, and a
::           {action:'resolve'} poke appends a %resolved event and the
::           turn goes on: accepted uses run, declined ones answer the
::           model with a refusal. The log is the truth, so a pending ask
::           survives a restart and a stop cancels it.
::
::  Reuse: lib/clanker's door for the metered proxy round-trip
::  (+call-anthropic), persistence (+write-chat) and the interrupt-aware
::  take; lib/tools for the run-grub protocol the tools nexus speaks.
::
/<  clanker    /lib/clanker.hoon
/<  nex-tools  /lib/tools.hoon
/<  rcp-lib    /lib/recipe.hoon
::  every sentence the model reads from this agent: the standing
::  sections (recipes.md, skills.md), the tip (tip.txt, spent.txt) and
::  the one-liners (lines.json: tool descriptions, step results, the
::  lines the log records). These seed each clanker's prompts/ once,
::  beside its main.md; the clanker's own files are what is read, per
::  request (+read-frags), and +say fills one with the run's facts
/&  prompts-raw  /nex/clanker/prompts/
::  the skills every clanker starts with, seeded into its skills/ once
/&  skills-raw  /nex/clanker/skills/
/&  bundle         /lib/clanker-bundle/
/&  kernel-bundle  /lib/clanker-kernel-bundle/
/&  repo-bundle    /lib/clanker-repo-bundle/
/&  build-bundle   /lib/clanker-build-bundle/
/&  trip-bundle    /lib/clanker-trip-bundle/
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  the sandbox is NOT self-declared here: it is the weir the host
      ::  set on this nexus when it mounted it. This lays out the tree.
      ::  config.json's "bundle" (read from the ball) picks the tools:
      ::  "kernel" adds the grubbery self-editing set to the default.
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          ::  prompts/: main.md is the standing prompt, the clanker's own
          ::  from the start; the rest are the words of the harness, seeded
          ::  once and then the clanker's too
          [%fall %& [/prompts %'main.md'] [[/ %mime] [/text/markdown (as-octs:mimes:html '')]]]
          [%fall %& [/prompts %'recipes.md'] [[/ %mime] (prompt-file %'recipes.md')]]
          [%fall %& [/prompts %'skills.md'] [[/ %mime] (prompt-file %'skills.md')]]
          [%fall %& [/prompts %'tip.txt'] [[/ %mime] (prompt-file %'tip.txt')]]
          [%fall %& [/prompts %'spent.txt'] [[/ %mime] (prompt-file %'spent.txt')]]
          [%fall %& [/prompts %'lines.json'] [[/ %mime] (prompt-file %'lines.json')]]
          [%fall %| /memories empty-dir:loader]
          ::  skills/: read on demand (the standing prompt lists them, the
          ::  model reads one when it applies). The defaults are seeded
          ::  once; a clanker may edit or remove them
          [%fall %| /skills empty-dir:loader]
          [%fall %& [/skills %'recipes.md'] [[/ %mime] (default-skill %'recipes.md')]]
          ::  recipes/*.json: thought processes a chat can follow. A run's
          ::  position lives beside that chat's log, as chats/<c>/run.json
          [%fall %| /recipes empty-dir:loader]
          [%fall %| /chats empty-dir:loader]
          ::  files/: what the clanker writes for the owner (write_file) and
          ::  its attachments (files/blobs, content-addressed). The loader
          ::  drops any directory its rows do not cover, so this row is what
          ::  lets a clanker's files survive a reload
          [%fall %| /files empty-dir:loader]
          ::  the tools nexus: its directory (the neck) seeded once, so
          ::  its runs/ (the record of every tool call, what +call-tool
          ::  resumes from after a reload) survive a reload; its CODE
          ::  overwritten from the bundle every load, so a bundle change
          ::  reaches it
          [%fall %| /tools (tools-dir (bundle-of ball))]
          [%over %| /tools/code (tools-code (bundle-of ball))]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        (serve rail prod)
      ==
    --
|%
++  ck  ~(. clanker:clanker [%clanker [%a ~] '' [%o ~]])
::  +prompt-file: one of the shipped prompt files, as the mime its seed
::  row writes
++  prompt-file
  |=  name=@ta
  ^-  mime
  (fall (~(get by (fall fil.prompts-raw ~)) name) [/text/plain (as-octs:mimes:html '')])
::  +default-skill: one of the shipped skills, as the mime its seed row writes
++  default-skill
  |=  name=@ta
  ^-  mime
  (fall (~(get by (fall fil.skills-raw ~)) name) [/text/markdown (as-octs:mimes:html '')])
::  +say: one system-prompt fragment with its {keys} filled
++  say
  |=  [=frags:rcp-lib name=@ta subs=(list [tape tape])]
  ^-  @t
  (crip (say:rcp-lib frags name subs))
::  +read-frags: the clanker's prompts/ directory as fragments: its files
::  by name, and the entries of lines.json by key
++  read-frags
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,frags:rcp-lib)
  ^-  form:m
  ;<  files=(list [@ta @t])  bind:m  (read-dir-texts rail /prompts)
  (pure:m (frags-of-texts:rcp-lib files))
++  default-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['model' s+'claude-sonnet-4-6']
      ['max_tokens' (numb:enjs:format 4.096)]
      ['bundle' s+'default']
  ==
::  +bundle-of: config.json's "bundle" as it sits in the ball at load.
++  bundle-of
  |=  =ball:tarball
  ^-  @t
  ?~  fil.ball  'default'
  =/  got  (~(get by contents.u.fil.ball) %'config.json')
  ?~  got  'default'
  =/  res  (mule |.(!<(json (need-vase:tarball sang.u.got))))
  ?:  ?=(%| -.res)  'default'
  =/  b=@t  (jstr:clanker p.res 'bundle')
  ?:(=('' b) 'default' b)
::  +tools-bole: the tools nexus mount, seeded from the default bundle and,
::  on top of it, the bundle config.json names: "kernel" = the grubbery
::  self-editing tools; "repo" = tools that read one git checkout (the
::  repo config.json points at, within the weir the host set).
++  tools-bole
  |=  which=@t
  ^-  bole:tarball
  =/  base=bole:tarball  (seed-tools:nex-tools bundle)
  ?:  =('kernel' which)
    (merge-boles:nex-tools base (seed-tools:nex-tools kernel-bundle))
  ?:  =('repo' which)
    (merge-boles:nex-tools base (seed-tools:nex-tools repo-bundle))
  ::  "build" = the repo set plus the tools that change the checkout and
  ::  drive its git lane (write, edit, git); which chats may use those is
  ::  the policy's business (tools.json), the weir's what they may reach
  ?:  =('build' which)
    %+  merge-boles:nex-tools
      (merge-boles:nex-tools base (seed-tools:nex-tools repo-bundle))
    (seed-tools:nex-tools build-bundle)
  ::  "trip" = the itinerary tools: the document by field, the attachments,
  ::  geocoding; the trip dir is the config's "repo"
  ?:  =('trip' which)
    (merge-boles:nex-tools base (seed-tools:nex-tools trip-bundle))
  base
::  +tools-dir: the tools nexus directory alone (its neck, no contents);
::  +tools-code: its code nexus, the bundle's tools.
++  tools-dir
  |=  which=@t
  ^-  bole:tarball
  [fil:(tools-bole which) ~]
++  tools-code
  |=  which=@t
  ^-  bole:tarball
  (~(got by dir:(tools-bole which)) %code)
::  +serve: the main.sig poke loop. {chat, message} runs a turn;
::  {action:'interrupt'} is swallowed here (it lands mid-await inside a
::  running turn, which cancels it). The tools nexus's list reply is a
::  json array poked back here; it is taken inside +list-tools, so a
::  stray one that arrives idle is dropped.
++  serve
  |=  [=rail:tarball =prod:fiber:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (rise-wait:io prod "%clanker agent: failed")
  ;<  ~  bind:m  (resume rail)
  |-
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  act=(unit @t)
    (bind (~(get by p.jon) 'action') |=(j=json ?>(?=(%s -.j) p.j)))
  =/  chat=@t  =/(c=@t (jstr:clanker jon 'chat') ?:(=('' c) 'main' c))
  ::  an interrupt that lands idle: nothing runs, but a chat paused on an
  ::  ask is waiting on the user, and stop means no
  ?:  ?=([~ %'interrupt'] act)
    ;<  ~  bind:m  (cancel-ask rail chat)
    $
  ::  the user's answer to a pending ask: {action:'resolve', chat,
  ::  decisions:{<tool_use id>: true|false}}
  ?:  ?=([~ %'resolve'] act)
    ;<  ~  bind:m  (resolve-chat rail jon chat)
    $
  ::  the user takes the chat out of its recipes: {action:'leave', chat,
  ::  depth?}: the frame at depth (bottom = 0) and every one above it
  ::  go; no depth means the top one
  ?:  ?=([~ %'leave'] act)
    =/  depth=(unit @ud)
      =/  d=(unit json)  (~(get by p.jon) 'depth')
      ?~  d  ~
      (mole |.((ni:dejs:format u.d)))
    ;<  ~  bind:m  (leave-run rail chat depth)
    $
  ;<  ~  bind:m  (turn-chat rail jon chat)
  $
::  +leave-run: the user ends recipe runs from outside. The frames are
::  dropped and the log says who did it, one line each, so the model's
::  history shows the exit too. Not while a turn runs: the running
::  fiber holds the log and would write over the lines.
++  leave-run
  |=  [=rail:tarball chat=@t depth=(unit @ud)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  held=stack:rcp-lib  bind:m  (read-run rail chat)
  ?~  held  (pure:m ~)
  ;<  [road=road:tarball existed=? log=(list json)]  bind:m  (chat-log rail chat)
  ?:  (open-turn log)  (pure:m ~)
  ;<  frags=frags:rcp-lib  bind:m  (read-frags rail)
  ::  `all` is held before ?~ narrowed it: scag and slag return ^+ their
  ::  list, and ~ does not nest in a lest
  =/  all=stack:rcp-lib  held
  =/  n=@ud  (lent all)
  =/  keep=@ud  ?~(depth (dec n) (min u.depth (dec n)))
  =/  gone=stack:rcp-lib  (scag (sub n keep) all)
  ;<  ~  bind:m  (write-run rail chat (slag (sub n keep) all))
  =/  lines=(list json)
    %+  turn  gone
    |=  s=state:rcp-lib
    (event-recipe (say frags %'left-by-user' ~[["name" (trip name.s)] ["step" (trip step.s)]]))
  (write-log road existed (weld log lines))
::  +chat-log: a chat's log road and its events (~ when there is none).
++  chat-log
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,[road=road:tarball existed=? log=(list json)])
  ^-  form:m
  =/  road=road:tarball  (nex-road:io rail [%& [%chats `@ta`chat ~] log-name])
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
  =/  log=(list json)
    ?.  ?=([%file *] cur)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.(?=([%a *] j) ~ p.j)
  (pure:m [road ?=([%file *] cur) log])
::  +read-run, +write-run: a chat's recipe run, a sibling of its log and
::  its status. Only the position and the spend persist; the tip itself
::  is rendered per request and never stored.
::
++  read-run
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,stack:rcp-lib)
  ^-  form:m
  ;<  j=json  bind:m  (read-json rail [%& [%chats `@ta`chat ~] %'run.json'])
  (pure:m (stack-from-json:rcp-lib j))
::
++  write-run
  |=  [=rail:tarball chat=@t st=stack:rcp-lib]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (nex-road:io rail [%& [%chats `@ta`chat ~] %'run.json'])
  =/  j=json  (stack-to-json:rcp-lib st)
  ;<  v=view:nexus  bind:m  (peek:io road ~)
  ?:  ?=([%file *] v)  (over:io road [[/ %json] j])
  ;<  *  bind:m  (make-soft:io road |+[[[/ %json] j] ~])
  (pure:m ~)
::  +read-recipe: one of the clanker's recipes, parsed.
::
++  read-recipe
  |=  [=rail:tarball name=@t]
  =/  m  (fiber:fiber:nexus ,(unit recipe:rcp-lib))
  ^-  form:m
  ?:  =('' name)  (pure:m ~)
  ;<  j=json  bind:m  (read-json rail [%& /recipes (crip "{(trip name)}.json")])
  (pure:m (parse:rcp-lib name j))
::  +engage: {recipe} in the poke (or the enter tool's input) starts that
::  recipe for this chat, from its first step, pushed over whatever the
::  chat is already on. Yields the line the chat log records for it, so
::  the entry is in the history both the user and the model read; ~
::  when nothing was entered.
::
++  engage
  |=  [=rail:tarball chat=@t jon=json]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  want=@t  (jstr:clanker jon 'recipe')
  ?:  =('' want)  (pure:m ~)
  ;<  r=(unit recipe:rcp-lib)  bind:m  (read-recipe rail want)
  ?~  r  (pure:m ~)
  =/  lvl=@t  =/(l=@t (jstr:clanker jon 'level') ?:(=('' l) 'normal' l))
  ;<  held=stack:rcp-lib  bind:m  (read-run rail chat)
  ;<  ~  bind:m  (write-run rail chat (push:rcp-lib held (enter:rcp-lib u.r lvl)))
  ::  a start step that is itself a recipe enters that one too
  ;<  ~  bind:m  (descend rail chat u.r start.u.r lvl 0)
  ;<  frags=frags:rcp-lib  bind:m  (read-frags rail)
  (pure:m `(entering-line frags want start.u.r lvl held))
::  +descend: landing on a recipe-step pushes its recipe, from its own
::  start step, as deep as that goes. The lines are written by +run
::  from the stack, so nothing is said here. Eight deep is a loop.
::
++  descend
  |=  [=rail:tarball chat=@t =recipe:rcp-lib step=@t lvl=@t depth=@ud]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  (gte depth 8)  (pure:m ~)
  =/  sub=(unit @t)  (sub-of:rcp-lib recipe step)
  ?~  sub  (pure:m ~)
  ;<  r=(unit recipe:rcp-lib)  bind:m  (read-recipe rail u.sub)
  ?~  r  (pure:m ~)
  ;<  held=stack:rcp-lib  bind:m  (read-run rail chat)
  ;<  ~  bind:m  (write-run rail chat (push:rcp-lib held (enter:rcp-lib u.r lvl)))
  $(recipe u.r, step start.u.r, depth +(depth))
::  +entering-line: the one line a push writes to the log.
::
++  entering-line
  |=  [=frags:rcp-lib name=@t step=@t lvl=@t outer=stack:rcp-lib]
  ^-  @t
  =/  within=tape
    ?~  outer  ""
    (trip (say frags %'entering-within' ~[["name" (trip name.i.outer)] ["step" (trip step.i.outer)]]))
  (say frags %'entering' ~[["name" (trip name)] ["step" (trip step)] ["level" (trip lvl)] ["within" within]])
::  +recipe-names: the recipes this clanker holds, by file stem.
::
++  recipe-names
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /recipes]) ~)
  ?.  ?=([%ball *] v)  (pure:m ~)
  ?~  fil.ball.v  (pure:m ~)
  %-  pure:m
  %+  murn  (sort ~(tap in ~(key by contents.u.fil.ball.v)) aor)
  |=  n=@ta
  ^-  (unit @t)
  =/  t=tape  (trip n)
  ?:  (lth (lent t) 5)  ~
  ?.  =(".json" (slag (sub (lent t) 5) t))  ~
  `(crip (scag (sub (lent t) 5) t))
::  +enter-schema: offered only while no run is live. The names ride in
::  the description, so the model knows what it may enter without a
::  separate catalog. The tool policy governs it like any other tool,
::  by the name `recipe_enter`.
::
++  enter-schema
  |=  [=frags:rcp-lib names=(list @t)]
  ^-  json
  =/  listed=tape
    %-  zing
    %+  join  ", "
    (turn names |=(n=@t (trip n)))
  %:  mk-tool-typed:clanker  'recipe_enter'
    (say frags %'tool-enter' ~[["recipes" listed]])
    :~  ['recipe' 'string' (say frags %'tool-enter-recipe' ~)]
        ['level' 'string' (say frags %'tool-enter-level' ~)]
    ==
    ~['recipe']
  ==
::  +take-enter: the model entering a recipe: +engage pushes it. What
::  that did to the stack is recorded by +run from the stack itself,
::  not from this result.
::
++  take-enter
  |=  [=rail:tarball chat=@t input=json]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  ;<  frags=frags:rcp-lib  bind:m  (read-frags rail)
  ;<  line=(unit @t)  bind:m  (engage rail chat input)
  ?~  line  (pure:m `[s+(say frags %'no-such-recipe' ~) 'error'])
  (pure:m `[s+u.line 'entered'])
::  +step-schema: offered only while a run is live and still movable.
::
++  step-schema
  |=  =frags:rcp-lib
  ^-  json
  %:  mk-tool-typed:clanker  'recipe_step'
    (say frags %'tool-step' ~)
    :~  ['target' 'string' (say frags %'tool-step-target' ~)]
        ['note' 'string' (say frags %'tool-step-note' ~)]
    ==
    ~['target']
  ==
::  +take-step: the model adopting the next intention. A refused move
::  comes back as the tool result rather than a crash, so it reads why
::  and names something else, at the cost of one message.
::
++  take-step
  |=  [=rail:tarball chat=@t input=json]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  ;<  frags=frags:rcp-lib  bind:m  (read-frags rail)
  =/  target=@t  (jstr:clanker input 'target')
  ;<  held=stack:rcp-lib  bind:m  (read-run rail chat)
  ?~  held  (pure:m `[s+(say frags %'no-recipe-engaged' ~) 'error'])
  ;<  rcf=(unit recipe:rcp-lib)  bind:m  (read-recipe rail name.i.held)
  ?~  rcf  (pure:m `[s+(say frags %'recipe-missing' ~) 'error'])
  =/  e=(each state:rcp-lib @t)  (move:rcp-lib u.rcf i.held target)
  ?:  ?=(%| -.e)  (pure:m `[s+p.e 'refused'])
  ::  the moved frame stays on the stack even when it has ended: +run
  ::  pops it after this batch and writes the line; here the model is
  ::  told where that leaves it
  ;<  ~  bind:m  (write-run rail chat [p.e t.held])
  ?:  asked.p.e
    (pure:m `[s+(say frags %'step-ask' ~) 'ask'])
  ?.  (done:rcp-lib p.e)
    ::  a recipe-step: the step is entered by entering its recipe
    ;<  ~  bind:m  (descend rail chat u.rcf step.p.e level.p.e 0)
    (pure:m `[s+(say frags %'step-now' ~[["step" (trip step.p.e)]]) step.p.e])
  =/  how=tape  ?:(=('abort' step.p.e) "left" "finished")
  =/  back=tape
    ?~  t.held  (trip (say frags %'step-none-left' ~))
    (trip (say frags %'step-back' ~[["name" (trip name.i.t.held)] ["step" (trip step.i.t.held)]]))
  (pure:m `[s+(say frags %'step-ended' ~[["how" how] ["name" (trip name.p.e)] ["back" back]]) step.p.e])
::  +answer-run: the user's message answers a run paused on an ask.
::
++  answer-run
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  held=stack:rcp-lib  bind:m  (read-run rail chat)
  ?~  held  (pure:m ~)
  ?.  asked.i.held  (pure:m ~)
  (write-run rail chat [(answer:rcp-lib i.held) t.held])
::  +last-kind: the k of a log's last event ('' when empty).
++  last-kind
  |=  log=(list json)
  ^-  @t
  ?~(log '' (jstr:clanker (rear log) 'k'))
::  +cancel-ask: a chat paused on an ask is stopped: the ask is answered
::  by an interrupt, so the log is at rest and nothing resumes it.
++  cancel-ask
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [road=road:tarball existed=? log=(list json)]  bind:m  (chat-log rail chat)
  ?.  =('ask' (last-kind log))  (pure:m ~)
  (write-log road existed (snoc log event-interrupt))
::  +resolve-chat: the user decided the pending ask. Append the %resolved
::  event (ids -> yes/no) and run on from there. A resolve with no ask
::  pending is dropped.
++  resolve-chat
  |=  [=rail:tarball jon=json chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [road=road:tarball existed=? log=(list json)]  bind:m  (chat-log rail chat)
  ?.  =('ask' (last-kind log))  (pure:m ~)
  =/  decisions=json
    ?.  ?=([%o *] jon)  [%o ~]
    (fall (~(get by p.jon) 'decisions') [%o ~])
  =.  log  (snoc log (event-resolved decisions))
  ;<  ~  bind:m  (write-log road existed log)
  ;<  cfg=json  bind:m  (read-json rail [%& / %'config.json'])
  =/  model=@t  =/(mo=@t (jstr:clanker cfg 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max=@ud   (jnum:clanker cfg 'max_tokens' 4.096)
  ;<  sys=@t  bind:m  (standing rail chat)
  ;<  pol=policy  bind:m  (read-policy rail chat)
  ;<  schema=json  bind:m  (list-tools rail pol)
  (run rail chat road log sys model max schema pol (provider-of cfg))
::  +turn-chat: one turn. Append the %input event to the chat log, persist
::  (so a refresh shows it even if the turn stalls), assemble this
::  clanker's standing context from its files, ask its tools nexus what it
::  advertises, then run the loop.
++  turn-chat
  |=  [=rail:tarball jon=json chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (pure:m ~)
  =/  msg=(unit @t)
    (bind (~(get by p.jon) 'message') |=(j=json ?>(?=(%s -.j) p.j)))
  ?~  msg  (pure:m ~)
  ::  the chat dir, then its log. The input is appended and persisted
  ::  FIRST: the page shows the message the moment the log is written
  ::  (its stream carries the log), not after the standing context is
  ::  assembled and the tools nexus has answered its list (a poke round
  ::  trip), which come next and only the model needs
  =/  chat-dir=path  [%chats `@ta`chat ~]
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| chat-dir]) ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] dv)  (pure:m ~)
    (make:io (nex-road:io rail [%| chat-dir]) &+empty-dir:loader)
  ;<  entered=(unit @t)  bind:m  (engage rail chat jon)
  ;<  ~  bind:m  (answer-run rail chat)
  ;<  [road=road:tarball existed=? log=(list json)]  bind:m  (chat-log rail chat)
  ::  a chat paused on an ask takes no new message until it is answered
  ::  (the model's pending tool uses must be answered first)
  ?:  =('ask' (last-kind log))  (pure:m ~)
  =?  log  ?=(^ entered)  (snoc log (event-recipe u.entered))
  =.  log  (snoc log (event-input u.msg))
  ;<  ~  bind:m  (write-log road existed log)
  ;<  cfg=json  bind:m  (read-json rail [%& / %'config.json'])
  =/  model=@t  =/(mo=@t (jstr:clanker cfg 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max=@ud   (jnum:clanker cfg 'max_tokens' 4.096)
  ;<  sys=@t  bind:m  (standing rail chat)
  ;<  pol=policy  bind:m  (read-policy rail chat)
  ;<  schema=json  bind:m  (list-tools rail pol)
  (run rail chat road log sys model max schema pol (provider-of cfg))
::  the chat log: one file per chat, its own mark (the explorer opens a
::  chat-log in the chat viewer), json inside
++  log-name  %'log.chat-log'
::  the log first (the chat pane follows it with its body: the event
::  carries the transcript), the status after (the lists follow that)
++  write-log
  |=  [road=road:tarball existed=? log=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m
    ?:  existed  (over:io road [[/ %chat-log] [%a log]])
    ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %chat-log] [%a log]] ~])
    (pure:m ~)
  (write-status road log)
::  +write-status: the chat's state as a sibling status.json, derived from
::  the log every time the log is written: {state, asks, last, recipe}.
::  The log's own mark is this app's, so a reader elsewhere (a tool,
::  another app) cannot validate it; plain json it can. state is one of
::  idle, busy (a turn runs), asking (paused on the user: `asks` lists
::  the pending tool uses, {id, name, input}, answered by
::  {action:'resolve'}), stopped. last is the latest assistant text.
::  recipe is the run beside the log, {name, step, asked}, or null.
++  write-status
  |=  [road=road:tarball log=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  status-road=(unit road:tarball)  (sibling road %'status.json')
  ?~  status-road  (pure:m ~)
  =/  status-road=road:tarball  u.status-road
  ;<  stk=stack:rcp-lib  bind:m
    =/  mr  (fiber:fiber:nexus ,stack:rcp-lib)
    =/  run-road=(unit road:tarball)  (sibling road %'run.json')
    ?~  run-road  (pure:mr ~)
    ;<  v=view:nexus  bind:mr  (peek:io u.run-road `[/ %json])
    ?.  ?=([%file *] v)  (pure:mr ~)
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.v)))) ~)
    (pure:mr (stack-from-json:rcp-lib j))
  =/  jon=json  (status-of log stk)
  ;<  v=view:nexus  bind:m  (peek:io status-road ~)
  ?:  ?=([%file *] v)  (over:io status-road [[/ %json] jon])
  ;<  *  bind:m  (make-soft:io status-road |+[[[/ %json] jon] ~])
  (pure:m ~)
::  +sibling: the log's road with the file name swapped, absolute or
::  relative; ~ for a road that names no file.
++  sibling
  |=  [road=road:tarball name=@ta]
  ^-  (unit road:tarball)
  ?-  -.road
    %&  ?.(?=(%& -.p.road) ~ `road(name.p.p name))
    %|  ?.(?=(%& -.q.p.road) ~ `road(name.p.q.p name))
  ==
++  status-of
  |=  [log=(list json) stk=stack:rcp-lib]
  ^-  json
  =/  k=@t  (last-kind log)
  =/  resp=json  (last-response log)
  =/  state=@t
    ?:  =('ask' k)  'asking'
    ?:  =('interrupt' k)  'stopped'
    ?:  (open-turn log)  'busy'
    'idle'
  =/  asks=(list json)
    ?.  =('ask' k)  ~
    =/  ids=(set @t)
      =/  l=json  (rear log)
      ?.  ?=([%o *] l)  ~
      =/  v  (~(get by p.l) 'ids')
      ?.  ?=([~ %a *] v)  ~
      (sy (murn p.u.v |=(j=json ?:(?=([%s *] j) `p.j ~))))
    %+  murn  (resp-content resp)
    |=  b=json
    ^-  (unit json)
    ?.  ?=([%o *] b)  ~
    ?.  ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))  ~
    ?.  (~(has in ids) (jstr:clanker b 'id'))  ~
    `(pairs:enjs:format ~[['id' s+(jstr:clanker b 'id')] ['name' s+(jstr:clanker b 'name')] ['input' (fall (~(get by p.b) 'input') [%o ~])]])
  =/  last=@t
    %-  crip
    %-  zing
    %+  turn  (resp-content resp)
    |=  b=json
    ?.  ?=([%o *] b)  ""
    ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
    (trip (jstr:clanker b 'text'))
  ::  input: the last thing the user said (what a chat list shows)
  =/  input=@t
    =/  ins=(list json)  (skim log |=(e=json =('input' (jstr:clanker e 'k'))))
    ?~(ins '' (jstr:clanker (rear ins) 'body'))
  %-  pairs:enjs:format
  :~  ['state' s+state]
      ['events' (numb:enjs:format (lent log))]
      ['asks' [%a asks]]
      ['last' s+last]
      ['input' s+input]
      ::  the top frame, and how deep the chat is
      :-  'recipe'
      ?~  stk  ~
      %-  pairs:enjs:format
      :~  ['name' s+name.i.stk]
          ['step' s+step.i.stk]
          ['asked' b+asked.i.stk]
          ['depth' (numb:enjs:format (lent stk))]
      ==
  ==
::  +resume: the restart contract. This fiber may be restarted at any
::  moment (a deploy, a crash); the log is the truth, so a chat whose log
::  ends mid-turn (an input or tool results not yet answered, or a
::  response still asking for tools) is picked up where it stopped. A
::  model call that was in flight is simply made again. A chat the user
::  stopped ends in an %interrupt event and is left alone.
++  resume
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /chats]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  =/  chats=(list @ta)  ~(tap in ~(key by dir.ball.dv))
  |-
  ?~  chats  (pure:m ~)
  =/  road=road:tarball  (nex-road:io rail [%& [%chats i.chats ~] log-name])
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
  =/  log=(list json)
    ?.  ?=([%file *] cur)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.(?=([%a *] j) ~ p.j)
  ?.  (open-turn log)  $(chats t.chats)
  ;<  cfg=json  bind:m  (read-json rail [%& / %'config.json'])
  =/  model=@t  =/(mo=@t (jstr:clanker cfg 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max=@ud   (jnum:clanker cfg 'max_tokens' 4.096)
  ;<  sys=@t  bind:m  (standing rail `@t`i.chats)
  ;<  pol=policy  bind:m  (read-policy rail `@t`i.chats)
  ;<  schema=json  bind:m  (list-tools rail pol)
  ;<  ~  bind:m
    (run rail `@t`i.chats road log sys model max schema pol (provider-of cfg))
  $(chats t.chats)
::  +open-turn: does this log end mid-turn? An input or tool results
::  await a response; a response that stopped for tool_use awaits its
::  results; a resolved ask awaits its tools. Anything else (a finished
::  response, an interrupt, an ask still waiting on the user, an empty
::  log) is at rest.
++  open-turn
  |=  log=(list json)
  ^-  ?
  ?~  log  %.n
  =/  last=json  (rear log)
  =/  k=@t  (jstr:clanker last 'k')
  ?|  =('input' k)
      =('results' k)
      =('resolved' k)
      &(=('response' k) =('tool_use' (jstr:clanker last 'stop')))
  ==
::  the tool policy: a verdict per tool name. See the header.
+$  policy  [default=@t allow=(set @t) ask=(set @t) deny=(set @t)]
++  no-policy  `policy`['allow' ~ ~ ~]
::  +parse-policy: tools.json as a policy; a missing or malformed file
::  is no policy (everything allowed), a file with no default asks. An
::  "ask" list is accepted too (a name the default would allow, held to
::  asking) though the usual file needs only allow and deny.
++  parse-policy
  |=  jon=json
  ^-  (unit policy)
  ?.  ?=([%o *] jon)  ~
  ::  an EMPTY object is no policy: a missing tools.json reads back as {}
  ::  (+read-json), and "no file" must mean everything allowed, not "a file
  ::  with no default", which asks
  ?:  =(~ p.jon)  ~
  =/  strs
    |=  k=@t
    ^-  (set @t)
    =/  v  (~(get by p.jon) k)
    ?.  ?=([~ %a *] v)  ~
    (sy (murn p.u.v |=(j=json ?:(?=([%s *] j) `p.j ~))))
  =/  d=@t  (jstr:clanker jon 'default')
  =/  d=@t  ?:(|(=('allow' d) =('ask' d) =('deny' d)) d 'ask')
  `[d (strs 'allow') (strs 'ask') (strs 'deny')]
::  +read-policy: the clanker's policy and the chat's, folded into one
::  that yields, per tool, the stricter of the two verdicts.
++  read-policy
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,policy)
  ^-  form:m
  ;<  base=json  bind:m  (read-json rail [%& / %'tools.json'])
  ;<  own=json  bind:m  (read-json rail [%& [%chats `@ta`chat ~] %'tools.json'])
  =/  b=policy  (fall (parse-policy base) no-policy)
  =/  c=policy  (fall (parse-policy own) no-policy)
  =/  names=(set @t)
    %-  ~(gas in *(set @t))
    ;:  weld
      ~(tap in allow.b)  ~(tap in ask.b)  ~(tap in deny.b)
      ~(tap in allow.c)  ~(tap in ask.c)  ~(tap in deny.c)
    ==
  =/  out=policy  [(stricter default.b default.c) ~ ~ ~]
  %-  pure:m
  %+  roll  ~(tap in names)
  |=  [n=@t acc=_out]
  =/  v=@t  (stricter (verdict b n) (verdict c n))
  ?:  =('deny' v)  acc(deny (~(put in deny.acc) n))
  ?:  =('ask' v)  acc(ask (~(put in ask.acc) n))
  acc(allow (~(put in allow.acc) n))
++  stricter
  |=  [x=@t y=@t]
  ^-  @t
  =/  rank  |=(v=@t ^-(@ud ?:(=('deny' v) 2 ?:(=('ask' v) 1 0))))
  ?:((gte (rank x) (rank y)) x y)
::  +verdict: one tool's verdict under a policy: deny, else ask, else
::  allow, else the default.
++  verdict
  |=  [p=policy name=@t]
  ^-  @t
  ?:  (~(has in deny.p) name)  'deny'
  ?:  (~(has in ask.p) name)  'ask'
  ?:  (~(has in allow.p) name)  'allow'
  default.p
::  +standing: the clanker's standing context for one chat, assembled
::  from its files: system.md, then the chat's own system.md if it has
::  one (the chat's role on top of the clanker's identity), then every
::  skill, then every memory. Each file is a titled section so the model
::  (and the context panel) can tell them apart. v1 inlines everything; a
::  budget comes later and lives here.
++  standing
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  sys=@t  bind:m  (read-text rail [%& /prompts %'main.md'])
  ;<  chat-sys=@t  bind:m  (read-text rail [%& [%chats `@ta`chat ~] %'system.md'])
  ;<  skills=(list [@ta @t])  bind:m  (read-dir-texts rail /skills)
  ;<  memories=(list [@ta @t])  bind:m  (read-dir-texts rail /memories)
  ;<  recipes=(list @t)  bind:m  (recipe-names rail)
  ;<  frags=frags:rcp-lib  bind:m  (read-frags rail)
  =/  section
    |=  [title=tape files=(list [n=@ta body=@t])]
    ^-  tape
    =/  out=tape
      %-  zing
      %+  turn  files
      |=([n=@ta body=@t] "\0a## {(trip n)}\0a{(trip body)}\0a")
    ?:  =("" out)  ""
    (weld "\0a\0a# {title}\0a" out)
  %-  pure:m
  %-  crip
  ;:  weld
    (trip sys)
    ?:(=('' chat-sys) "" "\0a\0a# This chat\0a{(trip chat-sys)}\0a")
    (skills-section frags skills)
    (section "Memories" memories)
    (recipes-section frags recipes)
  ==
::  +skills-section: the skills by name and first line. The standing
::  prompt carries only this list; the model reads a skill's body with
::  read_file when it applies.
::
++  skills-section
  |=  [=frags:rcp-lib files=(list [n=@ta body=@t])]
  ^-  tape
  ?~  files  ""
  =/  rows=tape
    %-  zing
    %+  turn  files
    |=  [n=@ta body=@t]
    (trip (say frags %'skill-row' ~[["name" (trip n)] ["about" (first-line body)]]))
  (trip (say frags %'skills.md' ~[["skills" rows]]))
::  +first-line: a file's first non-empty line, without a leading '# '
++  first-line
  |=  body=@t
  ^-  tape
  =/  lines=(list tape)  (turn (to-wain:format body) trip)
  |-  ^-  tape
  ?~  lines  ""
  =/  l=tape  i.lines
  ?:  =("" l)  $(lines t.lines)
  |-  ^-  tape
  ?:  ?=([%'#' *] l)  $(l t.l)
  ?:  ?=([%' ' *] l)  $(l t.l)
  l
::  +recipes-section: what a recipe is and how it is engaged, in the
::  standing prompt of a clanker that holds any. The names are listed;
::  the recipes themselves are read through the tip once entered.
::
++  recipes-section
  |=  [=frags:rcp-lib names=(list @t)]
  ^-  tape
  ?~  names  ""
  =/  listed=tape  (zing (join ", " (turn names |=(n=@t (trip n)))))
  (trip (say frags %'recipes.md' ~[["recipes" listed]]))
::  +list-tools: what this clanker's tools nexus advertises, as an
::  Anthropic tool schema array, plus the engine's own `spawn`. The tools
::  nexus answers a {cmd:'list'} poke by poking the array back to us.
++  list-tools
  |=  [=rail:tarball pol=policy]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ::  the list comes back as a poke; one lost across a reboot of the tools
  ::  nexus must not park this fiber forever (every later poke would be
  ::  skipped behind it), so ask again after a deadline, a few times
  ;<  listed=(list json)  bind:m
    =/  mt  (fiber:fiber:nexus ,(list json))
    =/  tries=@ud  0
    |-  ^-  form:mt
    ;<  ~  bind:mt
      (poke:io (nex-road:io rail [%& /tools %'main.sig']) [[/ %json] (pairs:enjs:format ~[['cmd' s+'list']])])
    ;<  got=(unit (list json))  bind:mt
      %^  (with-timeout:io ,(list json))  /tool-list  ~s20
      take-list
    ?^  got  (pure:mt u.got)
    ?:  (gte tries 3)  (pure:mt ~)
    $(tries +(tries))
  =/  tools=(list json)
    %+  turn  listed
    |=  t=json
    ^-  json
    ::  the tools nexus speaks {name, description, parameters, required};
    ::  Anthropic wants input_schema
    ?.  ?=([%o *] t)  t
    %-  pairs:enjs:format
    :~  ['name' (fall (~(get by p.t) 'name') s+'')]
        ['description' (fall (~(get by p.t) 'description') s+'')]
        :-  'input_schema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            ['properties' (fall (~(get by p.t) 'parameters') [%o ~])]
            ['required' (fall (~(get by p.t) 'required') [%a ~])]
        ==
    ==
  ::  a denied tool is not advertised: the model never sees it
  =/  all=(list json)  (snoc tools spawn-schema)
  %-  pure:m
  :-  %a
  %+  skip  all
  |=(t=json =('deny' (verdict pol (jstr:clanker t 'name'))))
::  +take-list: the list reply, a json array poked to main.sig. Anything
::  else that lands meanwhile is skipped (re-offered to the serve loop).
++  take-list
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    =/  jon=json  (fall (mole |.(!<(json q.sage.u.in))) *json)
    ?.  ?=([%a *] jon)  [%skip ~]
    [%done p.jon]
  ==
::  +is-clanker-seg: a path segment that names a clanker dir.
++  is-clanker-seg
  |=  n=@ta
  ^-  ?
  =/  t=tape  (trip n)
  =/  len=@ud  (lent t)
  &((gth len 8) =(".clanker" (slag (sub len 8) t)))
::  +spawn-schema: the one tool the engine provides itself.
++  spawn-schema
  ^-  json
  %:  mk-tool-typed:clanker  'spawn'
    'Delegate a task to a nested clanker of your own. It lives beneath this chat with its own prompt, memories and tools, and its full conversation is kept there. Reusing a name continues that clanker. Returns its reply.'
    :~  ['name' 'string' 'kebab-case name of the nested clanker']
        ['system' 'string' 'its standing prompt (used when it is created)']
        ['message' 'string' 'the task or question to send it']
    ==
    ~['name' 'message']
  ==
::  +run: the agent loop over the event log, driven by its tail. A log
::  ending in a response that asked for tools runs them and appends the
::  %results event; anything else assembles the request, sends it and
::  appends the %response event. Each event is persisted as it lands, so
::  a restart resumes from the tail (+resume). An interrupt (~ from the
::  proxy / tools) appends an %interrupt event and stops: the log is
::  intact and at rest.
++  run
  |=  [=rail:tarball chat=@t road=road:tarball log=(list json) sys=@t model=@t max=@ud schema=json pol=policy pro=provider:clanker]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  frags=frags:rcp-lib  bind:m  (read-frags rail)
  |-  ^-  form:m
  =/  last=json  ?~(log [%o ~] (rear log))
  =/  k=@t  (jstr:clanker last 'k')
  ::  paused on the user: at rest until a resolve or a stop
  ?:  =('ask' k)  (pure:m ~)
  ::  the tool uses to run now: the last response's, straight (when it
  ::  just landed) or as the user resolved them (when the tail is the
  ::  resolved event; the response is the one before the ask)
  =/  resolved=(unit json)  ?.(=('resolved' k) ~ `last)
  =/  resp=json
    ?^  resolved  (last-response log)
    ?.  &(=('response' k) =('tool_use' (jstr:clanker last 'stop')))  [%o ~]
    last
  =/  tool-uses=(list json)
    %+  skim  (resp-content resp)
    |=(b=json ?&(?=([%o *] b) ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))))
  ?^  tool-uses
    ::  a use whose tool asks first pauses the turn, unless the user
    ::  already answered (the resolved tail)
    =/  asks=(list @t)
      ?^  resolved  ~
      %+  murn  tool-uses
      |=(tu=json ?:(=('ask' (verdict pol (jstr:clanker tu 'name'))) `(jstr:clanker tu 'id') ~))
    ?^  asks
      (write-log road %.y (snoc log (event-ask asks)))
    =/  declined=(set @t)
      ?~  resolved  ~
      ?.  ?=([%o *] u.resolved)  ~
      =/  d  (~(get by p.u.resolved) 'decisions')
      ?.  ?=([~ %o *] d)  ~
      %-  sy
      %+  murn  ~(tap by p.u.d)
      |=([id=@t v=json] ?:(?=([%b %.n] v) `id ~))
    ;<  before=stack:rcp-lib  bind:m  (read-run rail chat)
    ;<  ran=(unit [(list json) (list json)])  bind:m  (run-tools rail chat tool-uses declined)
    ?~  ran
      (write-log road %.y (snoc log event-interrupt))
    =.  log  (snoc log (event-results -.u.ran +.u.ran))
    ::  what the tools did to the recipe stack is read from the stack,
    ::  not from their results: frames that appeared are entries, a top
    ::  frame that has ended is popped, and each is a line in the log
    ;<  after=stack:rcp-lib  bind:m  (read-run rail chat)
    =/  grew=@ud  ?:((gth (lent after) (lent before)) (sub (lent after) (lent before)) 0)
    =.  log
      =/  new=stack:rcp-lib  (flop (scag grew after))
      =/  i=@ud  grew
      |-  ^-  _log
      ?~  new  log
      =/  outer=stack:rcp-lib  (slag i after)
      %=  $
        new  t.new
        i    (dec i)
        log  (snoc log (event-recipe (entering-line frags name.i.new step.i.new level.i.new outer)))
      ==
    =/  settled=[stk=stack:rcp-lib lines=(list json)]
      =/  stk=stack:rcp-lib  after
      =|  lines=(list json)
      |-  ^-  [stack:rcp-lib (list json)]
      ?~  stk  [stk (flop lines)]
      ?.  (done:rcp-lib i.stk)  [stk (flop lines)]
      =/  how=tape  ?:(=('abort' step.i.stk) "left" "finished")
      =/  back=tape
        ?~  t.stk  ""
        (trip (say frags %'ended-back' ~[["name" (trip name.i.t.stk)] ["step" (trip step.i.t.stk)]]))
      =/  line=@t  (say frags %'ended' ~[["how" how] ["name" (trip name.i.stk)] ["back" back]])
      $(stk t.stk, lines [(event-recipe line) lines])
    ;<  ~  bind:m
      ?:  =(stk.settled after)  (pure:(fiber:fiber:nexus ,~) ~)
      (write-run rail chat stk.settled)
    =.  log  (weld log lines.settled)
    ::  an ask taken ends the turn here: the question is the text the
    ::  model wrote before naming ask, and calling it again would only
    ::  have it ask twice. The waiting line is the tail at rest; the
    ::  user's next message runs on from it.
    =/  asked=?
      ?~  stk.settled  |
      ?.  asked.i.stk.settled  |
      ?~  before  &
      !asked.i.before
    ?:  asked
      =/  top=state:rcp-lib  (head stk.settled)
      =/  line=@t  (say frags %'waiting' ~[["name" (trip name.top)] ["step" (trip step.top)]])
      (write-log road %.y (snoc log (event-recipe line)))
    ;<  ~  bind:m  (write-log road %.y log)
    $
  ;<  messages=(list json)  bind:m  (inline-blobs rail (assemble frags log))
  ::  a chat following a recipe carries its tip on the END of the last
  ::  message, rendered from the run AFTER this message is spent, so what
  ::  it reads is what it has left. The tip never enters the log: the log
  ::  is written from events and `sent` is a local.
  ;<  held=stack:rcp-lib  bind:m  (read-run rail chat)
  ;<  rcf=(unit recipe:rcp-lib)  bind:m
    ?~  held  (pure:(fiber:fiber:nexus ,(unit recipe:rcp-lib)) ~)
    (read-recipe rail name.i.held)
  ::  one message spends every frame: the outer steps stay occupied
  ::  while the inner recipe runs
  =/  spun=stack:rcp-lib  (tick-all:rcp-lib held)
  ;<  ~  bind:m
    ?~  spun  (pure:(fiber:fiber:nexus ,~) ~)
    (write-run rail chat spun)
  =/  tip-text=@t
    ?~  rcf  ''
    ?~  spun  ''
    ?:  (done:rcp-lib i.spun)  ''
    ?.  (stuck:rcp-lib u.rcf i.spun)  (tip-in:rcp-lib frags u.rcf i.spun t.spun)
    (spent:rcp-lib frags)
  =/  sent=(list json)
    ?:(=('' tip-text) messages (append-tip:ck messages tip-text))
  ::  step is on offer while a run is live and still movable; enter
  ::  whenever there are recipes to enter (entering nests)
  ;<  names=(list @t)  bind:m  (recipe-names rail)
  =/  kit=json
    ?.  ?=([%a *] schema)  schema
    =/  ts=(list json)  p.schema
    =?  ts  !=('' tip-text)  (snoc ts (step-schema frags))
    =?  ts  ?=(^ names)  (snoc ts (enter-schema frags names))
    [%a ts]
  ;<  answered=(unit json)  bind:m
    %+  call-proxy:ck  link.pro
    (encode-for pro model max sys kit sent)
  ?~  answered
    (write-log road %.y (snoc log event-interrupt))
  =/  resp=json  u.answered
  =/  content-arr=(list json)  (decode pro resp)
  =/  stop=@t  (stop-for pro resp)
  =.  log  (snoc log (event-response content-arr stop (usage-for pro resp)))
  ;<  ~  bind:m  (write-log road %.y log)
  ?.  =('tool_use' stop)  (pure:m ~)
  $
::  +run-tools: execute each tool_use; `spawn` is the engine's own, every
::  other name goes to this clanker's tools nexus. Yields the tool_result
::  blocks (for the model) and trace entries (for the UI). ~ on interrupt.
++  run-tools
  |=  [=rail:tarball chat=@t tool-uses=(list json) declined=(set @t)]
  =/  m  (fiber:fiber:nexus ,(unit [(list json) (list json)]))
  ^-  form:m
  =|  results=(list json)
  =|  trace=(list json)
  |-  ^-  form:m
  ?~  tool-uses  (pure:m `[(flop results) (flop trace)])
  =*  tu  i.tool-uses
  ?.  ?=([%o *] tu)  $(tool-uses t.tool-uses)
  =/  tid=@t   (jstr:clanker tu 'id')
  =/  name=@t  (jstr:clanker tu 'name')
  =/  input=json  (fall (~(get by p.tu) 'input') [%o ~])
  ;<  outcome=(unit [json @t])  bind:m
    ::  a use the user declined does not run; the model is told so
    ?:  (~(has in declined) tid)
      =/  mo  (fiber:fiber:nexus ,(unit [json @t]))
      (pure:mo `[s+'The user declined to run this tool. Do not retry it; ask, or go on without it.' 'declined'])
    ?:  =('spawn' name)  (spawn rail chat input)
    ?:  =('recipe_step' name)  (take-step rail chat input)
    ?:  =('recipe_enter' name)  (take-enter rail chat input)
    (call-tool rail name input tid)
  ?~  outcome  (pure:m ~)
  =/  result=json
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+tid]
        ['content' -.u.outcome]
    ==
  =/  note=@t  +.u.outcome
  =/  te=json
    (pairs:enjs:format ~[['tool' s+name] ['arg' s+(first-arg:ck input)] ['note' s+note]])
  $(tool-uses t.tool-uses, results [result results], trace [te trace])
::  +spawn: a nested clanker beneath THIS chat. Made on first use as a
::  nexus of this same kind (its own on-load lays out its tree and seeds
::  its tools); no weir of its own, so it is bounded by ours. Then one
::  turn: poke its main.sig and wait for its reply event.
++  spawn
  |=  [=rail:tarball chat=@t input=json]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  =/  name=@t  (jstr:clanker input 'name')
  =/  msg=@t   (jstr:clanker input 'message')
  =/  sys=@t   (jstr:clanker input 'system')
  ?:  |(=('' name) =('' msg))
    (pure:m `[s+'spawn needs a name and a message' 'error'])
  ::  depth guard: a clanker three deep spawns no further
  =/  depth=@ud  (lent (skim path.rail is-clanker-seg))
  ?:  (gte depth 3)
    (pure:m `[s+'spawn refused: nesting is already three clankers deep' 'error'])
  =/  dir=path  [%chats `@ta`chat (crip "{(trip name)}.clanker") ~]
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
  =/  mu  (fiber:fiber:nexus ,~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] dv)  (pure:mu ~)
    =/  b=bole:tarball  [`[`[/clanker %agent] ~ %.n ~] ~]
    =.  b  (~(put bo:tarball b) [/ %'config.json'] [[/ %json] default-config])
    =.  b  (~(put bo:tarball b) [/prompts %'main.md'] [[/ %mime] [/text/markdown (as-octs:mimes:html sys)]])
    (make:io (nex-road:io rail [%| dir]) &+b)
  =/  child-log=road:tarball  (nex-road:io rail [%& (weld dir /chats/main) log-name])
  ;<  *  bind:m  (keep:io /spawn child-log ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  (nex-road:io rail [%& dir %'main.sig'])  [/ %json]
    (pairs:enjs:format ~[['chat' s+'main'] ['message' s+msg]])
  ;<  reply=(unit @t)  bind:m  (await-reply child-log)
  ;<  ~  bind:m  (drop:io /spawn child-log)
  ?~  reply  (pure:m ~)
  (pure:m `[s+u.reply (crip "{(trip name)}")])
::  +await-reply: wait for the child's log to end in a finished response,
::  and return its text. ~ on interrupt.
++  await-reply
  |=  log-road=road:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  |-
  ;<  raw=(unit wave:nexus)  bind:m  (take-news-or-interrupt:ck /spawn)
  ?~  raw  (pure:m ~)
  ;<  lv=view:nexus  bind:m  (peek:io log-road `[/ %json])
  ?.  ?=([%file *] lv)  $
  =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.lv)))) [%a ~])
  ?.  ?=([%a ^] j)  $
  =/  last=json  (rear p.j)
  ?.  &(?=([%o *] last) =('response' (jstr:clanker last 'k')))  $
  ?:  =('tool_use' (jstr:clanker last 'stop'))  $
  =/  text=tape
    %-  zing
    %+  turn  (resp-content last)
    |=  b=json
    ?.  ?=([%o *] b)  ""
    ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
    (trip (jstr:clanker b 'text'))
  (pure:m `(crip text))
::  +call-tool: one run through this clanker's tools nexus (the calls
::  protocol: poke main.sig, await the run grub, read the result). The
::  run grub is KEPT, named by the time it was made and the tool_use id
::  (<time>..<id>), so a run can be inspected after the fact; +prune-runs
::  bounds the history. The id makes the call idempotent across a restart
::  of this fiber (a deploy, a crash: +resume re-runs the open turn): a
::  run already made for this use is picked up, never made again. Done,
::  its result is read; still running (runs restart with their nexus),
::  it is awaited.
++  call-tool
  |=  [=rail:tarball name=@t args=json tid=@t]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  ;<  prior=(unit [name=@ta st=(unit tool-state:nex-tools)])  bind:m  (find-run rail tid)
  =/  main-road=road:tarball  (nex-road:io rail [%& /tools %'main.sig'])
  ?:  ?&(?=(^ prior) ?=(^ st.u.prior) =(%done step.u.st.u.prior))
    (outcome-of rail main-road name.u.prior update.u.st.u.prior)
  ;<  now=@da  bind:m  get-time:io
  =/  run-name=@ta
    ?^  prior  name.u.prior
    (crip "{(trip (scot %da now))}..{(trip tid)}")
  =/  run-road=road:tarball   (nex-road:io rail [%& /tools/runs run-name])
  ;<  *  bind:m  (keep:io /tool run-road ~)
  ;<  ~  bind:m
    =/  mu  (fiber:fiber:nexus ,~)
    ?^  prior  (pure:mu ~)
    %-  poke:io
    :+  main-road  [/ %json]
    %-  pairs:enjs:format
    :~  ['cmd' s+'call']  ['id' s+run-name]  ['name' s+name]  ['arguments' args]
    ==
  ;<  timed=(unit (unit json))  bind:m  (await-run rail run-road run-name)
  ;<  ~  bind:m  (drop:io /tool run-road)
  ;<  ~  bind:m  (prune-runs rail)
  ?~  timed  (pure:m ~)
  (outcome-of rail main-road run-name u.timed)
::  +outcome-of: a run's result as the model's tool_result content and the
::  trace note. Bytes (a picture, a document) never enter the log: they go
::  to files/blobs/<sha256>.<ext> under this clanker, content-addressed,
::  and the log keeps a reference ({type, blob, media_type}) that +inline-
::  blobs expands into the request at call time. The run grub, which still
::  holds the bytes, is culled: the blob is the record.
++  outcome-of
  |=  [=rail:tarball main-road=road:tarball run-name=@ta res=(unit json)]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  ?.  ?&(?=([~ %o *] res) ?=([~ %s %'mime'] (~(get by p.u.res) 'type')))
    (pure:m `(tool-outcome res))
  =/  mt=@t   (jstr:clanker u.res 'media_type')
  =/  b64=@t  (jstr:clanker u.res 'data')
  ;<  blob=(unit @ta)  bind:m  (stash-blob rail mt b64)
  ;<  ~  bind:m
    %-  poke:io
    [main-road [/ %json] (pairs:enjs:format ~[['cmd' s+'cull'] ['id' s+run-name]])]
  ?~  blob  (pure:m `[s+'(the bytes did not decode)' 'error'])
  =/  kind=@t  ?:(=('application/pdf' mt) 'document' 'image')
  =/  block=json
    (pairs:enjs:format ~[['type' s+kind] ['blob' s+u.blob] ['media_type' s+mt]])
  =/  size=@ud  (div (mul 3 (met 3 b64)) 4)
  (pure:m `[[%a ~[block]] (crip "{(trip mt)}, {(a-co:co size)} bytes, files/blobs/{(trip u.blob)}")])
::  +stash-blob: bytes (base64, as the tools nexus hands them) into
::  files/blobs/<sha256>.<ext> under this clanker; the name, or ~ when
::  they do not decode. The same bytes land once.
++  stash-blob
  |=  [=rail:tarball mt=@t b64=@t]
  =/  m  (fiber:fiber:nexus ,(unit @ta))
  ^-  form:m
  =/  bytes=(unit octs)  (de:base64:mimes:html b64)
  ?~  bytes  (pure:m ~)
  =/  ext=tape
    ?:  =('image/png' mt)  "png"
    ?:  =('image/jpeg' mt)  "jpg"
    ?:  =('image/gif' mt)  "gif"
    ?:  =('image/webp' mt)  "webp"
    ?:  =('application/pdf' mt)  "pdf"
    "bin"
  =/  name=@ta  (crip "{((x-co:co 64) (shay p.u.bytes q.u.bytes))}.{ext}")
  ;<  ~  bind:m  (ensure-dir rail /files)
  ;<  ~  bind:m  (ensure-dir rail /files/blobs)
  ;<  *  bind:m
    (make-soft:io (nex-road:io rail [%& /files/blobs name]) |+[[[/ %mime] [(mite-of mt) u.bytes]] ~])
  (pure:m `name)
++  ensure-dir
  |=  [=rail:tarball dir=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
  ?:  ?=([%ball *] v)  (pure:m ~)
  (make:io (nex-road:io rail [%| dir]) &+empty-dir:loader)
::  +mite-of: "image/png" as a mite
++  mite-of
  |=  mt=@t
  ^-  mite
  =/  t=tape  (trip mt)
  ?~  sl=(find "/" t)  ~[mt]
  ~[(crip (scag u.sl t)) (crip (slag +(u.sl) t))]
::  +inline-blobs: the request's attachment references, read from
::  files/blobs and inlined as base64 source blocks. Only the request
::  carries bytes; the log never does.
++  inline-blobs
  |=  [=rail:tarball messages=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  =|  out=(list json)
  |-  ^-  form:m
  ?~  messages  (pure:m (flop out))
  ;<  msg=json  bind:m  (inline-message rail i.messages)
  $(messages t.messages, out [msg out])
++  inline-message
  |=  [=rail:tarball msg=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?.  ?=([%o *] msg)  (pure:m msg)
  =/  c  (~(get by p.msg) 'content')
  ?.  ?=([~ %a *] c)  (pure:m msg)
  ;<  blocks=(list json)  bind:m  (inline-blocks rail p.u.c)
  (pure:m [%o (~(put by p.msg) 'content' [%a blocks])])
++  inline-blocks
  |=  [=rail:tarball blocks=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  =|  out=(list json)
  |-  ^-  form:m
  ?~  blocks  (pure:m (flop out))
  ;<  b=json  bind:m  (inline-block rail i.blocks)
  $(blocks t.blocks, out [b out])
::  a tool_result's content is itself a block list: recurse; a block with
::  a blob becomes a base64 source block; anything else passes as is
++  inline-block
  |=  [=rail:tarball b=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?.  ?=([%o *] b)  (pure:m b)
  =/  c  (~(get by p.b) 'content')
  ?:  ?=([~ %a *] c)
    ;<  inner=(list json)  bind:m  (inline-blocks rail p.u.c)
    (pure:m [%o (~(put by p.b) 'content' [%a inner])])
  =/  blob  (~(get by p.b) 'blob')
  ?.  ?=([~ %s *] blob)  (pure:m b)
  ;<  v=view:nexus  bind:m  (peek:io (nex-road:io rail [%& /files/blobs `@ta`p.u.blob]) `[/ %mime])
  ?.  &(?=([%file *] v) !(is-boom:tarball sang.v))
    (pure:m (pairs:enjs:format ~[['type' s+'text'] ['text' s+(crip "[attachment missing: files/blobs/{(trip p.u.blob)}]")]]))
  =/  mim=mime  !<(mime (need-vase:tarball sang.v))
  %-  pure:m
  %-  pairs:enjs:format
  :~  ['type' (fall (~(get by p.b) 'type') s+'image')]
      :-  'source'
      %-  pairs:enjs:format
      :~  ['type' s+'base64']
          ['media_type' s+(jstr:clanker b 'media_type')]
          ['data' s+(en:base64:mimes:html q.mim)]
      ==
  ==
::  +find-run: the run already made for a tool_use id, if any: its name
::  (<time>..<id>) and its state (~ when the grub does not read).
++  find-run
  |=  [=rail:tarball tid=@t]
  =/  m  (fiber:fiber:nexus ,(unit [name=@ta st=(unit tool-state:nex-tools)]))
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /tools/runs]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  ?~  fil.ball.dv  (pure:m ~)
  =/  tail=tape  "..{(trip tid)}"
  =/  tl=@ud  (lent tail)
  =/  hit=(unit [@ta sang:tarball])
    =/  all=(list [n=@ta =sang:tarball *])  ~(tap by contents.u.fil.ball.dv)
    |-  ^-  (unit [@ta sang:tarball])
    ?~  all  ~
    =/  t=tape  (trip n.i.all)
    =/  l=@ud  (lent t)
    ?:  &((gte l tl) =(tail (slag (sub l tl) t)))  `[n.i.all sang.i.all]
    $(all t.all)
  ?~  hit  (pure:m ~)
  =/  res  (mule |.(!<(tool-state:nex-tools (need-vase:tarball +.u.hit))))
  (pure:m `[-.u.hit ?:(?=(%& -.res) `p.res ~)])
::  +tool-outcome: a run's result as the model's tool_result content and
::  the trace note.
++  tool-outcome
  |=  res=(unit json)
  ^-  [json @t]
  ?~  res  [s+'(no result)' 'error']
  ?.  ?=([%o *] u.res)  [s+'(bad result)' 'error']
  ?:  ?=([~ %s %'error'] (~(get by p.u.res) 'type'))
    =/  msg  (fall (bind (~(get by p.u.res) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'error')
    [s+msg 'error']
  ?:  ?=([~ %s %'mime'] (~(get by p.u.res) 'type'))
    =/  mt=@t   (jstr:clanker u.res 'media_type')
    =/  b64=@t  (jstr:clanker u.res 'data')
    =/  kind=@t  ?:(=('application/pdf' mt) 'document' 'image')
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+kind]
          :-  'source'
          %-  pairs:enjs:format
          :~  ['type' s+'base64']
              ['media_type' s+mt]
              ['data' s+b64]
          ==
      ==
    [[%a ~[block]] (crip "{(trip mt)}, {(a-co:co (div (mul 3 (met 3 b64)) 4))} bytes")]
  =/  txt=@t  (fall (bind (~(get by p.u.res) 'text') |=(j=json ?>(?=(%s -.j) p.j))) '')
  [s+txt (crip "{(a-co:co (met 3 txt))} bytes")]
::  +prune-runs: keep the newest `keep-runs` runs; cull the rest. Run
::  names are @da, so name order is time order. The culls are %cull
::  pokes to the tools nexus (its runs are its grubs).
++  keep-runs  50
++  prune-runs
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /tools/runs]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  ?~  fil.ball.dv  (pure:m ~)
  =/  names=(list @ta)  (sort ~(tap in ~(key by contents.u.fil.ball.dv)) aor)
  =/  n=@ud  (lent names)
  ?:  (lte n keep-runs)  (pure:m ~)
  =/  old=(list @ta)  (scag (sub n keep-runs) names)
  =/  main-road=road:tarball  (nex-road:io rail [%& /tools %'main.sig'])
  |-
  ?~  old  (pure:m ~)
  ;<  ~  bind:m
    %-  poke:io
    [main-road [/ %json] (pairs:enjs:format ~[['cmd' s+'cull'] ['id' s+i.old]])]
  $(old t.old)
::
::  +await-run: the run grub's %done, taken from its change notices, but
::  never only from them: a notice lost across a reboot would park this
::  fiber for good, so every few seconds the run is simply read, and a
::  run that is gone (the tools nexus reseeded, its runs/ with it) is
::  given up on as an error rather than waited on. ~ on interrupt.
::    A run whose FIBER HAS BANGED is the third ending, and it used to be no
::    ending at all: the grub is still there and still readable, its step just
::    never becomes %done, so the two tests below (gone? done?) both missed it
::    and this waited on a dead run for as long as the chat lived. A banged run
::    is now read off the runs directory and answered as an error, so the turn
::    finishes and the chat says what happened instead of sitting busy.
++  await-run
  |=  [=rail:tarball run-road=road:tarball run-name=@ta]
  =/  m  (fiber:fiber:nexus ,(unit (unit json)))
  ^-  form:m
  =/  misses=@ud  0
  |-
  ;<  timed=(unit (unit wave:nexus))  bind:m
    %^  (with-timeout:io ,(unit wave:nexus))  /run-poll  ~s5
    (take-news-or-interrupt:ck /tool)
  ?:  ?=([~ ~] timed)  (pure:m ~)
  ;<  =view:nexus  bind:m  (peek:io run-road ~)
  ?.  ?=([%file *] view)
    ?:  (gte misses 6)
      (pure:m `[~ (pairs:enjs:format ~[['type' s+'error'] ['message' s+'the tool run disappeared (the tools nexus reloaded); try again']])])
    $(misses +(misses))
  =/  res  (mule |.(!<(tool-state:nex-tools (need-vase:tarball sang.view))))
  ?:  ?=(%| -.res)  $
  ?.  =(%done step.p.res)
    ::  not done — but is it ever going to be? A banged fiber leaves the run
    ::  readable and stuck at whatever step it reached.
    ;<  banged=(unit tang)  bind:m  (run-bang rail run-name)
    ?~  banged  $
    =/  why=tape  (zing (turn (scag 1 u.banged) |=(=tank ~(ram re tank))))
    %-  pure:m
    :^  ~  ~  %o
    %-  malt
    :~  ['type' s+'error']
        ['message' s+(crip "the tool crashed: {why}")]
    ==
  (pure:m `update.p.res)
::  +run-bang: the crash of a run's own fiber, if it has one. The runs
::  directory carries a bang per grub; a run that banged will never write
::  another step, so this is the only way to tell waiting from dead.
++  run-bang
  |=  [=rail:tarball run-name=@ta]
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek-shallow:io (nex-road:io rail [%| /tools/runs]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  ?~  fil.ball.dv  (pure:m ~)
  =/  got  (~(get by contents.u.fil.ball.dv) run-name)
  ?~  got  (pure:m ~)
  (pure:m bang.u.got)
::  +assemble: THE context policy. Fold the event log into Anthropic
::  messages. v1 = append-all, with one repair: the API requires every
::  tool_use in an assistant turn to be answered by a tool_result in the
::  next user turn. A turn stopped between the two (an ask the user
::  cancelled, an interrupt mid-tools) leaves the call unanswered in the
::  log, and every later request would be refused. So a tool_use with no
::  results event after it is answered here with a synthetic result
::  saying it was stopped, folded into the next user turn.
++  assemble
  |=  [=frags:rcp-lib log=(list json)]
  ^-  (list json)
  =/  stopped
    |=  ids=(list @t)
    ^-  (list json)
    %+  turn  ids
    |=  id=@t
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+id]
        ['content' s+'This tool call was stopped by the user before it ran.']
    ==
  =|  out=(list json)
  =|  pending=(list @t)
  |-  ^-  (list json)
  ?~  log
    ::  a trailing tool_use is the live turn (+run answers it); leave it
    (flop out)
  =*  ev  i.log
  ?.  ?=([%o *] ev)  $(log t.log)
  =/  k=@t  (jstr:clanker ev 'k')
  ?:  =('input' k)
    =/  text=json  (pairs:enjs:format ~[['type' s+'text'] ['text' s+(jstr:clanker ev 'body')]])
    =/  content=json
      ?~  pending  s+(jstr:clanker ev 'body')
      a+(snoc (stopped pending) text)
    %=  $
      log      t.log
      pending  ~
      out      [(pairs:enjs:format ~[['role' s+'user'] ['content' content]]) out]
    ==
  ::  a recipe event reaches the model as a tagged line on the user's
  ::  side, the register the tip uses, so it reads as the harness speaking
  ?:  =('recipe' k)
    =/  text=json
      %-  pairs:enjs:format
      :~  ['type' s+'text']
          ['text' s+(say frags %'event' ~[["body" (trip (jstr:clanker ev 'body'))]])]
      ==
    =/  content=json
      ?~  pending  a+~[text]
      a+(snoc (stopped pending) text)
    %=  $
      log      t.log
      pending  ~
      out      [(pairs:enjs:format ~[['role' s+'user'] ['content' content]]) out]
    ==
  ?:  =('results' k)
    =/  c=(unit json)  (~(get by p.ev) 'content')
    ?.  ?=([~ %a *] c)  $(log t.log)
    %=  $
      log      t.log
      pending  ~
      out      [(pairs:enjs:format ~[['role' s+'user'] ['content' u.c]]) out]
    ==
  ?:  =('response' k)
    =/  c=(unit json)  (~(get by p.ev) 'content')
    ?.  ?=([~ %a *] c)  $(log t.log)
    ::  a response after an unanswered tool_use: answer it first
    =?  out  ?=(^ pending)
      [(pairs:enjs:format ~[['role' s+'user'] ['content' a+(stopped pending)]]) out]
    =/  uses=(list @t)
      %+  murn  p.u.c
      |=  b=json
      ?.  ?=([%o *] b)  ~
      ?.  ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))  ~
      `(jstr:clanker b 'id')
    %=  $
      log      t.log
      pending  uses
      out      [(pairs:enjs:format ~[['role' s+'assistant'] ['content' u.c]]) out]
    ==
  $(log t.log)
::  +encode: the anthropic codec, request side.
++  encode
  |=  [model=@t max=@ud sys=@t schema=json messages=(list json)]
  ^-  json
  %-  pairs:enjs:format
  :~  ['model' s+model]
      ['max_tokens' (numb:enjs:format max)]
      ['system' s+sys]
      ['tools' schema]
      ['messages' [%a messages]]
  ==
++  resp-content
  |=  resp=json
  ^-  (list json)
  ?.  ?=([%o *] resp)  ~
  =/  c  (~(get by p.resp) 'content')
  ?.(?=([~ %a *] c) ~ p.u.c)
++  resp-stop
  |=  resp=json  ^-  @t  (jstr:clanker resp 'stop_reason')
++  resp-usage
  |=  resp=json
  ^-  json
  ?.  ?=([%o *] resp)  [%o ~]
  (fall (~(get by p.resp) 'usage') [%o ~])
::
::  ---  dialects  ---
::
::  The anthropic Messages shape is this app's CANONICAL form: it is
::  what the event log stores, what +assemble folds to, and what the
::  viewer, +status-of and the recipe machinery read. OpenAI-dialect
::  endpoints (openrouter) are translated on BOTH edges — out in
::  +encode-for, back in +decode — so nothing above this line learns
::  there is a second provider and no stored log needs migrating.
::
::  +provider-of: the registry row this clanker's config selects. An
::  absent or unknown `provider` falls back to the first row, so every
::  clanker that predates providers reads exactly as before.
::
++  provider-of
  |=  cfg=json
  ^-  provider:clanker
  (provider-for:clanker (jstr:clanker cfg 'provider'))
::  +oai: does this provider speak the openai dialect? The codec
::  branches on the DIALECT, never on the provider's name, so a new
::  endpoint nexus that speaks one we already have needs no code here.
::
++  oai
  |=  pro=provider:clanker
  ^-  ?
  =('chat-completions' dialect.pro)
::  +encode-for, +stop-for, +usage-for: the codec, by dialect.
::
++  encode-for
  |=  [pro=provider:clanker model=@t max=@ud sys=@t schema=json messages=(list json)]
  ^-  json
  ?:  (oai pro)  (encode-oai model max sys schema messages)
  (encode model max sys schema messages)
::
++  stop-for
  |=  [pro=provider:clanker resp=json]
  ^-  @t
  ?:((oai pro) (stop-oai resp) (resp-stop resp))
::
++  usage-for
  |=  [pro=provider:clanker resp=json]
  ^-  json
  ?:((oai pro) (usage-oai resp) (resp-usage resp))
::  +decode: a response as canonical content. A response in neither
::  dialect — a proxy error, an endpoint that refused the shape, a model
::  with no tool support — becomes a VISIBLE text block rather than an
::  empty turn, so a failed experiment reads as a failure in the chat
::  instead of the model appearing to say nothing.
::
++  decode
  |=  [pro=provider:clanker resp=json]
  ^-  (list json)
  =/  blocks=(list json)
    ?:((oai pro) (decode-oai resp) (resp-content resp))
  ?^  blocks  blocks
  ~[(pairs:enjs:format ~[['type' s+'text'] ['text' s+(resp-error pro resp)]])]
::  +resp-error: the most legible account of a response we could not
::  read — the provider's own error text when there is one, else the raw
::  json. Nothing fails silently.
::
++  resp-error
  |=  [pro=provider:clanker resp=json]
  ^-  @t
  =/  tag=tape  "[{(trip name.pro)}] "
  =/  err=(unit json)
    ?.(?=([%o *] resp) ~ (~(get by p.resp) 'error'))
  ?:  ?=([~ %s *] err)  (crip (weld tag (trip p.u.err)))
  ?^  err
    =/  msg=@t  (jstr:clanker u.err 'message')
    ?:  =('' msg)  (crip (weld tag (trip (en:json:html u.err))))
    (crip (weld tag (trip msg)))
  ?:  ?=([%o ~] resp)  (crip (weld tag "empty response"))
  (crip (weld tag (weld "unreadable response: " (trip (en:json:html resp)))))
::  +encode-oai: the openai-dialect codec, request side. There is no
::  top-level system field — the prompt is a leading message — tools are
::  wrapped as functions, and the messages are translated out of our
::  canonical shape.
::
++  encode-oai
  |=  [model=@t max=@ud sys=@t schema=json messages=(list json)]
  ^-  json
  =/  sysm=json  (pairs:enjs:format ~[['role' s+'system'] ['content' s+sys]])
  %-  pairs:enjs:format
  :~  ['model' s+model]
      ['max_tokens' (numb:enjs:format max)]
      ['tools' (tools-to-oai schema)]
      ['messages' [%a [sysm (msgs-to-oai messages)]]]
  ==
::  +tools-to-oai: an anthropic tool schema as openai functions. A
::  server-side tool (web_search) has no input_schema and no openai
::  equivalent: drop it rather than send a shape the endpoint refuses.
::
++  tools-to-oai
  |=  schema=json
  ^-  json
  ?.  ?=([%a *] schema)  [%a ~]
  :-  %a
  %+  murn  p.schema
  |=  t=json
  ^-  (unit json)
  ?.  ?=([%o *] t)  ~
  =/  isc=(unit json)  (~(get by p.t) 'input_schema')
  ?~  isc  ~
  :-  ~
  %-  pairs:enjs:format
  :~  ['type' s+'function']
      :-  'function'
      %-  pairs:enjs:format
      :~  ['name' s+(jstr:clanker t 'name')]
          ['description' s+(jstr:clanker t 'description')]
          ['parameters' u.isc]
      ==
  ==
::  +msgs-to-oai: canonical messages as openai messages. Three shapes
::  diverge: an assistant turn's tool_use blocks become a sibling
::  tool_calls field, a user turn's tool_result blocks become their own
::  role:'tool' messages (emitted FIRST, so each still follows the
::  assistant turn that called it), and an image block becomes a data:
::  url. Plain text turns pass through untouched — that part of the two
::  dialects is identical.
::
++  msgs-to-oai
  |=  msgs=(list json)
  ^-  (list json)
  %-  zing
  %+  turn  msgs
  |=  mj=json
  ^-  (list json)
  ?.  ?=([%o *] mj)  ~
  =/  role=@t  (jstr:clanker mj 'role')
  =/  con=(unit json)  (~(get by p.mj) 'content')
  ?~  con  ~
  ?.  ?=([%a *] u.con)  ~[mj]
  =/  blocks=(list json)  p.u.con
  ?:  =('assistant' role)
    =/  calls=(list json)
      %+  murn  blocks
      |=  b=json
      ^-  (unit json)
      ?.  ?=([%o *] b)  ~
      ?.  ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))  ~
      :-  ~
      %-  pairs:enjs:format
      :~  ['id' s+(jstr:clanker b 'id')]
          ['type' s+'function']
          :-  'function'
          %-  pairs:enjs:format
          :~  ['name' s+(jstr:clanker b 'name')]
              ['arguments' s+(en:json:html (fall (~(get by p.b) 'input') [%o ~]))]
          ==
      ==
    =/  base=(list [@t json])
      ~[['role' s+'assistant'] ['content' s+(text-of blocks)]]
    :_  ~
    %-  pairs:enjs:format
    ?~(calls base (snoc base [`@t`'tool_calls' `json`[%a calls]]))
  =/  results=(list json)
    %+  murn  blocks
    |=  b=json
    ^-  (unit json)
    ?.  ?=([%o *] b)  ~
    ?.  ?=([~ %s %'tool_result'] (~(get by p.b) 'type'))  ~
    =/  c=json  (fall (~(get by p.b) 'content') s+'')
    :-  ~
    %-  pairs:enjs:format
    :~  ['role' s+'tool']
        ['tool_call_id' s+(jstr:clanker b 'tool_use_id')]
        :-  'content'
        ?:  ?=([%s *] c)  c
        s+(text-of ?:(?=([%a *] c) p.c ~))
    ==
  =/  parts=(list json)
    %+  murn  blocks
    |=  b=json
    ^-  (unit json)
    ?.  ?=([%o *] b)  ~
    =/  ty=@t  (jstr:clanker b 'type')
    ?:  =('text' ty)  `b
    ?.  =('image' ty)  ~
    =/  src=json  (fall (~(get by p.b) 'source') [%o ~])
    =/  mt=@t  (jstr:clanker src 'media_type')
    =/  d=@t   (jstr:clanker src 'data')
    ?:  |(=('' mt) =('' d))  ~
    :-  ~
    %-  pairs:enjs:format
    :~  ['type' s+'image_url']
        :-  'image_url'
        %-  pairs:enjs:format
        ~[['url' s+(crip "data:{(trip mt)};base64,{(trip d)}")]]
    ==
  %+  weld  results
  ?~  parts  ~
  ~[(pairs:enjs:format ~[['role' s+'user'] ['content' [%a parts]]])]
::  +text-of: the text blocks of a content array, concatenated.
::
++  text-of
  |=  blocks=(list json)
  ^-  @t
  %-  crip
  %-  zing
  %+  turn  blocks
  |=  b=json
  ^-  tape
  ?.  ?=([%o *] b)  ""
  ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
  (trip (jstr:clanker b 'text'))
::  +decode-oai: an openai-dialect response back into canonical content,
::  so the log, the viewer and +assemble never learn of the dialect.
::
++  decode-oai
  |=  resp=json
  ^-  (list json)
  =/  msg=json  (oai-message resp)
  ?.  ?=([%o *] msg)  ~
  =/  text=@t  (jstr:clanker msg 'content')
  =/  blocks=(list json)
    ?:  =('' text)  ~
    ~[(pairs:enjs:format ~[['type' s+'text'] ['text' s+text]])]
  =/  calls=(unit json)  (~(get by p.msg) 'tool_calls')
  ?.  ?=([~ %a *] calls)  blocks
  %+  weld  blocks
  %+  murn  p.u.calls
  |=  c=json
  ^-  (unit json)
  ?.  ?=([%o *] c)  ~
  =/  f=json  (fall (~(get by p.c) 'function') [%o ~])
  ::  arguments arrive as a JSON STRING; a model that emits malformed
  ::  json yields an empty input, which the tool refuses on its own
  ::  terms, rather than a crashed turn
  =/  input=json  (fall (de:json:html (jstr:clanker f 'arguments')) [%o ~])
  :-  ~
  %-  pairs:enjs:format
  :~  ['type' s+'tool_use']
      ['id' s+(jstr:clanker c 'id')]
      ['name' s+(jstr:clanker f 'name')]
      ['input' input]
  ==
::  +oai-message: choices[0].message, or an empty object.
::
++  oai-message
  |=  resp=json
  ^-  json
  ?.  ?=([%o *] resp)  [%o ~]
  =/  ch=(unit json)  (~(get by p.resp) 'choices')
  ?.  ?=([~ %a ^] ch)  [%o ~]
  =/  c0=json  i.p.u.ch
  ?.  ?=([%o *] c0)  [%o ~]
  (fall (~(get by p.c0) 'message') [%o ~])
::  +stop-oai: finish_reason as a canonical stop_reason, since +run
::  branches on 'tool_use' to decide whether the turn continues.
::
++  stop-oai
  |=  resp=json
  ^-  @t
  ?.  ?=([%o *] resp)  ''
  =/  ch=(unit json)  (~(get by p.resp) 'choices')
  ?.  ?=([~ %a ^] ch)  ''
  =/  fr=@t  (jstr:clanker i.p.u.ch 'finish_reason')
  ?:  =('tool_calls' fr)  'tool_use'
  ?:  =('stop' fr)  'end_turn'
  ?:  =('length' fr)  'max_tokens'
  fr
::  +usage-oai: openai token counts under canonical names, keeping
::  openrouter's native `cost` when the proxy asked for accounting.
::
++  usage-oai
  |=  resp=json
  ^-  json
  =/  u=json
    ?.(?=([%o *] resp) [%o ~] (fall (~(get by p.resp) 'usage') [%o ~]))
  ?.  ?=([%o *] u)  [%o ~]
  %-  pairs:enjs:format
  :~  ['input_tokens' (numb:enjs:format (jnum:clanker u 'prompt_tokens' 0))]
      ['output_tokens' (numb:enjs:format (jnum:clanker u 'completion_tokens' 0))]
      ['cost' (fall (~(get by p.u) 'cost') [%n '0'])]
  ==
::  +event-*: the log vocabulary, as stored json.
++  event-input
  |=  body=@t
  ^-  json
  (pairs:enjs:format ~[['k' s+'input'] ['body' s+body]])
::  a recipe was entered: one line, in the history of both readers
++  event-recipe
  |=  body=@t
  ^-  json
  (pairs:enjs:format ~[['k' s+'recipe'] ['body' s+body]])
++  event-response
  |=  [content=(list json) stop=@t usage=json]
  ^-  json
  (pairs:enjs:format ~[['k' s+'response'] ['content' [%a content]] ['stop' s+stop] ['usage' usage]])
++  event-results
  |=  [content=(list json) trace=(list json)]
  ^-  json
  (pairs:enjs:format ~[['k' s+'results'] ['content' [%a content]] ['trace' [%a trace]]])
::  the turn was stopped (by the user, or a tool/proxy interrupt): the
::  log is at rest here, and a restart does not resume it
++  event-interrupt
  ^-  json
  (pairs:enjs:format ~[['k' s+'interrupt']])
::  the turn is paused on the user: these tool_use ids (of the response
::  just before) ask first. At rest until resolved or stopped.
++  event-ask
  |=  ids=(list @t)
  ^-  json
  (pairs:enjs:format ~[['k' s+'ask'] ['ids' [%a (turn ids |=(i=@t `json`s+i))]]])
::  the user's answer: {id: true|false} per asked use. Only an explicit
::  false declines; an id left out runs.
++  event-resolved
  |=  decisions=json
  ^-  json
  (pairs:enjs:format ~[['k' s+'resolved'] ['decisions' decisions]])
::  +last-response: the newest response event in the log.
++  last-response
  |=  log=(list json)
  ^-  json
  =/  rs=(list json)  (skim log |=(e=json =('response' (jstr:clanker e 'k'))))
  ?~(rs [%o ~] (rear rs))
::  readers over this clanker's own tree
++  read-json
  |=  [=rail:tarball =lane:tarball]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io (nex-road:io rail lane) `[/ %json])
  ?.  ?=([%file *] v)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.v)))) [%o ~]))
++  read-text
  |=  [=rail:tarball =lane:tarball]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io (nex-road:io rail lane) `[/ %mime])
  ?.  ?=([%file *] v)  (pure:m '')
  ?:  (is-boom:tarball sang.v)  (pure:m '')
  (pure:m `@t`q.q:!<(mime (need-vase:tarball sang.v)))
::  +read-dir-texts: every file directly in a dir, as [name text], sorted.
++  read-dir-texts
  |=  [=rail:tarball dir=path]
  =/  m  (fiber:fiber:nexus ,(list [@ta @t]))
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  ?~  fil.ball.dv  (pure:m ~)
  =/  names=(list @ta)  (sort ~(tap in ~(key by contents.u.fil.ball.dv)) aor)
  =|  out=(list [@ta @t])
  |-
  ?~  names  (pure:m (flop out))
  ;<  t=@t  bind:m  (read-text rail [%& dir i.names])
  $(names t.names, out [[i.names t] out])
--
