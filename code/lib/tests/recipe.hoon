/<  test  /lib/test.hoon
/<  rec   /lib/recipe.hoon
/&  raw   /nex/clanker/system-prompt/
::  tests for lib/recipe: parse, budget arithmetic, transitions, render
::
::  The demo recipe is two steps. `a` may stay (dwell 2, life 4), go to
::  `b`, ask the user, or abort; `b` may only finish. `a` is budgeted
::  both ways and `b` has no dwell, so the unbudgeted-vs-zero
::  distinction gets exercised. The file also declares `done` and `ask`
::  steps, which parse must drop.
::
::  rcp and st0 are =/ legs rather than core arms on purpose: a face
::  looked up through an arm reference does not carry the arm's mold,
::  so `aim.rcp` fails where `aim` on a declared leg resolves. The chk
::  gates exist for the same class of reason — expect-eq compares types
::  as well as values, so the expected side needs a declared sample
::  rather than a bare literal.
::
=/  src=@t
  '{"aim":["Test recipe","","A description."],"input":["a question"],"output":["an answer"],"start":"a","steps":{"a":{"aim":["Step A"],"input":["the question"],"output":[],"next":{"self":"more to do","b":"a is settled","ask":"the question is unclear","abort":"no way forward"}},"b":{"aim":["Step B"],"input":[],"output":["the answer"],"next":{"done":"finished"}},"c":{"recipe":"other","next":{"done":"the other recipe came back"}},"done":{"aim":["must be dropped"]},"ask":{"aim":["must be dropped"]}},"levels":{"normal":{"run":10,"steps":{"a":{"life":4,"dwell":2},"b":{"life":3}}}}}'
::  the same recipe missing its own output, and missing a step's input:
::  both must be refused whole
=/  no-out=@t
  '{"aim":["x"],"input":[],"start":"a","steps":{"a":{"aim":["A"],"input":[],"output":[],"next":{"done":"ok"}}}}'
=/  no-step-in=@t
  '{"aim":["x"],"input":[],"output":[],"start":"a","steps":{"a":{"aim":["A"],"output":[],"next":{"done":"ok"}}}}'
=/  rcp=recipe:rec  (need (parse:rec 'demo' (need (de:json:html src))))
=/  st0=state:rec   (enter:rec rcp 'normal')
::  the tip's words come from the clanker's system-prompt directory
=/  fr=frags:rec    (frags-of:rec fil.raw)
=/  tip  |=([r=recipe:rec s=state:rec] (tip:rec fr r s))
%-  run-tests:test
!>
|%
::  +tik: spend n messages
::
++  tik
  |=  [n=@ud s=state:rec]
  ^-  state:rec
  ?:(=(0 n) s $(n (dec n), s (tick:rec s)))
::  +won: the state out of a move that must have succeeded
::
++  won
  |=  e=(each state:rec @t)
  ^-  state:rec
  ?>(?=(%& -.e) p.e)
::  +fail: did a move get refused
::
++  fail
  |=  e=(each state:rec @t)
  ^-  ?
  ?=(%| -.e)
::  +has: does a rendered block contain this text
::
++  has
  |=  [nedl=tape hstk=@t]
  ^-  ?
  ?=(^ (find nedl (trip hstk)))
::  typed comparisons
::
++  chk-ud   |=([want=@ud got=@ud] (expect-eq:test !>(want) !>(got)))
++  chk-t    |=([want=@t got=@t] (expect-eq:test !>(want) !>(got)))
++  chk-lo   |=([want=? got=?] (expect-eq:test !>(want) !>(got)))
++  chk-unit  |=([want=(unit @ud) got=(unit @ud)] (expect-eq:test !>(want) !>(got)))
++  chk-list  |=([want=(list @t) got=(list @t)] (expect-eq:test !>(want) !>(got)))
++  chk-rcp
  |=  [want=(unit recipe:rec) got=(unit recipe:rec)]
  (expect-eq:test !>(want) !>(got))
::  parse
::
++  test-parse-start
  |.((chk-t 'a' start.rcp))
++  test-parse-aim-lines
  |.((chk-ud 3 (lent aim.rcp)))
::  the reserved exits are arrow targets, so steps by those names are dropped
++  test-parse-drops-reserved-steps
  |.((chk-ud 3 ~(wyt by steps.rcp)))
