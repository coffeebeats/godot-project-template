# Tools

Development tooling for this template. Results below are from the Milestone 0
tooling spike.

Verified on **Godot 4.7.2.stable.official** (`gdenv`-installed stock build),
`addons/std` **v5.1.0**, gdtoolkit 4.5.0, Windows.

## Contents

| Path | Purpose |
| --- | --- |
| `tools/check.gd` | Every project-content check, as a registry of rules. |
| `tools/sync-translations.sh` | Translation sync. |
| `.claude/hooks/gd_on_edit.sh` | PostToolUse hook wiring format, lint and the checker to file edits. |
| `.claude/skills/godot-api/dump_api.sh` | Dumps engine, std and project API references to `.godot-api`. |

The checker is one binary rather than three scripts because each is a Godot boot,
and this project's boot is 1.07s (see Timings). A rule declares its name, the
extensions and roots it covers, and a check function; discovery, dispatch and
`--list` all derive from the registry, so adding a rule touches no shared code.

```sh
godot --headless -s tools/check.gd                  # every rule, every file
godot --headless -s tools/check.gd -- a.gd b.tscn   # only the given files
godot --headless -s tools/check.gd -- --fix a.tscn  # repair, then re-check
godot --headless -s tools/check.gd -- --list        # print the rule registry
```

Exits non-zero when there is something to read, whether a problem was found or a
repair was applied. It cannot say which through the exit code: `SceneTree.quit()`
collapses every non-zero code to 1 under `-s` (see Engine issues found).

Rules as of this writing: `compile` (`.gd`), `uid` (fixable), `path-ref`
(fixable), `load`, `script-order` and `nodepath`. New rules only after a pitfall
has bitten twice.

The full scan is also a step in the `test` job of `check-project.yaml`, ahead of
GUT, which is the first time a checker rule gates a PR. It runs without `--fix`:
a repair rewrites files and needs a re-import to resolve, and a check job reports
rather than edits. A fresh checkout is enough — `godot --headless --quit --import`
alone populates the uid cache the `path-ref` rule reads, verified by moving
`.godot` aside and re-running both.

**Placement.** `tools/` holds scripts with a consumer other than Claude — CI, a
hook, or a human. A script only ever run by Claude, as one step of one workflow,
ships beside its `SKILL.md`; hooks live next to the `settings.json` that calls
them. That is why the dump script and the hook are no longer in this directory:
skills and hooks ship to the monorepo as a Claude plugin, and a plugin cannot
carry a file out of `tools/`.

## Timings

Measured per invocation on this machine. The engine itself is cheap; almost all
of the fixed cost is this project's own boot.

| Operation | Time |
| --- | --- |
| Engine binary alone (`--version`) | 0.07s |
| Empty project + no-op script | 0.21s |
| **This** project + no-op script | 1.07s |
| `check.gd`, one `.gd` file | 1.08s |
| `check.gd`, one `.tscn` file (was 2 boots, ~2.1s) | 1.27s |
| `check.gd`, all 224 files | 6.95s |
| *superseded:* `check_scripts.gd`, all 83 | 2.07s |
| *superseded:* `check_scenes.gd`, all 55 | 5.5s |
| `gdformat` then `gdlint`, one file | 1.61s |
| Both in a single Python process | 0.85s |
| GUT, one test file | 2.27s |
| Full test suite (87 tests) | 7.6s |
| `dump_api.sh`, all sources | 7.4s |
| Headless runner, boot + 30 frames | 4.1s |
| Headless runner, same but with splash | 13.4s |

## Milestone 1 results

**`path-ref`** — A file path kept in a *string* property is not rewritten when its
target moves, because the engine's fixup only rewrites `ext_resource` headers.
Nothing reads the string until the screen is pushed or the condition allows, so the
break is silent. The rule reads `res://` and `uid://` literals off every line and
reports an unknown uid, a uid whose target is gone, a path that does not exist, and
a `res://` path whose target has a uid — the last of which `--fix` converts.

