# Tools

Development tooling for this template. Verified on Godot **4.7.2.stable.official**,
`addons/std` **v5.1.0** and gdtoolkit **4.5.0**.

| Path | Purpose |
| --- | --- |
| `tools/check.gd` | Every project-content check, as a registry of rules. |
| `tools/sync-translations.sh` | Validates, updates and compiles the `.po` catalogue. |
| `.claude/hooks/gd_on_edit.sh` | Runs format, lint and the checker on each file edit. |
| `.claude/skills/godot-api/dump_api.sh` | Dumps engine, std and project API references. |

`tools/` holds scripts with a consumer other than Claude — CI, a hook, or a human. A
script only ever run by Claude, as one step of one workflow, ships beside its
`SKILL.md`; hooks live next to the `settings.json` that calls them. That is why the
dump script and the hook are not in this directory: both ship elsewhere as a Claude
plugin, and a plugin cannot carry a file out of `tools/`.

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

### One binary rather than one script per check

Rules share a single Godot boot, because the boot is almost the whole cost:

| Operation | Time |
| --- | --- |
| Engine binary alone (`--version`) | 0.1s |
| This project plus a no-op script | 1.2s |
| `check.gd`, one file | 1.4s |
| `check.gd`, all 224 files | 8.0s |
| `gdformat` then `gdlint`, one file | 1.9s |

A rule declares its name, the extensions and roots it covers, and a check function;
discovery, dispatch and `--list` all derive from the registry, so adding one touches
no shared code. Add a rule only after a pitfall has bitten twice.

### Files a missing GDExtension makes unreadable

`EXTENSION_SCRIPTS` maps a `.gdextension` to the scripts naming its API. When the
extension is absent those scripts cannot parse, so a file whose `[ext_resource]`
headers reach one has the rules that load it skipped; its text-only rules still run,
and the count is printed rather than swallowed.

The vendored GodotSteam submodule ships macOS and Windows binaries and no Linux
build, so a Linux runner has no `Steam` singleton and seven files would otherwise
report as defects of their own.

The unit is a script, not a directory. `system/input/steam/observer.gd` never names
`Steam` and compiles anywhere, and the `.tres` files beside it are plain data;
blocking the directory would take those too, and with them every scene that depends
on them, which is most of the input and platform wiring.

### What it does not cover

`project.godot` holds the same kind of fragile path string as a scene does — the main
scene, the autoloads, the bus layout, the translation list — and is out of scope. It
is neither a scene nor a resource, the engine reads it before any of this runs, and
several of its entries name files that carry no uid at all. Scripts are out of scope
too: `preload` breaks loudly at compile time, which `compile` already catches.

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
requested code to stderr and discarding it. A tool gets one bit, and the caller reads
the output for the rest.

**A missing `[ext_resource]` target does not fail a load.** The engine prints a parse
error, then the scene loads, `instantiate()` succeeds, and the node that needed the
dependency is simply absent. `ResourceLoader.load()` returns a valid `PackedScene`, so
`load` sees nothing wrong and `path-ref` validates those headers instead. The engine
prefers the uid and falls back to the path, so a header is broken only when neither
resolves.

**A path held in a string property is never rewritten.** The engine's move and rename
fixup covers `ext_resource` headers and nothing else, so `StdScreen.scene_path`, its
attachment and dependency lists, and `StdConditionLoader.scene` point at nothing the
moment their target moves — silently, since nothing reads the string until the screen
is pushed or the condition allows. A `uid://` reference survives, because the id
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
`check.gd --fix` on any file the checker covers — one Godot boot for every rule that
applies. A repair is reported like a failure so the agent learns the file changed
under it; the engine cannot distinguish the two through an exit code, so the label
stays neutral and the checker's output says which it was.

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

The `project/core/` branch runs a fast simulation test and is guarded on a `*_test.gd`
actually being present. Without that guard it is not inert: run against a directory
holding no test, GUT spends 3.3s to report that nothing ran and exits 0 while doing
it, so the cost is invisible.