::  a recipe-step names a recipe instead of an aim, and needs no input
::  or output of its own
++  test-parse-recipe-step
  |.((expect-eq:test !>(`(unit @t)``'other') !>((sub-of:rec rcp 'c'))))
++  test-plain-step-is-not-a-recipe
  |.((expect-eq:test !>(*(unit @t)) !>((sub-of:rec rcp 'a'))))
++  test-parse-rejects-startless
  |.((chk-rcp ~ (parse:rec 'x' (need (de:json:html '{"steps":{}}')))))
::  input and output are part of the shape at both levels: a file that
::  omits either, on the recipe or on any step, is refused whole
++  test-parse-keeps-input
  |.((chk-list ~['a question'] input.rcp))
++  test-parse-keeps-step-output
  |.((chk-list ~['the answer'] output:(need (~(get by steps.rcp) 'b'))))
++  test-parse-rejects-recipe-without-output
  |.((chk-rcp ~ (parse:rec 'x' (need (de:json:html no-out)))))
++  test-parse-rejects-step-without-input
  |.((chk-rcp ~ (parse:rec 'x' (need (de:json:html no-step-in)))))
::  entry
::
++  test-enter-step
  |.((chk-t 'a' step.st0))
++  test-enter-unspent
  |.((chk-ud 0 (add run.st0 dwell.st0)))
++  test-enter-not-asked
  |.((chk-lo | asked.st0))
::  budgets: ~ is unbudgeted, which is not zero
::
++  test-life-fresh
  |.((chk-unit `4 (life-left:rec rcp st0 'a')))
++  test-dwell-fresh
  |.((chk-unit `2 (dwell-left:rec rcp st0)))
++  test-run-fresh
  |.((chk-ud 10 (run-left:rec rcp st0)))
++  test-tick-spends-run
  |.((chk-ud 8 (run-left:rec rcp (tik 2 st0))))
++  test-tick-spends-life
  |.((chk-unit `2 (life-left:rec rcp (tik 2 st0) 'a')))
++  test-tick-spends-dwell
  |.((chk-unit `0 (dwell-left:rec rcp (tik 2 st0))))
::  a step with no dwell in the level is unbudgeted, not spent
++  test-dwell-absent-is-unbudgeted
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-unit ~ (dwell-left:rec rcp s))
::  transitions
::
++  test-stay-keeps-dwell
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'self'))
      (chk-ud 1 dwell.s)
++  test-stay-keeps-step
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'self'))
      (chk-t 'a' step.s)
::  the tip labels the self-arrow `stay`, so that word has to move too
++  test-stay-alias-is-accepted
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'stay'))
      (chk-t 'a' step.s)
++  test-stay-alias-keeps-dwell
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'stay'))
      (chk-ud 1 dwell.s)
++  test-stay-alias-refused-when-spent
  |.((chk-lo & (fail (move:rec rcp (tik 2 st0) 'stay'))))
++  test-move-resets-dwell
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-ud 0 dwell.s)
++  test-move-changes-step
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-t 'b' step.s)
::  a target with no arrow from here is refused, not silently taken
++  test-no-such-arrow
  |.((chk-lo & (fail (move:rec rcp st0 'zzz'))))
::  dwell spent: staying is no longer on offer
++  test-stay-refused-when-dwell-spent
  |.((chk-lo & (fail (move:rec rcp (tik 2 st0) 'self'))))
++  test-done-is-terminal
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-lo & (done:rec (won (move:rec rcp s 'done'))))
::  ask: the step is kept and the run is marked waiting; the user's
::  message clears it. abort: terminal, and only where the author put it
++  test-ask-keeps-step
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'ask'))
      (chk-t 'a' step.s)
++  test-ask-marks-waiting
  |.((chk-lo & asked:(won (move:rec rcp (tik 1 st0) 'ask'))))
++  test-ask-keeps-dwell
  |.((chk-ud 1 dwell:(won (move:rec rcp (tik 1 st0) 'ask'))))
++  test-answer-clears-waiting
  |.((chk-lo | asked:(answer:rec (won (move:rec rcp st0 'ask')))))
++  test-ask-refused-where-not-offered
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-lo & (fail (move:rec rcp s 'ask')))
++  test-abort-is-terminal
  |.((chk-lo & (done:rec (won (move:rec rcp st0 'abort')))))
++  test-abort-refused-where-not-offered
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-lo & (fail (move:rec rcp s 'abort')))
::  the open set, in render order: stay first, steps, then the exits
::
++  test-open-order
  |.  %+  chk-list  ~['self' 'b' 'ask' 'abort']
      (turn (open:rec rcp st0) |=(a=arrow:rec target.a))
::  a spent arrow drops out of the open set rather than erroring
++  test-open-drops-spent-stay
  |.  %+  chk-list  ~['b' 'ask' 'abort']
      %+  turn
        (skim (open:rec rcp (tik 2 st0)) |=(a=arrow:rec ok.a))
      |=(a=arrow:rec target.a)
::  exhaustion
::
++  test-not-stuck-fresh
  |.((chk-lo | (stuck:rec rcp st0)))
++  test-stuck-when-run-spent
  |.((chk-lo & (stuck:rec rcp (tik 10 st0))))
++  test-done-is-not-stuck
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-lo | (stuck:rec rcp (won (move:rec rcp s 'done'))))
::  render: the structural lines are facts, the aim is quoted
::
++  test-tip-names-step
  |.((chk-lo & (has "STEP  a" (tip rcp st0))))
++  test-tip-shows-budgets
  |.((chk-lo & (has "[dwell 2, step 4, run 10]" (tip rcp st0))))
::  an unbudgeted figure renders as a dash, never as 0
++  test-tip-dash-for-unbudgeted
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-lo & (has "[dwell -, step 3, run 9]" (tip rcp s)))
++  test-tip-quotes-the-aim
  |.((chk-lo & (has "| Step A" (tip rcp st0))))
::  input and output ride under structural labels, the author's lines
::  quoted; an empty one shows as a dash rather than vanishing
++  test-tip-labels-recipe-input
  |.((chk-lo & (has "INPUT \0a| a question" (tip rcp st0))))
++  test-tip-labels-step-input
  |.((chk-lo & (has "| the question" (tip rcp st0))))
++  test-tip-dash-for-empty-output
  |.((chk-lo & (has "OUTPUT  -" (tip rcp st0))))
::  the exits show only where the step offers them
++  test-tip-lists-abort-where-offered
  |.((chk-lo & (has "abort" (tip rcp st0))))
++  test-tip-omits-abort-where-not-offered
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-lo | (has "abort" (tip rcp s)))
++  test-tip-says-asked
  |.((chk-lo & (has "ASKED" (tip rcp (won (move:rec rcp st0 'ask'))))))
++  test-tip-silent-when-not-asked
  |.((chk-lo | (has "ASKED" (tip rcp st0))))
++  test-tip-lists-open-arrow
  |.((chk-lo & (has "a is settled" (tip rcp st0))))
::  catalog: one line per recipe, title only
::
++  test-catalog-names-recipe
  |.((chk-lo & (has "demo" (catalog:rec ~[rcp]))))
++  test-catalog-shows-title
  |.((chk-lo & (has "Test recipe" (catalog:rec ~[rcp]))))
++  test-catalog-empty-is-empty
  |.((chk-t '' (catalog:rec *(list recipe:rec))))
::  state serialization: a run survives a trip through a grub
::
++  chk-state
  |=  [want=(unit state:rec) got=(unit state:rec)]
  (expect-eq:test !>(want) !>(got))
::
++  test-state-round-trip-fresh
  |.((chk-state `st0 (state-from-json:rec (state-to-json:rec st0))))
::  with a non-empty spent map and a dwell mid-step
++  test-state-round-trip-spent
  |.  =/  s=state:rec  (won (move:rec rcp (tik 2 st0) 'b'))
      =/  s=state:rec  (tik 3 s)
      (chk-state `s (state-from-json:rec (state-to-json:rec s)))
++  test-state-round-trip-asked
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'ask'))
      (chk-state `s (state-from-json:rec (state-to-json:rec s)))
::  the stack: entering pushes, one message spends every frame, the file
::  holds the frames bottom first
++  test-stack-push-is-top
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-t 'b' step:(head (push:rec ~[st0] s)))
++  test-stack-tick-spends-every-frame
  |.  =/  s2=stack:rec  (tick-all:rec ~[st0 st0])
      (chk-ud 2 (add run:(head s2) run:(rear s2)))
++  test-stack-round-trip
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      =/  stk=stack:rec  ~[s st0]
      (expect-eq:test !>(stk) !>((stack-from-json:rec (stack-to-json:rec stk))))
++  test-stack-from-plain-state-is-none
  |.((expect-eq:test !>(*stack:rec) !>((stack-from-json:rec (state-to-json:rec st0)))))
++  test-tip-in-names-outer
  |.((chk-lo & (has "WITHIN  demo at a" (tip-in:rec fr rcp st0 ~[st0]))))
++  test-tip-alone-has-no-within
  |.((chk-lo | (has "WITHIN" (tip rcp st0))))
::  a run that knows neither where it is nor which recipe is not a run
++  test-state-rejects-stepless
  |.  %+  chk-state  ~
      (state-from-json:rec (need (de:json:html '{"recipe":"demo"}')))
++  test-state-rejects-nameless
  |.  %+  chk-state  ~
      (state-from-json:rec (need (de:json:html '{"step":"a"}')))
--
