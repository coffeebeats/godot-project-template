# Tools

Development tooling for this template. Verified on Godot **4.7.2.stable.official**,
`addons/std` **v5.1.0** and gdtoolkit **4.5.0**.

| Path | Purpose |
| --- | --- |
| `tools/check.gd` | Every project-content check, as a registry of rules. |
| `tools/bridge.sh` | Drives a running game: state, `eval`, screenshots, its log. |
| `tools/bridge.py` | The bridge client itself; `bridge.sh` picks its interpreter. |
| `tools/aseprite.sh` | Bakes `.aseprite` to a PNG sheet plus a tag manifest. |
| `tools/sync-translations.sh` | Validates, updates and compiles the `.po` catalogue. |
| `.claude/hooks/gd_on_edit.sh` | Runs format, lint and the checker on each file edit. |
| `.claude/skills/godot-api/dump_api.sh` | Dumps engine, std and project API references. |

The last two live outside `tools/` because both ship elsewhere as a Claude plugin, and
a plugin cannot carry a file out of this directory. AGENTS.md has the placement rule.

## `tools/check.gd`

Reports problems that a normal boot or import does not surface, and repairs the ones
that can be repaired.

```sh
godot --headless -s tools/check.gd                  # every rule, every file
godot --headless -s tools/check.gd -- a.gd b.tscn   # only the given files
godot --headless -s tools/check.gd -- --fix a.tscn  # repair, then re-check
godot --headless -s tools/check.gd -- --list        # print the rule registry
```

| Rule | Covers | Reports | Fixable |
| --- | --- | --- | --- |
| `compile` | `.gd` | a script that does not compile | |
| `uid` | `.tscn` `.tres` | a header carrying no `uid=` | yes |
| `path-ref` | `.tscn` `.tres` | a reference that does not resolve, and a `res://` string that should be a uid | yes |
| `load` | `.tscn` `.tres` | a file that does not parse or instantiate | |
| `script-order` | `.tscn` `.tres` | a property assigned ahead of `script =` | |
| `nodepath` | `.tscn` | a `NodePath` export that resolves to null | |

Every rule but `compile` is scoped to `project/`, `system/` and `platform/`;
`compile` covers everything outside `addons/` and `script_templates/`.

It exits non-zero when there is something to read, whether that is a problem found or
a repair applied, and cannot say which through the exit code. Follow a `--fix` run
with `godot --import --headless` so the assigned uids resolve.

The full scan is a step in the `test` job of `check-project.yaml`, ahead of GUT, so a
project that will not load reports as one legible line rather than as whatever GUT
makes of it. CI runs it without `--fix`, since a check job reports rather than edits.

### One Godot boot for every rule

The boot is almost the whole cost:

| Operation | Time |
| --- | --- |
| Engine binary alone (`--version`) | 0.1s |
| This project plus a no-op script | 1.2s |
| `check.gd`, one file | 1.4s |
| `check.gd`, all 224 files | 8.0s |
| `gdformat` then `gdlint`, one file | 1.9s |

A rule declares its name, the extensions and roots it covers, and a check function.
Discovery, dispatch and `--list` all derive from the registry, so adding one touches no
shared code.

### Files a missing GDExtension makes unreadable

`EXTENSION_SCRIPTS` maps a `.gdextension` to the scripts naming its API. When the
extension is absent those scripts cannot parse, so a file whose `[ext_resource]`
headers reach one has the rules that load it skipped; its text-only rules still run,
and the count is printed rather than swallowed.

The vendored GodotSteam submodule ships macOS and Windows binaries and no Linux
build, so a Linux runner has no `Steam` singleton and seven files would otherwise
report as defects of their own.

The unit is a script, not a directory. `system/input/steam/observer.gd` never names
`Steam` and compiles anywhere, and the `.tres` files beside it are plain data, so
skipping the whole directory would drop most of the input and platform wiring from CI.

### What it does not cover

`project.godot` holds the same kind of fragile path string as a scene does, including
the main scene, the autoloads, the bus layout and the translation list. It is neither a
scene nor a resource, the engine reads it before any of this runs, and several of its
entries name files that carry no uid at all. Scripts are out of scope too, since
`preload` breaks loudly at compile time and `compile` already catches that.

## Engine behavior the checker is shaped around

Each of these returns a plausible wrong answer rather than an error.

**`--check-only` does not register autoload singletons.** Every script referencing
`Lifecycle`, `Platform`, `Systems` or `Main` reports a false `Identifier not found`.
Loading a script from inside a running `SceneTree` resolves them, which is what the
`compile` rule does.