It found 13 fragile references in the template, across three properties and not the
one the plan named: `StdScreen.scene_path` (7), `StdConditionLoader.scene` (5) and a
`configurator` path in the controls menu. Scoping the rule to the class of pitfall
rather than to the property that was noticed is the whole difference between finding
those and finding none of them. All were converted, and the app was booted to confirm
the loader takes uids: `StdScreenLoader.load_scene` asserts they are allowed,
`ResourceLoader.has_cached` resolves them, and so — checked because the fixer would
otherwise be able to break code — does `FileAccess`.

Demonstrated against cases built to fail: a malformed uid, an unknown uid, a missing
`res://` target, a convertible reference sharing a line with a missing one (the line
is converted in place and the missing one still reported), and a CRLF fixture
confirming the repair preserves line endings. The 224-file scan confirmed no false
positive on the `ext_resource` headers that legitimately hold `res://` paths.

**A missing dependency is not a load failure** (found while justifying the above,
and the twelfth engine silent failure on this list). An `[ext_resource]` pointing at
a file that does not exist prints a parse error to stderr, and then the scene loads,
`instantiate()` succeeds, and the node that needed the dependency is simply absent.
`ResourceLoader.load()` returns a valid `PackedScene`, so the `load` rule sees
nothing wrong — the skip of `ext_resource` lines was originally justified by
assuming otherwise, and testing that assumption is what turned it up. Because the
checker exited 0, the edit hook stayed silent too, which is where it mattered: this
project hand-writes scene files. The rule now validates those headers without
rewriting them. The engine prefers the uid and falls back to the path, so a header
is only broken when *neither* resolves; a stale path beside a good uid is left alone
and repaired by the editor on the next save.

**What is not covered.** `project.godot` holds the same kind of fragile string — the
main scene, three autoloads, the bus layout, the theme, the translation list — and
is out of scope. It is not a scene or a resource, the engine reads it before any of
this runs, and several of its entries name files that carry no uid at all (`.mo`
translations, `plugin.cfg`). Scripts are out of scope too: `preload` breaks loudly at
compile time, which the `compile` rule already catches.
## Milestone 0 results

### Passing

**gdformat / gdlint** — Clean across the codebase at line length 88. Neither
was wired to fire on edit; `.claude/settings.json` did not exist. It now
registers `.claude/hooks/gd_on_edit.sh` as a PostToolUse hook. Note that
`.gitignore` excluded all of `.claude/`, so the hook config would never have
shipped with the template; `settings.json`, `hooks` and `skills` are now
un-ignored by name.

**Test suite** — 87 tests, all passing.

**Logging profile overrides** — A `game/enemy` logger inherits the profile's
global level (0/DEBUG in `profile_editor.tres`); adding a `"game/": 2` entry to
`level_overrides` raises its effective level to 2, suppressing `debug` while
`warn` still emits. Longest-prefix matching behaves as documented.

**Screen transition signals** — `screen_covered` and `screen_uncovered` fire
*after* the corresponding transition completes, paired on the same frame with
`screen_entered` / `screen_exited` respectively — not at transition start:

```
frame 267  screen_entering  ScreenB
frame 295  screen_entered   ScreenB
frame 295  screen_covered   ScreenA
frame 360  screen_exiting   ScreenB
frame 388  screen_uncovered ScreenA
frame 388  screen_exited    ScreenB
```

`screen_entering` lags `push()` by ~30 frames while the scene loads.

**Script compile checks** — the `compile` rule covers 84 scripts (the project
root, `tests/` and `tools/` included) in 2.07s. Validated against fixtures: it
catches a broken script, a script whose *base* script is broken, and reports no
false positive for `@abstract`, `@tool` or `class_name` scripts. It does not
catch runtime-only faults such as a bad dictionary key, which are not compile
errors.

**`.tscn` checks** — the `load`, `script-order` and `nodepath` rules catch both
known pitfalls, which is
worth doing precisely because **both fail silently**: the scene loads without
error and the problem only appears as wrong behavior at runtime.

1. *Properties assigned before `script =`* are discarded. A property set ahead
   of the script line reverts to the script's declared default with no warning.
   Only script-declared properties are affected — properties belonging to the
   node's base type (`layout_mode`, `anchors_preset`, `theme_override_*`) apply
   regardless, and the editor writes those first by design. Checking naively
   against every preceding property yields 34 false positives here.
