# Tools

Development tooling for this template. Verified on Godot **4.7.2.stable.official**,
`addons/std` **v5.1.0** and gdtoolkit **4.5.0**.

| Path | Purpose |
| --- | --- |
| `tools/bridge.sh` | Drives a running game: state, `eval`, screenshots, its log. |
| `tools/bridge.py` | The bridge client itself; `bridge.sh` picks its interpreter. |
| `tools/aseprite.sh` | Bakes `.aseprite` to a PNG sheet plus a tag manifest. |
| `tools/sync-translations.sh` | Validates, updates and compiles the `.po` catalogue. |

## Python tooling

The bridge client and repository tooling use the dependencies in `pyproject.toml`, locked
in `uv.lock`. Run the same checks as CI with:

```sh
uv lock --check
uv run ruff check .
```

Ruff checks the Python tooling, including `tools/bridge.py`; `custom.py` is excluded
because it is a SCons build-options file rather than a Python program.

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
goes before the subcommand. The standard library is the only requirement beyond the
interpreter, and none of this ever runs in CI.

`tools/bridge.py` holds the client; `tools/bridge.sh` runs it through `uv run`, which
supplies the interpreter.

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

**The viewport image is read after `await RenderingServer.frame_post_draw`.** This is
kept as cheap insurance rather than a demonstrated requirement: awaiting `process_frame`
instead still produced a complete frame, and toggling `ColorRect.color` across the draw
produced byte-identical images, since that setter's redraw queues for the next frame.

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

MSYS rewrites an argument that looks like an absolute Unix path, so a typed
`--path /root/Main` arrives as `C:/Program Files/Git/root/Main` and matches nothing.
Node paths are therefore relative to `/root` (`--path Main`). `MSYS_NO_PATHCONV=1` is
not the answer, since it also stops the conversion of `--out`, which does want it, and
the screenshot is then written somewhere like `C:\c\msys64\tmp\...`.

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