**A script that failed to parse still loads as non-null.** A null check proves
nothing. A compiled script always resolves a native base type, so an empty
`get_instance_base_type()` is the signal. `Script.reload()` looks like the cleaner
signal and cannot be used: it errors on any script that already has live instances,
which most resource scripts here do.

**Re-loading the running script hangs the engine.** `ResourceLoader.load` with
`CACHE_MODE_IGNORE_DEEP` on the script executing under `-s` never returns, so
`compile` skips its own path. `ResourceLoader.has_cached()` is not a usable
substitute for that skip, since it reports true for scripts the process never loaded.

**A parse error in a `preload`ed script exits 0.** A broken entry script exits 1, but
a broken script it `preload`s prints `Failed to compile depended scripts` and the
process exits 0 having run nothing. That is why every rule lives in one file; a
checker split across files would report success while checking nothing.

**`SceneTree.quit(code)` collapses every non-zero code to 1** under `-s`, printing the
requested code to stderr and discarding it.

**A missing `[ext_resource]` target does not fail a load.** The engine prints a parse
error, then the scene loads, `instantiate()` succeeds, and the node that needed the
dependency is simply absent. `ResourceLoader.load()` returns a valid `PackedScene`, so
`load` sees nothing wrong and `path-ref` validates those headers instead. The engine
prefers the uid and falls back to the path, so a header is broken only when neither
resolves.

**A path held in a string property is never rewritten.** The engine's move and rename
fixup covers `ext_resource` headers and nothing else, so `StdScreen.scene_path`, its
attachment and dependency lists, and `StdConditionLoader.scene` point at nothing the
moment their target moves. It fails silently, since nothing reads the string until the
screen is pushed or the condition allows. A `uid://` reference survives, because the id
travels in the target's own header.

**Uid resolution reads a cache a script process does not rebuild.** A reference to a
target created since the last import reports as unknown, and a `res://` string naming
that target is left unconverted. Both settle after `godot --import --headless`. Ids
derive from the path, so every machine assigns the same uid to the same file.

**Quitting mid-load produces parse errors for well-formed scenes.** A
`godot --headless --quit` boot reports five to seven scenes failing in
`_parse_node_tag`, and the failing set changes between runs; the engine is tearing
down while threaded loads are still in flight. Thirty frames is enough for the count
to reach zero, so use `--quit-after 30`. A boot is therefore not a substitute for the
`load` rule, which loads synchronously.

## The edit hook

`.claude/hooks/gd_on_edit.sh` runs gdformat and gdlint on `.gd` edits, then
`check.gd --fix` on any file the checker covers. A repair is reported like a failure so
the agent learns the file changed under it; the engine cannot distinguish the two
through an exit code, so the label stays neutral and the checker's output says which it
was.

It fires on `Edit` and `Write` only, so a file written any other way stays unchecked
until a full run. Three things it must get right:

- The payload carries a **native absolute path**, which the engine cannot resolve
  against the project root. The hook converts it to a project-relative path with
  `cygpath`.
- Blocking feedback must go to **stderr**; anything written to stdout is not
  surfaced, and the failure appears as "No stderr output".
- Every headless run prints the engine banner, godotsteam's settings conversion, and
  the leaked-object and resources-in-use notices emitted during teardown. None is
  actionable and all of it buries the lines that are, so the hook drops those by
  exact match. Script errors and warnings are never filtered.

The `project/core/` branch runs a fast simulation test, guarded on a `*_test.gd`
actually being present. Run against a directory holding no test, GUT spends 3.3s to
report that nothing ran and exits 0, so the cost would be invisible.

## `tools/bridge.py`

Inspects and drives a game that is already running. Files, the checker and GUT cover
everything that can be judged without a live process; this covers what is on screen,
what the scene tree looks like right now, and what the game just logged.

```sh
tools/bridge.sh launch                       # start the game, wait until it is usable
tools/bridge.sh status                       # frame, current scene, registered commands
tools/bridge.sh tree --path Main             # names, classes, visibility, control rects
tools/bridge.sh eval 'Main.screens().get_depth()'
tools/bridge.sh call app                     # a handler the running scene registered
tools/bridge.sh screenshot --out shot.png    # or --node <path> to crop to one control
tools/bridge.sh logs                         # what the game printed
tools/bridge.sh wait --for app.booted        # poll until a handler reports ready
tools/bridge.sh stop
```

`--port` (default 9080) selects the instance, so several games can run at once, and it
goes before the subcommand. Python 3 and its standard library are the only requirements,
and none of this ever runs in CI.