2. *A NodePath export pointing at a wrong-typed node* resolves to `null` rather
   than erroring. Detected by instantiating and checking that every assigned
   NodePath export resolves.

All 55 project scenes pass.

**API dumps** — `dump_api.sh` writes ~1300 classes across five sources in 7.4s.
The engine reference carries signatures, types, defaults, signals, inheritance
and enum values but **no prose**, because a release binary does not embed the
description text and `--doctool` regenerates from ClassDB reflection alone.

`--doctool --gdscript-docs <path>` is the more useful mode and does carry prose,
generated from inline `##` comments: 146 classes for `addons/std`, 51 for
`project` (named by `class_name`, e.g. `Main.xml`), plus `system` and
`platform`. Those APIs cannot be looked up anywhere else, which makes them the
part worth dumping.

**Headless runner** — Every capability the runner needs works on the pinned Godot.
A probe (`.probe/runner.tscn`, not a deliverable) boots the app, waits out the
splash, pushes a named screen, injects input, runs N frames and writes a JSON
dump with the collected errors, exiting non-zero when any were seen:

```json
{
  "ok": true,
  "screens": {
    "current": "res://project/menu/settings/screen.tres",
    "stack": ["res://project/main/menu/screen.tres",
              "res://project/menu/settings/screen.tres"]
  },
  "errors": [], "warnings": [], "ignored": 38
}
```

Validated against faults built to fail. A script error, a `push_error` and a
failed `assert` each fail the run with the correct `res://file:line`; a
`push_warning` is recorded without failing:

| injected fault | exit | recorded as |
| --- | --- | --- |
| call on a null | 1 | error, `ERROR_TYPE_SCRIPT` |
| `push_error` | 1 | error, `ERROR_TYPE_ERROR` |
| `assert(false)` | 1 | error, `ERROR_TYPE_ERROR` |
| `push_warning` | 0 | warning |

The `Logger` tap is the right mechanism, with two wrinkles. Engine checks put the
*condition* in `code` and the readable message in `rationale`, so a reader that
prints only `code` shows `Condition "data.blocked > 0" is true` instead of the
actual complaint. And `push_error` / `push_warning` report the engine's own C++
source as `file`/`line`; the calling script is only in `ScriptBacktrace` frame 0.

**A watchdog is not optional.** A script error inside the runner aborts its
coroutine silently — no error propagates to the exit code and the process runs
forever. Only a `SceneTreeTimer` scheduled up front guarantees the run ends.

### Maps run standalone (resolved in std v5.1.0)

All three templates -- `2d`, `2d_pixel` and `3d` -- boot standalone and take the
pause and cancel actions with **zero errors**. F6-ing a map used to produce five.

Four were cleared here: `Main._get_main()` returns null instead of tripping the
assert in `StdGroup.get_sole_member`, and `get_active_save_data()` /
`go_to_main_menu()` handle a missing `Main`.

The fifth was in the submodule. `StdScreenPusher._enter_tree` asserted a
`StdScreenManager` exists; the assert aborted `_enter_tree` before the signal
connections but left the node in the tree with input processing on, so pressing
the map's pause action called `push()` on a null -- a plain runtime error, not
confined to debug builds. Fixed upstream in godot-plugin-std#437: the pusher now
logs one warning and stays inert.

```
WARNING: No screen manager found; pusher disabled.
   at: _enter_tree (res://addons/std/screen/pusher.gd:63)
```

## Engine issues found

**`godot --check-only` is unusable on this project.** Running
`godot --headless -s <file> --check-only` does not register autoload singletons
as global identifiers, so every script referencing `Lifecycle`, `Platform`,
`Systems` or `Main` reports a false `Identifier not found`. Loading the same
script from inside a running `SceneTree` resolves it correctly, which is why
the `compile` rule loads scripts from inside a `SceneTree` instead.

Two further traps in detecting a failed compile:

- `ResourceLoader.load()` returns a **non-null** `Script` for a file that failed
  to parse, so a null check reports nothing. A compiled script always resolves
  a native base type, so an empty `get_instance_base_type()` is the signal.
- `Script.reload()` looks like the cleaner signal and returns
  `ERR_PARSE_ERROR` correctly, but errors with *"Cannot reload script while
  instances exist"* for any script that already has live instances — which most
  resource scripts here do — producing 23 false positives against 83 scripts.

