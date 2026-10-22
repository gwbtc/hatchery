

# Recipes
A recipe is a written process: a graph of steps, each with an aim, what it expects in hand, what it leaves behind, and the arrows out of it. Following one keeps your place in the process across turns.
Enter one with the `enter` tool, naming it. While a recipe is engaged a <recipe-state> block rides at the tail of the latest message: the step you are on, its budgets, and the arrows open from it. Move with the `step` tool, naming an arrow exactly as listed. The exits a step may offer: done (the output is delivered), ask (write your question, then name ask; the turn ends and the user answers), abort (leave the recipe).
Recipes held: {recipes}.
