# hatchery

Grubbery applications, followed into a ship as one desk. The apps here were
migrated out of the grubbery kernel one commit at a time; the kernel now
ships only the shell, tiles, explorer, mcp, peers, notifications, forge, and
github. This file is for whoever works on the hatchery next, human or agent:
what the repo is, how it reaches a ship, and the loop used to build it from
inside grubbery.

## Layout

`code/` is the followed desk.

- `bill.json` maps an instance name to a neck. `"counter.counter": "/counter/app"`
  spawns a nexus named `counter.counter` from `nex/counter/app.hoon`. The
  suffix after the dot is the nexus type, the same way `forge.git_forge` is a
  `/git/forge` nexus. It is never the desk's name. An app keeps its own type
  wherever it is installed.
- The trailing `/app` in the neck is the file. An app is a directory,
  `nex/<app>/`, with `app.hoon` as its root nexus and its assets, sub-nexuses
  (`agent.hoon`, `bridge.hoon`), and pages beside it. Imports inside are
  relative (`./index.html`).
- `version.json` is the update gate. The desk keeps this file and re-syncs the
  whole tree when it changes. A code change without a bump does not deploy.
- `lib/` and `mar/` are shared code. A directory ending in `-bundle` is data to
  whatever imports it, not code of this namespace; tool bundles live there.
  `mar/` holds only marks no other namespace provides.
- `man/<app>/` holds an app's handbook pages.

Everything under `nex/` compiles whether or not the bill names it. An app
with code here and no bill entry is dormant: present, compiled, not spawned.

## How it reaches a ship

Two nexuses do the work. A forge repo instance holds a clone of this repo
with a checked-out working tree. A desk follows that tree's `code` directory
and spawns the bill.

```
/apps/forge.git_forge/repos/hatchery.git_repo/        the clone
  config.json                                         {repo, ref, account, author_name, author_email}
  poll.json                                           {minutes}; 0 = pull only when poked
  run.git-action                                      the serial command lane and its log
  data/tree/                                          the working tree (this repo)
  data/ui/current.json                                {hash, branch, remote}
  data/ui/status.json                                 {clean, staged, unstaged, untracked}

/apps/shell.shell/desks/hatchery.desk/                the follower
  source.json                                         {"code": ".../hatchery.git_repo/data/tree/code"}
  version.json                                        the version it last applied
  desk/code/                                          the synced code namespace
  desk/data/<instance>/                               each app's root, born jailed
```

On a fresh ship the shell does this itself: `default-repos` in the shell
names this repo, and `ensure-pairing` creates the repo instance, pokes a pull,
creates the desk, and writes its `source.json`. "Sync all" on the desks tile
or `POST /desks/sync-defaults` re-runs it. Before that entry existed the same
pairing was made by hand from inside the ship, which is how any repo not on
the stock list gets in:

1. `forge_create_repo` with `name` and `remote`, called into the forge's tools
   nexus (`call_tool` with `path: /apps/forge.git_forge/tools`). Give the
   remote as `owner/repo`. A full `https://...git` URL is stored verbatim and
   discovery answers 404 on it.
2. `git_cmd` at the same path with the repo instance's path and `pull`. Read
   `run.git-action` afterwards: its log says `cloned`, `fetched N new objects`,
   `already up to date`, or the error.
3. `create_desk` with `name` and `source` pointing at the tree's `code`. It
   crashed once part way, leaving a desk with a null `source.json`; writing
   `{"code": "<path>"}` into that file by hand finished the job.

An app's root on the ship is therefore
`/apps/shell.shell/desks/hatchery.desk/desk/data/<instance>`, not
`/apps/<instance>`. Nothing in this repo may assume otherwise.

## The loop

The working copy is the ship's. The repo instance's tree at `data/tree/` is
edited in place, committed through the instance's command lane, and pushed
to GitHub from the ship. A laptop checkout is a mirror and a recovery hatch,
not the place to edit. Everything below is MCP calls against the ship.