**Re-loading the running script hangs the engine.** Calling
`ResourceLoader.load(self_path, "Script", CACHE_MODE_IGNORE_DEEP)` on the script
currently executing via `-s` never returns. `CACHE_MODE_REUSE` on the same path
is fine. `check.gd` skips its own path for this reason.

`ResourceLoader.has_cached()` is **not** a usable substitute for that skip: it
reports true for scripts the process never loaded, since autoloads pull global
classes in transitively.

**`SceneTree.quit(code)` collapses every non-zero exit code to 1.** Under `-s`,
`quit(2)`, `quit(3)` and `quit(42)` all leave the process returning **1**; the
requested code is printed to stderr as `exit status N` and then discarded. A
tool cannot signal detail — "problems found" versus "I repaired the file" —
through its exit status, so callers get one bit and read the output for the rest.

**A parse error in a `preload`ed script exits 0.** A broken *entry* script under
`-s` exits 1 with `Parse error`, but a broken script it `preload`s prints
`Failed to compile depended scripts` and the process exits **0**, having run
nothing. A checker split across files would therefore report success while
checking nothing. `ResourceLoader.load()` at runtime does not have this problem:
the broken script comes back non-null with an empty `get_instance_base_type()`,
the caller keeps running, and it chooses its own exit code. That is the
difference between a safe split and an unsafe one.

**Quitting mid-load produces spurious parse errors.** A `godot --headless
--quit` boot reports 6-7 scenes failing with
`Parse Error ... at: _parse_node_tag`, and the failing set changes between runs.
This is **not** a race between concurrent loads, and the scenes are not
malformed — it is the engine tearing down while threaded loads are still in
flight. Error count against frames allowed before quitting:

| frames | parse errors |
| --- | --- |
| 1 (`--quit`) | 6 |
| 2 | 7 |
| 5 | 7 |
| 10 | 2 |
| 30 | 0 |
| 100 | 0 |

Requesting the same scenes concurrently with `CACHE_MODE_IGNORE_DEEP` and
waiting for completion gives 0 failures across 5 trials; issuing identical
requests and quitting immediately gives 11. Quit timing is the entire effect.

**Consequence:** a headless boot *is* usable as a tooling signal, provided it is
given frames to settle (`--quit-after 30`) rather than `--quit`. This was
initially misdiagnosed as a threading bug in `StdScreenLoader.load_all_scenes()`
and reported as coffeebeats/godot-plugin-std#432; that report has been corrected
and no change to `load_all_scenes()` is warranted.

## Driving the app headless

Four traps, each of which silently does nothing rather than reporting an error.

**`Input.action_press` does not raise an input event.** It sets the polled action
state only, so `Input.is_action_pressed` sees it but no `_input` or
`_unhandled_input` handler ever fires. Anything driven by handlers — the whole
screen-pusher layer — ignores it. `Input.parse_input_event` with a synthesized
`InputEventAction` or `InputEventKey` does work headless; both were confirmed to
push the settings screen from the main menu.

**Input reaches later siblings first.** A runner added to the root before the app
sees events only after the app has consumed them. Moving it to the end of the
root's children is what lets it observe input.

**Input injected during a screen transition is swallowed.** This is the subtle
one, because it looks exactly like injection not working. `get_current_screen()`
changes at *push* time, but the manager mounts an `_InputBlocker` — a `Control`
that marks every event handled — until the enter transition completes ~30 frames
later. A runner that waits on `get_current_screen()` injects into the blocker and
sees nothing happen. Waiting for `screen_entered` fixes it.

**Headless is not unthrottled.** It runs at roughly 110fps here, so frame counts
and `SceneTreeTimer` deadlines stay related but not equal. The two 3-second
splash screens therefore cost ~10s of every boot; clearing `Main.splash`, which
is exported, skips them without touching the app and cuts a boot-and-30-frames
run from 13.4s to 4.1s.

Also: the app cannot be added to the tree from the runner's own `_ready` — the
root is still setting up children, and `add_child` fails with *"Parent node is
busy setting up children"*. One frame of delay is enough.

