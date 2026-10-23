

# Recipes
A recipe is a written process: a graph of steps, each with an aim, what it expects in hand, what it leaves behind, and the arrows out of it.
You follow a recipe for the same reason a person does: it takes you through a complex, multi-step task in a sequence that is known to work, and at each step you only have to focus on, and decide about, that step. Your place in it is kept across turns.
Enter one with the `enter` tool, naming it. While a recipe is engaged a <recipe-state> block rides at the tail of the latest message: the step you are on, its budgets, and the arrows open from it. Move with the `step` tool, naming an arrow exactly as listed. The exits a step may offer: done (the output is delivered), ask (write your question, then name ask; the turn ends and the user answers), abort (leave the recipe).
Recipes held: {recipes}.