1. Write the file: `write_grub` into
   `/apps/forge.git_forge/repos/hatchery.git_repo/data/tree/<path>`. Hoon,
   JSON, and markdown all land as mime; everything under `tree/` must be mime.
   Bump `code/version.json` the same way.
2. The desk is already watching that tree, so the version write deploys at
   once, before any commit. The desk's `version.json` moves to the new number
   and `desk/code` is re-synced.
3. Compile-check every artifact you touched against the desk's namespace, not
   the kernel's: `check_bin` with
   `code: /apps/shell.shell/desks/hatchery.desk/desk/code`,
   `path: /nex/<app>`, `name: app`. Sub-nexuses and bundle tools too
   (`/nex/itinerary` `agent`, `/lib/nostr-bundle/tools` `nostr-feed`). A
   compile error shows nowhere else. The ghostprompter was broken for four
   versions before anyone ran this.
4. `browse` the instance under `desk/data` to see it is born. `read_weir` on
   it to see what it may reach.
5. A new or changed `weir.json` is a new ask. It shows in the shell's Permits
   page; a person approves it there. Until then the app runs under its
   previous grant, or none, and a dart past the fence prints a veto trace in
   the dojo naming the boundary, the road, and the jump. Read those; each one
   was a one-line fix in this repo.
6. When it works, commit and push through the lane: `git_cmd` (call_tool
   with `path: /apps/forge.git_forge/tools`, `path` arg = the repo instance)
   with `add <file>` per file, then `commit -m "..."`, then `push`. Read
   `run.git-action` after each; the log entry says `staged N path(s)`,
   the commit hash, or the refusal. `data/ui/status.json` and
   `current.json` are rebuilt on the data nexus's next reload, so they can
   lag the lane's log by a moment.

Commit needs `author_name` and `author_email` in the repo's `config.json`;
push needs `account` set to a GitHub login the github nexus holds a token
for. All three are empty on a fresh instance and the lane refuses with a
clear message until they are set; `write_grub` the config with them filled
in. `remote set-url` and other unlisted verbs are rejected; the remote is
the `repo` field of `config.json`. The GitHub repo has a branch rule that
asks for pull requests; a direct push by an admin is let through with a
warning.

The other direction, for a change that was pushed from elsewhere: poke
`run.git-action` with `{"command": "pull"}`, or `git_cmd` `pull`. The poll
timer is seeded at zero, so nothing pulls on its own. Then confirm
`data/ui/current.json` is the hash you expect and the desk's `version.json`
has moved.

Other ship-side moves that came up:

- `remote_load` (ship, path, name) re-runs an instance's `+on-load`. Before
  the kernel learned to cascade reloads from a desk release, this was how a
  changed `weir.json` got re-declared so its ask would appear. A version
  bump now does it.
- `poke_grub` on the shell's `sweep.sig` with `{}` makes the shell re-walk
  app roots: new names into `/sys/link`, new asks surfaced, stale followers
  dropped.
- `delete_folder` removes an instance the bill no longer names. Removing a
  bill entry does not cull the directory; the placeholder `hello` from the
  first scaffold had to be deleted by hand.
- Kernel changes go through the grubbery `commit` tool. It often reports a
  timeout; the commit still ran. A fiberio change rebuilds every artifact on
  the ship and every call times out for minutes; wait rather than retry. The
  one case where a commit did not land is `recover: dig: meme` in the dojo:
  the event ran out of loom and rolled back. Verify a kernel commit by
  `grep` on `/code/...` for a string you added before building on it.

## Rules for an app in the hatchery

**Never name your own install path.** An app does not know where it lives.
From a nested fiber, `ancestor-road:io [/x %app] lane` reaches the app
root; `nex-road:io` reaches the current nexus. A page's JavaScript that
needs the app's data root asks the server: serve `GET /api/root` returning
the root, and fetch it before building any other URL. The counter, itinerary,
s3, and ghostprompter pages do this. The counter's page once hardcoded
`/apps/counter.counter/...` and silently showed an empty list once the
counter moved.