**Headless produced error noise that was not a defect** (resolved in std
v5.1.0). A boot to the settings
screen logged 38 errors of *"Not supported by this display server"* from
`addons/std/input/godot/device_glyphs.gd:98`. The call is guarded by a platform
check (`OS.has_feature(&"windows")` and friends) rather than a capability check,
and the platform feature is still true under `--headless`, so the guard passes
and the headless display server's stub errors.

Behavior is unaffected: the failed call returns the keycode it was passed, which
is what the guard's fallback branch produces anyway, so glyphs are correct either
way. It was purely volume. But it landed on the one signal the runner uses to
decide pass/fail, so the runner needed an ignore list — and an ignore list is a
hole in the mechanism meant to catch real errors. Fixed upstream in
godot-plugin-std#439, which gates the call on `DisplayServer.get_name()` as well
as the platform; the same boot now reports `errors=0 warnings=0` with **zero
entries suppressed**, so the runner's ignore list is dead code.

The other unguarded `DisplayServer` calls in std (`keyboard_get_current_layout`,
`keyboard_get_layout_language`, `mouse_get_mode`, `mouse_set_mode`) were checked
and return defaults silently headless. `keyboard_get_label_from_physical` is the
outlier that raises rather than falling back.

## Hook notes

`.claude/hooks/gd_on_edit.sh` runs gdformat and gdlint on `.gd` edits, then
`tools/check.gd --fix` on any file the checker covers — one Godot boot for every
rule that applies. A repair is reported like a failure so the agent learns the
file changed under it; the engine cannot distinguish the two through an exit
code, so the label stays neutral and the checker's output says which it was.
Files written through Bash never trigger the hook; a full `check.gd` run is the
backstop. Three things it must get right, the first two found by the hook firing
for real:

- The payload carries a **native absolute path**. The checkers resolve paths
  against the project root, so an absolute path becomes `res://C:\...` and
  fails. The hook converts to a project-relative path via `cygpath`.
- Blocking feedback must go to **stderr**; anything written to stdout is not
  surfaced, and the failure appears as "No stderr output".
- Every headless run prints the engine banner, godotsteam's settings conversion
  and the leaked-object and resources-in-use notices emitted during teardown.
  None is actionable and all of it buries the lines that are, so the hook drops
  those by exact match. Script errors and warnings are never filtered.

The sim-test branch is wired but inert until a harness exists, and it is guarded
on a `*_test.gd` actually being present. Without that guard it is not inert at
all: run against a directory holding no test, GUT spends **3.3s** to report that
nothing ran — and exits 0 while doing it, so the hook reports nothing and the
cost is invisible. That is 2x the whole hook budget on every matching edit.

## Editor addons

Vendored locally for the spike and **not committed** (both are `.gitignore`d):
`AsepriteWizard` 9.8.0-4 and `gdfxr` 2.1. Note the second is `timothyqiu/gdfxr`,
not the `godot-sfxr` the plan names — that one is Godot 3 only, last touched in
2023. Both load on 4.7.2 with no errors, and both were driven end to end rather
than merely enabled.

| Check | Result |
| --- | --- |
| `.aseprite` → `SpriteFrames` | 2 tags became 2 animations, 2 frames each, 10 fps |
| `.sfxr` → `AudioStreamWAV` | 0.299s, 44100 Hz, 8-bit, 13176 bytes |
| `.sfxr` into `StdSoundEvent1D.stream` | accepted; reloads as `AudioStreamWAV` |
| Aseprite CLI contract | wizard's exact argv works against Aseprite 1.3.18.3 |

Both are import-time only. The wizard shells out to the Aseprite binary and
gdfxr bakes `.sfxr` parameters into an `AudioStreamWAV`, so neither addon is a
runtime dependency and no game code references them.

**`SfxrAudioStream` does not exist.** The plan's `add-sound` item assumes a
custom stream class; gdfxr has none. A `.sfxr` file is referenced like any other
audio file, so the skill needs no new resource type — only the note that the
import is 8-bit 44.1kHz by default.

### Aseprite's path is a global editor setting, not project state

`aseprite/general/command_path` is an **`EditorSettings`** key, so it lives in
`%APPDATA%/Godot/editor_settings-4.7.tres`, is shared by every project on the
machine, and cannot be committed. Two consequences:

