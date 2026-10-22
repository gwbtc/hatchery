::  lib/recipe: thought processes as step graphs, rendered at the tip
::
::  A recipe is a graph of steps. A step is a held intention with an aim
::  (commit convention: a title line, a blank, then the description) and
::  a set of arrows, each carrying the condition under which to take it.
::  The agent names the intention it adopts next; staying is re-choosing
::  the same step, so `self` is an ordinary arrow.
::
::  Three arrow targets are reserved and never steps: `done` ends the
::  run, `abort` ends it without its output, `ask` pauses it on the
::  user (the step is kept; the run waits for the user's next message).
::  Each is on offer only where the author put it in a step's `next`,
::  with its condition, like any other arrow: a step with no `abort` is
::  one the agent may not give up on. Running out of budget is not an
::  exit the agent takes; it is the run ending under it (+stuck).
::
::  Budgets live in levels, each a WHOLE budget rather than a scaling of
::  some other level. Three kinds: the run total, a per-step lifetime
::  (when spent the step becomes unreachable — not an error, you just
::  lose a destination), and a per-step dwell (one occupancy, reset on
::  leaving). A step absent from a level is unbudgeted; `life: 0` retires
::  it before the run starts. Budgets only subtract: they make a move
::  impossible, never mandatory.
::
::  Everything here is pure. The tip is assembled fresh per request and
::  never stored in the chat — see +tip's callers. Its words are not
::  in here: the caller hands in the system-prompt fragments (a map of
::  file name to text, +frags-of over a /& directory import) and +fill
::  puts the run's facts into them.
::
|%
+$  frags  (map @ta @t)
::  +frags-of: a /& directory import as fragments by file name.
::
++  frags-of
  |=  raw=(unit (map @ta mime))
  ^-  frags
  (~(run by (fall raw ~)) |=(=mime `@t`q.q.mime))
::  +say: a fragment with its {keys} filled.
::
++  say
  |=  [=frags name=@ta subs=(list [tape tape])]
  ^-  tape
  (fill (trip (fall (~(get by frags) name) '')) subs)
::  +fill: {key} in a template becomes its value; an unknown key stays
::  as written, so a missing value is visible rather than blank.
::
++  fill
  |=  [tpl=tape subs=(list [k=tape v=tape])]
  ^-  tape
  =/  open=@tD  `@tD`123
  =/  close=@tD  `@tD`125
  |-  ^-  tape
  ?~  tpl  ~
  ?.  =(open i.tpl)  [i.tpl $(tpl t.tpl)]
  =/  end=(unit @ud)  (find ~[close] t.tpl)
  ?~  end  [i.tpl $(tpl t.tpl)]
  =/  key=tape  (scag u.end t.tpl)
  =/  hit=(unit tape)  (lookup key subs)
  %+  weld  ?~(hit [open (weld key ~[close])] u.hit)
  $(tpl (slag +(u.end) t.tpl))
::
++  lookup
  |=  [key=tape subs=(list [k=tape v=tape])]
  ^-  (unit tape)
  ?~  subs  ~
  ?:(=(key k.i.subs) `v.i.subs $(subs t.subs))
::  +spent: what rides when the budget is gone.
::
++  spent
  |=  =frags
  ^-  @t
  (crip (say frags %'spent.txt' ~))
+$  recipe
  $:  name=@t
      aim=(list @t)
      input=(list @t)
      output=(list @t)
      start=@t
      steps=(map @t step)
      levels=(map @t level)
  ==
::  a step: its aim, what it expects to have in hand (input), what it
::  leaves behind (output), and its arrows: target -> the condition
::  under which to take it. targets are a step name, 'self', or one of
::  the reserved exits. input and output are part of the shape at both
::  levels, and +parse refuses a file that omits either: a recipe that
::  does not say what it needs and what it hands back is not a
::  function, and a step that does not is not a step. Empty is a
::  statement; absent is not.
::
+$  step  [aim=(list @t) input=(list @t) output=(list @t) next=(map @t @t)]
+$  level  [run=@ud caps=(map @t cap)]
+$  cap   [life=(unit @ud) dwell=(unit @ud)]
::  run state for one chat. `asked` is set by taking an `ask` arrow and
::  cleared by the user's next message. `spent` is lifetime consumed per
::  step, `dwell` is consumed in the current occupancy, `run` the total.
::
+$  state
  $:  name=@t
      level=@t
      step=@t
      asked=?
      spent=(map @t @ud)
      dwell=@ud
      run=@ud
  ==
::  a chat's runs, nested: the recipe it is on, inside the recipe that
::  was on when that one was entered. Top first. Entering pushes; a
::  run that reaches done or abort is popped by the caller, which is
::  then back on the frame beneath, at the step it left, with that
::  step's own arrows to choose from.
::
+$  stack  (list state)
::
++  push
  |=  [=stack s=state]
  ^-  ^stack
  [s stack]
::  +tick-all: one message spends every frame. The outer step is
::  occupied for as long as the inner recipe runs, so its dwell, its
::  life and its run all go down with it.
::
++  tick-all
  |=  =stack
  ^-  ^stack
  (turn stack tick)
::
++  stack-to-json
  |=  =stack
  ^-  json
  (pairs:enjs:format ~[['frames' a+(turn (flop stack) state-to-json)]])
::  +stack-from-json: {frames: [...]} bottom first in the file, top
::  first in hand. Anything else is no run.
::
++  stack-from-json
  |=  jon=json
  ^-  stack
  ?.  ?=([%o *] jon)  ~
  =/  fs=(unit json)  (~(get by p.jon) 'frames')
  ?.  ?=([~ %a *] fs)  ~
  (flop (murn p.u.fs state-from-json))
::  +term: the reserved arrow targets.
::
++  term
  |=  t=@t
  ^-  ?
  |(=('done' t) =('abort' t) =('ask' t))
::  +parse: a recipe file. ~ when it lacks a start or a steps object,
::  since a recipe without those cannot be entered.
::
++  parse
  |=  [nm=@t jon=json]
  ^-  (unit recipe)
  ?.  ?=([%o *] jon)  ~
  =/  start=@t  (jstr jon 'start')
  ?:  =('' start)  ~
  =/  sj=(unit json)  (~(get by p.jon) 'steps')
  ?.  ?=([~ %o *] sj)  ~
  ?.  &((~(has by p.jon) 'input') (~(has by p.jon) 'output'))  ~
  =/  steps=(unit (map @t step))  (steps-of u.sj)
  ?~  steps  ~
  :-  ~
  :*  nm
      (jlines (~(get by p.jon) 'aim'))
      (jlines (~(get by p.jon) 'input'))
      (jlines (~(get by p.jon) 'output'))
      start
      u.steps
      (levels-of (~(get by p.jon) 'levels'))
  ==
::  +enter: the state a fresh run starts in.
::
++  enter
  |=  [=recipe level=@t]
  ^-  state
  [name.recipe level start.recipe | ~ 0 0]
::  +tick: spend one message. Called once per request, before the tip is
::  rendered, so what the agent reads is what it has left.
::
++  tick
  |=  =state
  ^-  ^state
  =/  used=@ud  (fall (~(get by spent.state) step.state) 0)
  %=  state
    run    +(run.state)
    dwell  +(dwell.state)
    spent  (~(put by spent.state) step.state +(used))
  ==
::  +move: adopt an intention. Refuses a target with no arrow from the
::  current step, and one whose budget is spent. Staying keeps the dwell
::  count; going anywhere else resets it. `ask` keeps the step and marks
::  the run as waiting; `done` and `abort` become the step, which is
::  how the run records its ending.
::
++  move
  |=  [=recipe =state target=@t]
  ^-  (each ^state @t)
  ::  the tip labels the self-arrow `stay`, so accept the word it showed.
  ::  'self' stays the graph key; nobody has to know that but the file.
  =?  target  =('stay' target)  'self'
  =/  opts=(list arrow)  (open recipe state)
  |-  ^-  (each ^state @t)
  ?~  opts
    |+(crip "no arrow from {(trip step.state)} to {(trip target)}")
  ?.  =(target target.i.opts)  $(opts t.opts)
  ?.  ok.i.opts
    |+(crip "{(trip target)} is out of budget")
  ?:  =('self' target)  &+state
  ?:  =('ask' target)  &+state(asked &)
  &+state(step target, dwell 0)
::  +answer: the user has spoken; a run paused on an ask goes on.
::
++  answer
  |=  =state
  ^-  ^state
  state(asked |)
::  +done: has the run ended, by either exit.
::
++  done
  |=  =state
  ^-  ?
  |(=('done' step.state) =('abort' step.state))
::  +stuck: nothing reachable and not finished — the graph ran out of
::  room, which is a failure exit rather than a halt.
::
++  stuck
  |=  [=recipe =state]
  ^-  ?
  ?:  (done state)  |
  ?:  =(0 (run-left recipe state))  &
  =(~ (skim (open recipe state) |=(a=arrow ok.a)))
::  an arrow as the renderer and +move see it: where, why, and whether
::  its budget leaves it open.
::
+$  arrow  [target=@t cond=@t ok=?]
::  +open: this step's arrows in a stable order — stay first, the
::  reserved exits last, the rest alphabetical. Spent targets are
::  included and marked, so a caller can render them or drop them.
::
++  open
  |=  [=recipe =state]
  ^-  (list arrow)
  =/  st=(unit step)  (~(get by steps.recipe) step.state)
  ?~  st  ~
  %+  turn  (sort ~(tap by next.u.st) arrow-order)
  |=  [t=@t c=@t]
  ^-  arrow
  :+  t  c
  ?:  (term t)  &
  ?:  =('self' t)
    =/  d=(unit @ud)  (dwell-left recipe state)
    ?~(d & (gth u.d 0))
  =/  l=(unit @ud)  (life-left recipe state t)
  ?~(l & (gth u.l 0))
::  +cap-for: a step's budget at the run's level. Absent means
::  unbudgeted, which is not the same as zero.
::
++  cap-for
  |=  [=recipe =state nm=@t]
  ^-  cap
  =/  lv=(unit level)  (~(get by levels.recipe) level.state)
  ?~  lv  [~ ~]
  (fall (~(get by caps.u.lv) nm) [~ ~])
::  +life-left, +dwell-left: ~ when unbudgeted, else what remains.
::
++  life-left
  |=  [=recipe =state nm=@t]
  ^-  (unit @ud)
  =/  c=cap  (cap-for recipe state nm)
  ?~  life.c  ~
  =/  used=@ud  (fall (~(get by spent.state) nm) 0)
  `?:((gte used u.life.c) 0 (sub u.life.c used))
::
++  dwell-left
  |=  [=recipe =state]
  ^-  (unit @ud)
  =/  c=cap  (cap-for recipe state step.state)
  ?~  dwell.c  ~
  `?:((gte dwell.state u.dwell.c) 0 (sub u.dwell.c dwell.state))
::
++  run-left
  |=  [=recipe =state]
  ^-  @ud
  =/  lv=(unit level)  (~(get by levels.recipe) level.state)
  ?~  lv  0
  ?:((gte run.state run.u.lv) 0 (sub run.u.lv run.state))
::  +tip: what rides at the end of the request. Two registers on
::  purpose: the structural lines are facts about the run and read as
::  infrastructure, while an aim is the recipe author speaking and is
::  marked as quoted. The shape is identical every turn — anything that
::  varies in form reads as commentary rather than state.
::
++  tip
  |=  [=frags =recipe =state]
  ^-  @t
  (tip-in frags recipe state ~)
::  +tip-in: the tip of a nested run. The frames beneath are named, top
::  of them first, so the agent knows what it will return to.
::
++  tip-in
  |=  [=frags =recipe =state outer=(list state)]
  ^-  @t
  =/  st=(unit step)  (~(get by steps.recipe) step.state)
  %-  crip
  %^  say  frags  %'tip.txt'
  :~  ["name" (trip name.recipe)]
      ["level" (trip level.state)]
      ["within" (within frags outer)]
      ["aim" (quoted aim.recipe)]
      ["input" (labeled "INPUT " input.recipe)]
      ["output" (labeled "OUTPUT" output.recipe)]
      ["step-line" (step-line recipe state)]
      ["step-aim" (quoted ?~(st ~ aim.u.st))]
      ["step-input" (labeled "INPUT " ?~(st ~ input.u.st))]
      ["step-output" (labeled "OUTPUT" ?~(st ~ output.u.st))]
      ["asked" ?:(asked.state (say frags %'asked.txt' ~) "")]
      ["arrows" (arrows-block recipe state)]
  ==
::  +within: the frames beneath this run, one line each.
::
++  within
  |=  [=frags outer=(list state)]
  ^-  tape
  %-  zing
  %+  turn  outer
  |=  o=state
  (say frags %'within.txt' ~[["name" (trip name.o)] ["step" (trip step.o)] ["level" (trip level.o)]])
::  +step-line: the budget readout. A dash is unbudgeted, not zero.
::
++  step-line
  |=  [=recipe =state]
  ^-  tape
  ;:  weld
    "STEP  "  (trip step.state)
    "  [dwell "  (gauge (dwell-left recipe state))
    ", step "    (gauge (life-left recipe state step.state))
    ", run "     (a-co:co (run-left recipe state))
    "]\0a"
  ==
::  +arrows-block: the open arrows with their conditions. Spent ones are
::  left out rather than shown struck through: a destination you cannot
::  reach is not a choice, and listing it invites arguing with the
::  budget.
::
++  arrows-block
  |=  [=recipe =state]
  ^-  tape
  %-  zing
  %+  turn  (open recipe state)
  |=  =arrow
  ^-  tape
  ?.  ok.arrow  ""
  =/  label=tape  ?:(=('self' target.arrow) "stay" (trip target.arrow))
  ;:(weld "  " (pad label 11) " " (trip cond.arrow) "\0a")
::  +catalog: the recipes on offer, one line each. The aim's title line
::  is what sells a recipe before it has been entered, so it is all that
::  shows here.
::
++  catalog
  |=  rs=(list recipe)
  ^-  @t
  ?:  =(~ rs)  ''
  =/  body=tape
    %-  zing
    %+  turn  rs
    |=  r=recipe
    ;:(weld "  " (pad (trip name.r) 14) " " (trip (title aim.r)) "\0a")
  %-  crip
  ;:  weld
    "<recipes-available>\0a"
    body
    "</recipes-available>\0a"
  ==
::  run state as json, so it can live in an ordinary grub beside the
::  chat it belongs to. The only thing the protocol persists is where
::  you are, whether you are waiting, and what you have spent.
::
++  state-to-json
  |=  =state
  ^-  json
  %-  pairs:enjs:format
  :~  ['recipe' s+name.state]
      ['level' s+level.state]
      ['step' s+step.state]
      ['asked' b+asked.state]
      ['dwell' (numb:enjs:format dwell.state)]
      ['run' (numb:enjs:format run.state)]
      :-  'spent'
      %-  pairs:enjs:format
      %+  turn  ~(tap by spent.state)
      |=([k=@t v=@ud] [k (numb:enjs:format v)])
  ==
::  +state-from-json: ~ unless both the recipe name and the step are
::  present, since a run that doesn't know either of those is not a run.
::
++  state-from-json
  |=  jon=json
  ^-  (unit state)
  ?.  ?=([%o *] jon)  ~
  =/  nm=@t  (jstr jon 'recipe')
  ?:  =('' nm)  ~
  =/  sp=@t  (jstr jon 'step')
  ?:  =('' sp)  ~
  :-  ~
  :*  nm
      (jstr jon 'level')
      sp
      (jflag jon 'asked')
      (spent-of (~(get by p.jon) 'spent'))
      (jnum jon 'dwell' 0)
      (jnum jon 'run' 0)
  ==
::
++  spent-of
  |=  v=(unit json)
  ^-  (map @t @ud)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t @ud))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t @ud])
  =/  n=(unit @ud)  (mole |.((ni:dejs:format j)))
  ?~(n ~ `[k u.n])
::  helpers
::
++  title
  |=  ls=(list @t)
  ^-  @t
  ?~(ls '' i.ls)
::  +quoted: an aim as the author wrote it, indented so it reads as
::  quotation rather than as instruction from the harness.
::
++  quoted
  |=  ls=(list @t)
  ^-  tape
  ?~  ls  ""
  %-  zing
  %+  turn  ls
  |=(l=@t ?:(=('' l) "\0a" (weld (weld "| " (trip l)) "\0a")))
::  +labeled: a structural label over the author's quoted lines. An
::  empty list renders as a dash: the author said "nothing", which is
::  shown, since +parse refuses a file that said nothing at all.
::
++  labeled
  |=  [lbl=tape ls=(list @t)]
  ^-  tape
  ?~  ls  (weld lbl "  -\0a")
  (weld (weld lbl "\0a") (quoted ls))
::
++  gauge
  |=  u=(unit @ud)
  ^-  tape
  ?~(u "-" (a-co:co u.u))
::
++  pad
  |=  [t=tape n=@ud]
  ^-  tape
  ?:  (gte (lent t) n)  t
  (weld t (reap (sub n (lent t)) ' '))
::  +arrow-order: stay first, then steps alphabetical, then the exits
::  in the order ask, abort, done. JSON objects are unordered, so the
::  render order is imposed here rather than taken from the file.
::
++  arrow-order
  |=  [a=[t=@t c=@t] b=[t=@t c=@t]]
  ^-  ?
  ?:  =('self' t.a)  &
  ?:  =('self' t.b)  |
  =/  ra=@ud  (exit-rank t.a)
  =/  rb=@ud  (exit-rank t.b)
  ?.  =(ra rb)  (lth ra rb)
  (lth t.a t.b)
::
++  exit-rank
  |=  t=@t
  ^-  @ud
  ?:  =('done' t)  3
  ?:  =('abort' t)  2
  ?:  =('ask' t)  1
  0
::  +steps-of: the steps object. ~ when any step omits input or output
::  — the whole recipe is refused, since a step without a stated shape
::  cannot be entered any more than a recipe without a start. A step
::  named like a reserved exit is dropped.
::
++  steps-of
  |=  jon=json
  ^-  (unit (map @t step))
  ?.  ?=([%o *] jon)  ~
  =/  all=(list [k=@t v=json])  ~(tap by p.jon)
  =|  out=(map @t step)
  |-  ^-  (unit (map @t step))
  ?~  all  `out
  ?.  ?=([%o *] v.i.all)  $(all t.all)
  ?:  (term k.i.all)  $(all t.all)
  =/  v  v.i.all
  ?.  &((~(has by p.v) 'input') (~(has by p.v) 'output'))  ~
  =/  st=step
    :^    (jlines (~(get by p.v) 'aim'))
        (jlines (~(get by p.v) 'input'))
      (jlines (~(get by p.v) 'output'))
    (jarrows (~(get by p.v) 'next'))
  $(all t.all, out (~(put by out) k.i.all st))
::
++  levels-of
  |=  v=(unit json)
  ^-  (map @t level)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t level))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t level])
  ?.  ?=([%o *] j)  ~
  `[k [(jnum j 'run' 0) (caps-of (~(get by p.j) 'steps'))]]
::
++  caps-of
  |=  v=(unit json)
  ^-  (map @t cap)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t cap))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t cap])
  ?.  ?=([%o *] j)  ~
  `[k [(jopt j 'life') (jopt j 'dwell')]]
::
++  jarrows
  |=  v=(unit json)
  ^-  (map @t @t)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t @t))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t @t])
  ?:(?=([%s *] j) `[k p.j] ~)
::
++  jlines
  |=  v=(unit json)
  ^-  (list @t)
  ?.  ?=([~ %a *] v)  ~
  %+  murn  p.u.v
  |=  j=json
  ^-  (unit @t)
  ?:(?=([%s *] j) `p.j ~)
::
++  jstr
  |=  [jon=json key=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  v=(unit json)  (~(get by p.jon) key)
  ?:(?=([~ %s *] v) p.u.v '')
::
++  jflag
  |=  [jon=json key=@t]
  ^-  ?
  ?.  ?=([%o *] jon)  |
  =/  v=(unit json)  (~(get by p.jon) key)
  ?:(?=([~ %b *] v) p.u.v |)
::
++  jnum
  |=  [jon=json key=@t def=@ud]
  ^-  @ud
  ?.  ?=([%o *] jon)  def
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  def
  (fall (mole |.((ni:dejs:format u.v))) def)
::
++  jopt
  |=  [jon=json key=@t]
  ^-  (unit @ud)
  ?.  ?=([%o *] jon)  ~
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  ~
  (mole |.((ni:dejs:format u.v)))
--