**Reach other apps by name through `/sys/link`.** Each app declares a name
in `link.json`; the shell collects every claimant into
`/sys/link/<name>/dest.lanes`, an ordered list, earliest claimant first. From
a fiber, `resolve-link:io '@anthropic'` gives the default root,
`resolve-link-at:io '@notifications' [%& / %'main.sig']` a place under it, and
`poke-link`, `peek-link`, `make-link`, `keep-link` act at a name directly. In
`weir.json`, write the dependency as `@name/...` and also ask for peek on
`/sys/link/`; the shell resolves the name when it writes the grant. This
holds for kernel apps too (`@github`, `@notifications`, `@tiles`, `@forge`).
The file the shell reads is `link.json`; an older `alias.json` is ignored,
which is why `@contacts` resolved to nothing for a week.

**Reads don't resolve.** Resolving a name is a peek on `/sys/link`, which
needs an approved grant. A read route that resolves a proxy before serving
hangs forever on a fresh install. Resolve in the fibers that act, never on
the read path.

**A host's ask covers its nested agents.** Weirs compose by containment: a
nested agent reaches the intersection of its own weir and every host above
it. So a host that births an agent (itinerary per trip, ghostprompter's main
agent) lists in its own `weir.json` everything the agent touches, including
peek on `/sys/link/`, resolves the names in a fiber, and sands the agent
with absolute roads at rise, re-sanding when a name may have moved. An
agent reaching past its host prints a veto at the host's boundary.

**Tool bundles are code.** `lib/<app>-bundle/` is seeded by its host into a
tools instance's own `/code`. Tools reach their own app with
`ancestor-road` and other apps with `resolve-link`. A tool that fails to
build reports its tang as the run result and nothing else complains.

**Syntax that cost real versions.** One element per line inside a tall
`:~`; three on one line parse as a single cell. Don't name a `|=` sample
after an arm it calls (`make` calling `+make` shadows it).

## What a release does to data

A sync rewrites `desk/code` and the kernel reloads the apps it governs.
Grubs under `desk/data` are untouched. `%fall` rows in `+on-load` seed once
and never overwrite; `%over` rows re-declare on every load. A changed seed
for a `%fall` grub needs the live grub patched as well.

## Migrating an app in

The procedure every app here went through:

1. Copy `nex/<app>.hoon` to `nex/<app>/app.hoon`, its assets beside it, its
   libraries to `lib/`, its bundle to `lib/<app>-bundle/`. Keep basenames;
   directories disambiguate. Rewrite imports relative.
2. Replace every `/apps/<x>` in the source with `ancestor-road` (own tree) or
   `resolve-link` / `@name` (other apps). Grep `nex/` and `lib/` for `/apps/`
   and for the instance name; both should come up empty.
3. Add the bill entry with the app's own type. Bump the version. `check_bin`.
4. Carry the data. The old instance under `/apps/<x>` holds the user's grubs.
   `copy_grub` moves one file, `copy_dir` a directory, into
   `desk/data/<x>`. `copy_dir` onto a directory that already exists crashes,
   and the new instance's `%fall` seeds will already have made the empty
   directories, so `delete_folder` the seeded one first, then copy. Grubs
   that read as booms from the copying position still copy; the tool moves
   the raw noun.
5. Approve the ask. Open the page. Fix what breaks. Commit and push.
6. Remove the app from the kernel: its `root.hoon` row, its sources, any
   stock-list or catalog entry. `delete_folder` the old `/apps/<x>` and its
   stale follower under `/apps/shell.shell/sync`.

Kernel references to a moved app (`notify`, tiles, forge, github) go through
link names, so the kernel does not care where it went.

## Known rough spots

- `grant.json` is not visible on app roots though the shell writes it.
  `read_weir` shows the live weir instead.
- A grub under a desk read from outside the desk (the MCP tools read from
  the mcp nexus) comes back as a boom, "no marc", even when the data is
  fine. The desk's own code reads it correctly. Check through the app's
  page, not the reader.
- A release that touches a library many apps import rebuilds them all in
  one event. On a small loom this is `meme`. `|pack` first.
- The forge UI does not render this file from the tree view; the grub is
  there and `read_grub` returns it.
- The goals and loops tool roots are still hardcoded. Both are dormant.