- Enabling the plugin **writes** the key, seeded from a Windows default of
  `C:\\Steam\steamapps\common\Aseprite\aseprite.exe` — a literal doubled
  backslash, and a path that is wrong for a non-Steam install. Import fails with
  `Could not create child process` until it is corrected by hand.
- A fresh clone therefore cannot import `.aseprite` sources without a manual,
  per-machine step. Anything that depends on it (CI, a `sprite` skill) has to
  either set the key itself or call the Aseprite CLI directly and skip the addon.

### Export exclusion

`exclude_filter` in all five presets gained `addons/AsepriteWizard/*` and
`addons/gdfxr/*`. Verified by exporting a `.pck` per preset and enumerating its
paths — no export template needed, `--export-pack` alone suffices.

Every preset ships exactly two addon files: `AsepriteWizard/plugin.cfg` and
`gdfxr/plugin.cfg`, a few hundred bytes each. **`exclude_filter` cannot remove
them.** The exporter force-includes the manifest of every plugin listed in
`editor_plugins/enabled`; disabling the plugins drops both files, and no filter
does. Harmless, since an exported build never runs editor plugins, but the
exclusion is not literally complete and a test asserting zero addon files will
fail.

Do **not** add `*.aseprite` or `*.sfxr` to the filter. That was the first
attempt here, and it silently removed the *baked* resources along with the
sources — `.godot/imported/*.res` and `*.sample` both vanished, so a
`load("res://…/foo.sfxr")` would fail at runtime in exported builds only. Godot
keeps the source path in the pack as the remap entry that makes the import
resolvable; filtering the extension breaks the pair. Source art is not shipped
either way, so the filter buys nothing and costs correctness.

## Debug bridge

Validated: it is the highest-risk item in section 10, and it works. `.probe/`
holds a TCP server on `127.0.0.1:7345` speaking line-delimited JSON, hosted by a
scene that boots `main.tscn` the same way the headless runner does. Driven from
an external Python client against a live **windowed** instance, 11/11 checks
passed.

| Command | Result |
| --- | --- |
| `state` | screen stack, depth, node count, fps, window size |
| `eval` | `Main.screens().get_depth()` → `1`; bad calls report cleanly |
| `input` | `ui_toggle_menu` pushed settings (depth 1→2); `ui_cancel` popped |
| `screenshot` | 1920×1080 PNG of the real frame, legible menu text |

Four traps, all of which produce a plausible-looking wrong answer rather than
an error:

- **`Expression` resolves neither autoloads nor global script classes.** It
  knows only engine built-ins, so `Main.screens()` fails with `Invalid named
  index 'Main' for base type Object`. Names have to be passed in explicitly via
  `parse(expr, names)` / `execute(values, self)`. Without that, eval can reach
  the tree through `get_tree()` but not a single one of this project's APIs,
  which is most of what you would want to ask about.
- **`screen_entered` alone is not a readiness signal.** A pop reveals the screen
  underneath with `screen_uncovered`; it does not re-fire `screen_entered`. A
  bridge tracking only `entered` reports "settled" correctly through pushes and
  then hangs forever on the first pop. Both signals must feed the check.
- **A settled screen is not a booted app.** The loading screen is a genuine,
  fully entered intermediate state, so it reports settled at t=0 while the app
  reaches the menu at ~2.3s. A client that waits on "settled" therefore latches
  onto the loading screen and injects input into a scene that ignores it -- and
  since the assertions that follow read a real state, the run fails with
  plausible values rather than a timeout. Boot completion is a distinct
  condition: the settled screen equals `Main.initial`, which the bridge now
  reports as `booted`. The headless runner already gated on this.
- **The viewport image is only complete after the frame is drawn.** Grabbing it
  mid-frame yields the previous frame or nothing; `await
  RenderingServer.frame_post_draw` first.

A stale instance also holds the port, so a client that aborts without sending
`quit` leaves a process that the next launch silently loses the bind to
(`listen` → error 22). The bridge should take a port argument and the launcher
should reap by command line.

## Not yet covered

Nothing outstanding for milestone 0. The itch.io publish path is considered
verified.
