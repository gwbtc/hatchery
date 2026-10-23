# How to write and grow a recipe — read this before creating or changing one

A recipe is a process a clanker follows. It is a graph of steps. Each
step has:

- an aim: the goal of the step, what it is trying to bring about
- an input: what the step expects to have when it starts
- an output: what the step produces
- arrows: the steps or exits it can move to, each with the condition for
  taking it

The chat keeps its place in the recipe across turns. A recipe can enter
another recipe as one of its steps. The tip tab shows where the chat is.

## Why a recipe

An agent follows a recipe for the same reason a person does. A complex
task with many steps gets done:

- in a sequence that has been shown to work
- with the agent's focus and decisions limited to one step at a time
- without losing its place between turns

A recipe is worth writing when a task is like that: several steps, an
order that matters, and a risk of losing track or deciding too much at
once.

## Inputs and outputs

Write what each step expects and what it produces.

- Name a concrete thing where you can: "a list of the touched files",
  not "an understanding of the change". The next step can refer to it
  and you can find it in the log.
- If the output is clear from the chat, a short line is enough.

Inputs and outputs are advice to the agent. The system does not check
them.

## Start small, test early

1. Start with a few steps. The recipe's own aim, input and output say
   what the whole process takes and produces; the steps cover the
   obvious divisions.
2. Run it before adding to it. The first run usually shows something
   the guess got wrong.

## Where steps come from

Add or split a step when a run shows a seam. A seam is one of:

- the agent did something out of order
- the agent did two things at once that should be separate
- the agent left out something that should have been done

The seam tells you what the new step is.

## Avoiding backtracking and repeated work

- Each step writes its result down, in the chat or in a file. The next
  step uses it instead of working it out again.
- Most arrows go forward.
- An arrow back is for one of two things, and its condition says which:
  - a loop: the same step again for the next item, when a step runs
    over many things
  - a redo: a later step showed an earlier result was wrong

## Exits

A step offers an exit only if it is listed in the step's arrows.

- `done`: the recipe's output is ready.
- `ask`: the step cannot continue without the user. The agent writes
  its question, names `ask`, and the turn ends.
- `abort`: giving up is a valid outcome for this step.

## Budgets

Add budgets after you have seen a run go in circles. Start generous.

- `dwell`: how many messages a step can be held in one visit. Set it
  first; it stops loops.
- `life`: how many messages a step can be used in the whole run.
- `run`: how many messages the whole run can take.
- One level, `normal`, until a second one is needed.

The system enforces budgets, arrows, exits, and that a sub-recipe runs
inside the step that called it. It cannot enforce what the agent reads
or whether it really did a step; that is what the aim is for, and the
log shows whether it worked.

## Sub-recipes

A step can be another recipe: `"recipe": "name"` instead of an aim.

1. Entering the step enters that recipe.
2. When it finishes or aborts, the run returns to this step.
3. This step's arrows say what happens next: one for "it finished",
   one for "it aborted".

Use one when two recipes need the same step, or when a step's aim has
become a list of instructions.

## The file

```
{
  "recipe": "name",
  "aim": ["one sentence", "", "optional description"],
  "input": ["what it takes"],
  "output": ["what it hands back"],
  "start": "first-step",
  "steps": {
    "first-step": {
      "aim": ["..."], "input": ["..."], "output": ["..."],
      "next": { "self": "why you would stay", "other-step": "why you would move",
                "ask": "why you would ask", "done": "when it is finished" }
    },
    "other-step": { "recipe": "another-recipe", "next": { "done": "it came back" } }
  },
  "levels": { "normal": { "run": 20, "steps": { "first-step": { "life": 6, "dwell": 3 } } } }
}
```

The file lives in the clanker's `recipes/` directory, one file per
recipe, named `<name>.json`.
