# Hatchery Style Guide

## Layers

- In the nexus the main fiber is `+on-file`: the switch that says which grub
  runs what. Each of its cases reads as a stepwise sequence of instructions.
- Every fiber reads as a stepwise sequence of instructions, each one at a
  single level of abstraction. A fiber that drops below its own level for a
  few lines has found a helper.
- A fiber calls out to pure functions and helper fibers, which consolidate
  the work one layer of abstraction down.
- A computation that is a synchronous pure function of some piece of state is
  defined as one — possibly a core with several arms manipulating that state.
- Helpers that coalesce on a theme get grouped.
- A library is what they are pulled out into when another application demands
  the same functionality — or earlier, if the group is simple and clear enough
  to stand alone and pulling it out significantly unclutters the nexus.
- A fiber or function that works a grub the way any nexus would — not this
  app's own notion of it — eventually belongs in the io every fiber already
  holds, `/lib/fiberio`. The bar is that a nexus without it writes the same
  thing by hand. Below that bar it stays an app's own; an app's convenience
  in the io is something every nexus then carries.
- Don't maintain an HTTP endpoint for something the kernel's API already
  serves. The page reaches the namespace through peek, make, poke, cull and
  keep; an endpoint of your own over your own data is a second way to do what
  already works, with its own permissions and its own bugs.
- Data the code does not compute is a file. A declaration, a seed, a table of
  names — anything whose value is just written down — is imported beside the
  nexus, not assembled by an arm. An arm earns its place when the value is
  derived from state or chosen by a condition.
- A file says what it is in its own notation, is readable and editable without
  a compile, and diffs as the thing that changed. The same value spelled in
  Hoon makes a reader step through construction to find out what it says.

## Order

- The main sequence comes first: high-level, structured, skimmable. Reading it
  is what motivates the helper core and the libraries under it.
- The helper core comes after, referenced from above.
- Within the helper core: set up, define, use.
- A file reads top to bottom in order, and skims top to bottom too — the
  structures and their comments alone give the shape.
- A name used before it is defined carries a hint where it is used: what you
  will find when you get there.
- So skipping ahead to a reference and coming back costs nothing. The hint
  held the thread; the detail was never needed to follow it.
- A comment sits with the thing it describes, in the order you meet them.
- Every arm clear and the file still inscrutable means the order is wrong.

## Flow

- Smaller branches first, staircase indentation.
- Separate structuring from switching. A switch selects; it does not build.
  - Give the alternatives a shape — a tagged union — so each branch produces
    one small tagged value and nothing else.
  - Assemble once, after the switch, from that shape.
  - The switch is then a table you can read down: this case, that answer.
  - Short branches keep the cases close together, a few lines apart, so the
    whole switch is visible at once. A branch that builds its result inline
    is twenty lines, and the next case is twenty lines further down.
- No functions defined inline inside another expression.
- A type comes before the code that uses it, with room around it.
- Build data where it is used, when it reads in one pass. Naming a value
  you could have written in place is indirection with nothing behind it.

## Comments
### Layout

- No empty lines. A line that separates is `::`.
- A block comment ends with a bare `::` line, then the thing it describes. No
  line before it.
- A preceding block sits above an arm or a structure.
- Inline `::` lines sit inside, one before each step of multi-step work.
- A run of declarations — imports, rows — takes a trailing `::` on each line,
  aligned in a column, saying what that one is.
- Switch cases are spaced apart. Each takes a block above it like any other
  thing a comment describes — the text, then a bare `::`, then the case. A
  bare `::` alone where there is nothing to say. Cases run together are a
  wall.
- Any single line takes a trailing `::` when it needs a word and does not need
  a line of its own: one binding among many, one row in a list that is not
  obvious from its name.
- Longer than a few lines becomes bullets, or a one-sentence summary with
  notes beside the items. Break at the joints, don't wrap prose.
- A section header is a label: `::  /itinerary frontend UI - page and assets`.
  Name it, then list what is in it.

```
/&  name   ./file.ext    ::  what this one is
/&  other  ./other.ext   ::  and this one
=/  thing  (compute a b)                 ::  what it is for
::
::  +arm-name: what it is and what it does.
::
++  arm-name
  ...
  ::  why this step
  ...
  ::  why this one
  ...  ::  and an aside about this line
```

### Prose

- A block says what the thing is and what it does. Prose is fine. Arguments,
  result, purpose and common use are what it usually ends up covering, not a
  form to fill in.
- An inline line says why that step is taken.
- Explain, don't restate. A comment that paraphrases the hoon under it is
  noise.
- One line, where the thing is simply the standard pattern.
- Plain. No vague or poetic language, no hedging.
- Cut what the reader does not need here. A mechanism that matters three
  screens away does not belong in an import header.
- Leave the working-out behind. "The way every other nexus serves itself",
  "this is the standard approach", "as discussed" — that is the author
  justifying the choice to a reviewer. The reader learns nothing from it.
- No history. How the code came to be is not the reader's business: no dates,
  no incidents, no "was added to fix", no "used to", no "no longer". That
  belongs in the commit.
- Plans and TODOs are fine. Say plainly what is missing or coming.
- The exception is a scar: a shape forced by a specific pressure, where a
  reader who did not know would undo it. Say what the pressure is and what
  not to do. The test is whether removing the context makes the code
  dangerous to change.
- An example drawn from something that actually happened gets generalised
  until it is no longer that event: the lesson without the anecdote.
- Incomprehensible to someone who did not write it means wrong.
- The test: could someone six months from now understand what this does and
  why it is shaped this way, knowing nothing about when or how it was written?

## Deprecated

- `+rise-wait` does nothing. `prod` is always `~`, so every call falls
  straight through. It reads like crash recovery, which is why it survives.
  Drop the line; don't add new ones.

## Process and Emergence

- Start with a small, concrete objective.
- Build the smallest thing that produces a visible result — something you can
  see, log or assert. Not scaffolding towards a result.
- Look at what it did, not at what it was supposed to do.
- Let that change the objective, then go again. The objective is refined by
  what you learn; it is not a plan being carried out.
- One behaviour per step. Nothing dead, nothing deferred, nothing wired in
  before it has run on its own.
- State what you believe before you test it, so the test can prove you wrong.
- Cut and elaborate at the joints that show up under use:
  - the logic is written twice
  - you cannot name it in a few words, because it does more than one thing
  - the step is lower-level than the lines around it
- Don't write a helper arm for a caller that does not exist yet.
- Make it work before making it read. But a stepwise unfolding process
  preserves far more legibility than a blind random walk, so there is
  usually less to go back and fix than you expect.
