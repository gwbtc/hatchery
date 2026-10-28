# The stage

Every chat has a stage: a pane the owner can open beside the chat (the
`stage` tab of the chat, or the chat's directory with `?view=stage`). The
pane shows `chats/<chat>/stage.layout` and follows it, so each write to
that file reshapes what the owner sees within a second. The file is a
gmux layout. Write the whole file with `write_file`; keep it valid JSON.
Panes whose moment did not change keep their live content; the rest is
built again. `snap` shows you what the owner sees.

## Nodes

A **division** splits a space in two:

```json
{"div": {"dir": "horizontal", "ratio": 0.3, "a": <pane>, "b": <pane>}}
```

- `dir`: `"horizontal"` (a left, b right) or `"vertical"` (a top, b bottom)
- `ratio`: a's share, 0.02 to 0.98
- `fold`: `"a"` or `"b"` to start with that side collapsed; absent otherwise
- a side is a pane, or a bare `{"div": ...}` to nest

A **pane** holds tabs; each tab a history of entries and a cursor:

```json
{"bar": true, "nav": false, "activeTab": 0, "tabs": [
  {"label": "repos", "entries": [{"path": "@forge/repos"}], "cursor": 0}
]}
```

- `bar`: true shows the tabs row. Omit for a bare pane.
- `nav`: false hides the back/forward/path row. Usually false on a stage.
- `label`: the tab's name. Optional.
- an entry is `{"path": <moment>}`, or `{"div": ...}` to nest a split.
- `{"entries": [], "cursor": -1}` is an empty tab.

The file's top level is one node: a `{"div": ...}` or a `{"tabs": ...}` pane.
An empty stage is `{"tabs": [{"entries": [], "cursor": -1}], "activeTab": 0}`.

## Moments

A path names a moment: a place plus optional `?args` saying how it is looked at.

- absolute: `/apps/forge.git_forge/repos`
- by name: `@forge/repos`, `@clanker/projects`
- relative to the stage file's directory (the chat's): `./notes.md`, `../../files/report.md`

Args: a directory takes `?view=rows` (default), `?view=grid`, `?view=tree`;
an app's own views only where the app declares them. A directory an app
opens as a layout (a clanker, a repo, a trip) becomes that layout inside
your pane.

## Routing

A pane may carry `"open": {"to": "#<id>", "mode": "tab" | "replace"}`,
sending the links clicked in it to the pane with that `id` (written as
`"id": "<name>"` on the pane). `#root` is reserved: the owner's whole
workspace, where a link becomes a new top-level tab. A selector on the
left that opens into a tabbed pane on the right is `open: {to: "#content",
mode: "tab"}` with the right pane `id: "content"`, `bar: true`, one empty tab.