`tools/bridge.py` holds the client. `tools/bridge.sh` is the entry point because a
`python` on `PATH` is not always a program; see
[below](#driving-it-from-a-windows-shell).

Node paths for `tree --path` and `screenshot --node` are relative to `/root`, so it is
`--path Main`, not `--path /root/Main`. The absolute form still works, but an MSYS shell
mangles it before the tool sees it.

### Gating

Two independent gates, because the bridge evaluates arbitrary expressions on request:

1. `system/system.tscn` mounts it through an `StdConditionLoader` whose expression is
   `debug_build_expression.tres` (`OS.has_feature("debug")`), so a release export never
   places the node. The same mechanism gates the Steam storefront in
   `platform/storefront/storefront.tscn`.
2. The node listens only when handed a port, either `--bridge-port <N>` after `--` or
   `GODOT_DEBUG_BRIDGE_PORT` for editor runs, where run arguments are a per-machine
   editor setting that cannot be committed. An ordinary F5, a GUT run and a headless CI
   run therefore open no socket.

It binds `127.0.0.1` and nothing else.

### The command hook

The bridge knows sockets, JSON, `Expression`, the scene tree and the viewport. It knows
nothing about screens, maps or a simulation; those register handlers on it:

```gdscript
const Debug := preload("res://system/debug/debug.gd")

Debug.register(&"map", _get_debug_state)              # in _ready
Debug.unregister(&"map", _get_debug_state)            # in _exit_tree
```

Both calls are safe when no bridge is present, so a call site needs no feature check of
its own. `unregister` takes the handler because a screen transition has the incoming
scene in the tree before the outgoing one leaves it, and an unqualified erase would drop
the handler its replacement had just registered.

The template registers two: `app` from `project/main/main.gd` (current screen, stack
depth, save slot, and whether the app is settled and booted) and `map` from
`ProjectMap`, which every inherited map gets for free.

`wait` polls one of these handlers from the client rather than evaluating a predicate in
the engine, which keeps the bridge simple and lets a failure in the game's log end the
wait early.

### Engine behavior the bridge is shaped around

**`Expression` resolves no autoloads, no global classes and no engine singletons.** It
sees only what `parse(source, names)` was given, so the bridge extracts the identifiers
from the expression and binds the ones it recognises. Without that, `Main.screens()`
fails with `Invalid named index 'Main' for base type Object`. The singleton half is not
obvious, because `ResourceLoader` and `OS` read like built-ins; they are not, and
`ResourceLoader.load(...)` fails the same way until it is bound.

**A pop emits `screen_uncovered`, never `screen_entered`.** Anything tracking whether a
transition is in flight has to clear its flag on both. Clearing on `screen_entered`
alone leaves the app reporting `settled=false` forever after one push and pop, and
`wait` times out on an idle, usable game.

**"Settled" is not "booted".** Each splash screen is a genuine settled state. Sampled
through a real boot, before the menu appears:

```text
settled=False booted=False screen=res://project/main/splash/godot_screen.tres
settled=True  booted=False screen=res://project/main/splash/godot_screen.tres
settled=True  booted=False screen=res://project/main/splash/studio_screen.tres
settled=True  booted=True  screen=res://project/main/menu/screen.tres
```

A client that waits for "settled" acts on the splash, and reports on a scene that is
ignoring it. `Main._is_booted()` excludes the loading and splash screens, which is why
it lives in `project/` and not in `system/`.

**An aborted client leaves the game holding the port.** The next `listen` fails with
`Already in use` (`ERR_ALREADY_IN_USE`, error 22) and the new instance runs on with no
bridge. `launch` reaps first with a graceful `quit` over the port, then the pid it
recorded for that port, after checking the pid still names a Godot process, since pids
are recycled. A port held by an editor-launched game is reported as that rather than
killed.

**`StdLogSinkGodot` drops the context dictionary for warnings and errors.** It hands
`push_warning` the message alone, so anything the reader needs has to be in the message
string. `info` and below keep their context.

**The viewport image is read after `await RenderingServer.frame_post_draw`.** Two
attempts to show that the await is required did not succeed: awaiting `process_frame`
instead still produced a complete frame, and a probe which changed `ColorRect.color` and
captured on both sides of the draw produced two byte-identical images, because that
setter queues its redraw for the *next* frame. It is kept as cheap insurance rather than
a demonstrated requirement.

**A coroutine that never resumes takes its reply with it**, leaving the client waiting
on a socket nothing will ever write to. Every awaiting command carries a
`SceneTreeTimer` watchdog for that reason.

### Capturing the game's output

A detached windowed process writes its errors nowhere the caller can see, so `launch`
captures the game's output to a log beside the pid file in the OS temp directory. That
also catches what an in-engine `Logger` tap could not, including an error raised before
the bridge mounts and a crash. `logs` tails it through the same noise filter the edit
hook uses, and `wait` scans it as it polls, so a game that dies during boot reports

```text
bridge: the game reported an error: ERROR: Node not found: "NoSuchNode" (relative to "/root/Main").
```

in a couple of seconds rather than timing out sixty seconds later.

A wait only counts what the game logged after that wait began. The log outlives the
command that wrote to it, so scanning it whole let one stale line, such as a screenshot
written to an unwritable path an hour earlier, make every later `wait` abandon a healthy
game. `launch` truncates the log, so its own wait reads the whole run.

`wait --equals` decodes its argument as JSON when it can, so `--equals true` matches the
boolean the game reported rather than the string `True`, and `--equals` on a screen
compares against `app.screen`, which is the `StdScreen`'s `res://` path.

`stop` sends the notification a window close sends, and `Lifecycle.shutdown()` answers
it by printing `print_orphan_nodes` in an editor-feature build, so `logs` after a stop
can end on `Stray Node: …`. That is the project's own shutdown diagnostic, not a failure
of the run.

### Driving it from a Windows shell

Two things bite in an MSYS or Git Bash shell, neither of them the client's doing:

- **A `python` on `PATH` need not be a program.** A pyenv-win shim is a shell script
  that re-enters `pyenv`, which is a batch file, so `cmd.exe` re-parses the arguments
  and any expression containing parentheses dies with
  `.get_depth( was unexpected at this time` before Python starts. `tools/bridge.sh` asks
  pyenv for the interpreter itself and falls through to `PATH` everywhere else; `PYTHON`
  overrides the search.
- **MSYS rewrites an argument that looks like an absolute Unix path**, so a typed
  `--path /root/Main` arrives as `C:/Program Files/Git/root/Main` and matches nothing.
  Node paths are therefore relative to `/root` (`--path Main`). `MSYS_NO_PATHCONV=1` is
  not the answer: it also stops the conversion of `--out`, which does want it, and the
  screenshot is then written somewhere like `C:\c\msys64\tmp\...`.

## `tools/aseprite.sh`

Bakes `.aseprite` sources to a horizontal PNG sheet plus a tag manifest, both read by
Godot's stock importer. Verified against **Aseprite 1.3.18.3**.

```sh
tools/aseprite.sh assets/src/hero.aseprite       # beside the source
tools/aseprite.sh --out assets/baked assets/src  # a whole directory
```

The export command:

```sh
aseprite -b src.aseprite --sheet out.png --sheet-type horizontal \
         --data out.json --format json-array --list-tags
```

`--list-tags` is what emits `meta.frameTags[]`; without it the data file describes no
animations at all. There is no `--trim`, because uniform full-canvas frames are what
`hframes` and `SpriteFrames` expect.

### The manifest

Aseprite's own JSON carries `meta.image` as an absolute path and `meta.version` as the
installed binary, so committing it verbatim churns the file on every machine and every
upgrade. What is kept is what a consumer reads:

```json
{ "source": "sprite.aseprite", "size": [64, 16], "frame_size": [16, 16],
  "frames": [{"duration": 100}, {"duration": 200}],
  "tags": [{"name": "idle", "from": 0, "to": 1, "direction": "forward"}] }
```

Durations are milliseconds and `direction` is `forward`, `reverse` or `pingpong`; a tag's
`repeat` is carried through when 1.3 emits it.

Both halves go through the stock importer with nothing else installed: the PNG imports as
a `CompressedTexture2D` with a `.import` sidecar, and `load()` on the manifest returns a
`JSON` whose `.data` is the dictionary above. Read numbers out of it with `int(...)`,
since JSON has one number type and `from` and `to` arrive as floats.

No `SpriteFrames` generator ships with this. The manifest carries what one needs: the
frame size, each frame's duration, and every tag's range and direction.

### The fixture

`tools/testdata/sprite.aseprite` is four 16x16 frames with distinct colours, two tags and
a different duration per frame, so a manifest that loses tags, reorders frames or drops
timing is visibly wrong. It is generated rather than hand-drawn, and regenerating it is:

```sh
aseprite -b --script tools/testdata/make_sprite_fixture.lua
```

`tools/.gdignore` keeps all of this out of the import pipeline.

### What fails silently

**Never filter `*.aseprite` in an export preset.** A filter matching a source also drops
the `.res`/`.sample` baked beside it, and nothing says so until an exported build looks
for the asset at runtime. The presets here filter only `LICENSE.*`, `*.md` and tests.

**Outputs are named after the source's basename.** Two sources called `hero.aseprite`
in different directories and one `--out` would overwrite each other, so the script
refuses the second rather than baking it; give them distinct names or separate `--out`
directories.

**The binary's path is per-machine.** It is found through `ASEPRITE`, then `PATH`, then
the usual install locations.
