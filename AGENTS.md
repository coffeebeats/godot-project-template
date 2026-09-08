# AGENTS.md

Godot 4+ project template for 2D games. Game logic goes in `project/`; reusable infrastructure lives in `system/` (autoloads) and `addons/std/` (standard library, a git submodule).

## Project Structure

Three autoloads bootstrap the app (in order): `Lifecycle`, `Platform`, `System`.

- **`project/`** — Game-specific code and assets.
  - **`core/`** — Game logic (empty by default; extend here).
  - **`main/`** — Main scene and app orchestration via `StdScreenManager`. Contains `menu/` and `splash/`.
  - **`maps/`** — Game maps (scenes/levels). `base/` contains style-specific inheritance templates: `2d/`, `2d_pixel/`, and `3d/`. Each has a standalone scene (`.tscn`) and script (`.gd`) with the full apparatus (SubViewport, PausePusher, InputActionSetLoader, UI). `2d_pixel/` extends `2d/` at the script level so it inherits the 2D world-to-screen bridge; the `.tscn` files remain standalone siblings (don't chain scene inheritance). The 3D template includes settings observers for render quality. Create new maps via `Scene > New Inherited Scene` from a template in `base/`.
  - **`menu/`** — Infrastructure menus: pause (`pause/`), save slot selection (`save/`), settings (`settings/`).
  - **`save/`** — Save data schemas (save slot data, summaries).
  - **`input/`** — Input action definitions, including Steam Input actions.
  - **`locale/`** — i18n with 13 pre-configured languages (`.pot` template, `.po`/`.mo` per language).
  - **`ui/`** — Shared UI: screen transitions (fade, slide), input glyphs, modals, tooltips, world-space trackers, theme, font.
- **`system/`** — Game-agnostic autoloaded subsystems (the `System` autoload). Accessed via `Systems.audio()`, `Systems.input()`, `Systems.saves()`.
  - **`audio/`** — Sound event player, music player, mix snapshots, audio bus layout (`game`/`ui` split).
  - **`input/`** — UI navigation, cursor management, gamepad/Steam Input support.
  - **`save/`** — Multi-slot save system (4 slots). Async save/load via background worker. Slot status tracking (OK/EMPTY/BROKEN).
  - **`setting/`** — Setting observers that sync `ProjectSettings` with UI (audio, video, interface).
- **`platform/`** — Platform abstraction (the `Platform` autoload). User profiles and storefront integration with Steam and fallback backends.
- **`addons/std/`** — Standard library (git submodule; do not edit directly). Classes use the `Std` prefix. Key modules: `config/`, `input/`, `save/`, `screen/`, `setting/`, `sound/`, and more.
- **`addons/gut/`** — GUT testing framework.
- **`script_templates/`** — GDScript file templates enforcing project structure (Node, Object, Resource, test, library).
- **`.github/workflows/`** — CI/CD: format/lint checks, tests, multi-platform export (macOS/Windows/Web), release-please automation.

Most changes involve both `.gd` scripts and `.tscn` scene files. Editing UI or wiring nodes typically requires touching both.

## Common Workflows

- **Adding a setting** — Create a `StdSettingsProperty*` resource in `system/setting/<category>/`. Add an observer (extends `StdSettingsObserver`) to react to value changes. Add UI in `project/menu/settings/<tab>/` using `setting.tscn` and a controller node (e.g., `StdSettingsControllerRange`). Wire the observer into `system/setting/settings.tscn`.
- **Adding a save data field** — Create a class extending `StdConfigItem` in `project/save/data/`. Add an `@export` for it in `data.gd` and register it in `data.tres`. Access at runtime via `Main.get_active_save_data()`. If migrating existing saves, bump the version in `ProjectSaveData`, add a `StdConfigSchemaMigration`, and regenerate golden files with `TEST_GENERATE_GOLDENS=1` (see [Testing](#testing)).
- **Adding a screen** — Create a `.tscn` scene and `.gd` script. Create a `StdScreen` resource (`.tres`) pointing to the scene with transition config. Export or preload the resource in `main.gd`. Navigate via `Main.screens().push()`, `.replace()`, `.pop()`, or `.reset()`. Keys that close a screen go in the `StdScreen`'s `close_actions`, beside `overlay_click_to_close`; a closer needs no pusher and no placement. This works with `pause_when_covered` (it disables the covered scene, not the overlay) but not under `get_tree().paused`, which the template never sets. To open a screen with an input action, list a `StdScreenPusher` scene in the `StdScreen`'s `attachment_scenes` instead of placing it in the scene. Write `scene_path`, `attachment_scenes` and `dependency_scenes` as `uid://` strings (the target's header uid), since Godot's move/rename fixup rewrites `ext_resource` references but never a path held in a string; the checker's `path-ref` rule enforces this and `--fix` converts them. Attachments mount into the screen's overlay, so `pause_when_covered` does not touch them and the scene stays runnable on its own. An opener goes on the screen it opens **from**, since it must outlive its target (`project/menu/settings/pusher.tscn` on `project/main/menu/screen.tres`). Both mechanisms only fire if the topmost screen's action set binds the action, since loading an action set rebinds the whole `InputMap`. Pick an action bound by the screen that should respond and unbound by the screens that should stay quiet.
- **Adding a translatable string** — Use the `add-translation` skill. Only edit `messages.pot` and `en_US.po` (key-based `msgid` values); other `.po` files use English text as `msgid` (swapped via `poswap`) and must not be edited directly. Reference keys in scenes via `text` property or in code via `tr("my_new_key")`.
- **Adding an input action** — Add the action to a `StdInputActionSet` resource in `project/input/actions/`. Add default binding in `project.godot` under `[input]`. Add translation with `msgctxt "actions_<SetName>"` to `messages.pot` and `en_US.po`. Scenes load action sets via `StdInputActionSetLoader` nodes. An origin binds to at most one action, so an action added to a layer takes its key away from whatever held it before (`addons/std/input/godot/device_actions.gd:240`). `ui_toggle_menu` and `ui_cancel` are both `Escape` in `project.godot`, and on any screen loading `menu_options.tres` the key goes to `ui_toggle_menu`, leaving `ui_cancel` on the gamepad only.
- **Adding a map** — Pick a style template from `project/maps/base/` (`2d/`, `2d_pixel/`, or `3d/`). Right-click the template's `scene.tscn` → `New Inherited Scene`. Save in `project/maps/<your_map>/scene.tscn`. Add a `World` node (Node2D or Node3D) as a child of the SubViewport and place game content under it. Create a `StdScreen` resource (`.tres`) pointing to the new scene with a transition, `pause_when_covered = true` (so the map subtree's `process_mode` flips to `DISABLED` when the pause menu is on top — pause is achieved via `process_mode`, NOT `get_tree().paused`), `dependency_screens` listing pause + settings, and `attachment_scenes` listing `project/menu/pause/pusher.tscn` by its `uid://`, which opens the pause menu on `ui_toggle_menu` (closing is handled by the pause screen's `close_actions`; the templates carry no pusher node). If the map needs custom logic, attach a script extending the template's `.gd`. To wire as the default game scene, assign the screen to `Main.game` in `main.tscn`. Gotchas: don't rename the root node of an inherited scene; don't chain more than one level of scene inheritance. If scene inheritance causes issues, copy the template and extend the script directly.
- **Adding a world-tracked HUD element** — Attach a `WorldTracker2D` (or `WorldTracker3D`) as a child of the screen-space `Control` that should follow a world entity (health bar, name plate, off-screen indicator). Set `map` to the `ProjectMap` and `target` to the tracked `Node2D`/`Node3D`. The tracker must live in a subtree later than the map's `SubViewport` (typically the `UI` layer) or it reads a stale camera transform — a startup assertion enforces this. Use `offset` to shift the widget, `clamped` with `viewport_margin` to pin it to the viewport edge while off-screen, and the `target_entered_view`/`target_exited_view`/`started`/`stopped` signals to react to visibility and lifecycle changes.
- **Adding a sound** — Place audio file in `project/`. Use WAV for short effects and OGG for longer loops/music. For multi-sample variation, use `AudioStreamRandomizer`. Create a `StdSoundEvent1D` resource (`.tres`) referencing the file and a bus from `system/audio/bus/`. Route game sounds to `sound_effects.tres` (via `game` bus) and UI sounds (focus, button clicks) to `ui.tres`. Play one-shot sounds via `Systems.audio().play(event)`. For music, use `Systems.audio().music().play(event)` which handles crossfade automatically. For concurrency limits, create a `StdSoundGroup` resource. For global mix states (e.g. covered-screen low-pass), use `StdMixSnapshot` with `StdSoundBusEffect` overrides.

## Save Data Runtime API

Game scenes access save data via `Main` statics in `project/main/main.gd`:

- `Main.get_active_save_data()` — read/write fields on the returned `ProjectSaveData`.
- `Main.save_game()` — awaitable; accumulates play time, stores, clears dirty.
- `Main.request_save()` — fire-and-forget; skips if in-flight or clean.
- `Main.load_game(slot)` / `Main.go_to_main_menu()` — game flow transitions.

Dirty tracking is automatic (`StdConfigItem` snapshots); use `mark_critical()` to force a save without field changes. Shutdown uses synchronous `flush_save_data()` as a last-resort path (`system/save/saves.gd`).

## Logging

`StdLogger` instances are named by hierarchical path (e.g. `system/save`, `std/config/writer/binary`). Levels are `DEBUG=0, INFO=1, WARN=2, ERROR=3`; the global default is `WARN`, so `debug`/`info` are opt-in (`debug` is compiled out of non-debug builds).

Levels are set declaratively by `StdLogProfile` resources, applied at startup in `platform/logging/logging.gd`: `profile_editor.tres` (editor) and `profile_default.tres` (exported builds). Each profile has a global `level` plus `level_overrides` (`{prefix: level}`); a logger's effective level is the longest matching prefix override, else the global. To trace a subsystem while developing, lower its prefix in `profile_editor.tres` rather than calling `StdLogger.set_level_override(...)` in code (`apply()` clears code-set overrides at startup).

## Pitfalls

- `Systems.*()` accessors only work after autoloads finish `_ready()`.
- Save schema changes without a version bump will silently drop fields from old saves.
- A `.tscn` or `.tres` written outside the editor has no `uid=` header, so it cannot be referenced by `uid://`. The engine never assigns one headless: run `godot --headless -s tools/check.gd -- --fix <paths>` to assign a path-derived uid, then `godot --import --headless` so it resolves.
- A file path kept in a string property — `StdScreen.scene_path` and its attachment and dependency lists, `StdConditionLoader.scene` — is not rewritten when its target moves, and nothing reads it until the screen is pushed or the condition allows. Reference the target by `uid://` instead; the checker's `path-ref` rule reports a reference that no longer resolves and a `res://` string that should be a uid, and `--fix` converts the latter.
- A `.tscn` whose `[ext_resource]` names a file that does not exist still loads *and still instantiates*: the engine prints a parse error and quietly drops the node that needed it, while `ResourceLoader.load()` returns a valid scene. Nothing fails, so a hand-written scene with a wrong path looks fine. The `path-ref` rule reports it; the engine falls back from the uid to the path, so only a header where neither resolves is broken.
- Assigning a property before `script =` in a `[node]`, `[resource]` or `[sub_resource]` block silently drops it: the file loads clean and the value never applies. The editor writes `script =` first; hand-written files must too.
- A `NodePath` export pointing at a node whose type does not match the declared type resolves to null at runtime rather than erroring.
- `SceneTree.quit(code)` collapses every non-zero code to process exit 1 under `-s`, printing the requested code to stderr. A tool cannot signal detail through its exit status.

## Commands

```bash
# Format check (line length 88)
gdformat -l 88 --check $(find . -path ./addons -prune -o -name '*.gd' -print)

# Lint
gdlint $(find . -path ./addons -prune -o -name '*.gd' -print)

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit

# Import resources and write `.uid` sidecars for scripts (scene and resource uid headers
# are not generated)
godot --import --headless

# Check project files for problems a normal load does not surface (compile errors,
# missing uid headers, properties dropped before `script =`, unresolvable NodePath
# exports). Exits non-zero when there is something to read.
godot --headless -s tools/check.gd                      # every rule, every file
godot --headless -s tools/check.gd -- path/to/file.tscn  # one file or directory
godot --headless -s tools/check.gd -- --fix path/to/file.tscn  # repair, then re-check
godot --headless -s tools/check.gd -- --list             # what each rule covers
```

CI has no `Steam` singleton, because GodotSteam ships no Linux binary, so a script
naming an extension API goes in `EXTENSION_SCRIPTS` in the checker; its dependents
are found from there. The checker says so when it happens, so this is a shortcut
past one CI round trip rather than something to remember.

The same checker runs on every `Edit`/`Write` via `.claude/hooks/gd_on_edit.sh`, so
most problems surface before they are committed, and as a full-project step in the
`test` job of `check-project.yaml`, which is the backstop for what the hook never saw —
an editor save, or a move that breaks a file nobody touched. Adding a check means adding a `Rule` subclass
in `tools/check.gd` and one entry in its registry; add one only after a pitfall has bitten
twice.

## Tooling placement

`tools/` holds scripts with a consumer other than Claude — CI, a hook, or a human. A
script only ever run by Claude, as one step of one workflow, ships beside its `SKILL.md`
in `.claude/skills/<name>/`, so the skill installs as a unit in a repository that does not
have this one's `tools/`. Hooks live in `.claude/hooks/`, next to the `settings.json` that
is their only caller.

## Code Style

Follows GDScript style guide. Key project-specific conventions:

- Lines are limited to 88 characters.
- Use the appropriate script template from `./script_templates` based on the base class.
- Overridden methods go in `PRIVATE METHODS (OVERRIDES)` or `ENGINE METHODS (OVERRIDES)` sections.
- Files begin with a `##` comment block:

  ```gdscript
  ##
  ## project/path/to/file.gd
  ##
  ## Brief description of the file's purpose.
  ##
  ```

- Class names: `Std` prefix for `addons/std/` only. Project classes have no prefix.
- Private members: underscore prefix (`_data`, `_mutex`).
- StringNames: use `&` prefix for literals (`&"category"`, `&"key"`).
- Use `##` for public API docs, `# NOTE:` for implementation details.
- Assertions for preconditions: `assert(category != "", "invalid argument: missing category")`
- Don't wrap comment lines prematurely; use the full 88-character width before breaking.
- Suppress lint warnings inline: `# gdlint:ignore=max-public-methods`

## Testing

Tests use GUT framework. Test files end in `_test.gd` and live alongside the code they test. Test cases are named `test_<subject>_<scenario>_<expectation>`. Use BDD-style comments:

```gdscript
func test_config_set_float_updates_value():
    # Given: A new, empty 'Config' instance.
    var config := Config.new()
    # When: A float value is set.
    config.set_float("category", "key", 1.0)
    # Then: The value is present.
    assert_eq(config.get_float("category", "key", 0.0), 1.0)
```

Schema migration tests compare against golden files in `tests/testdata/golden/saves/`. After a schema version bump, regenerate with `TEST_GENERATE_GOLDENS=1`. CI sets this to `0` to prevent accidental generation.

## Commits

Use Conventional Commits format (e.g., `feat(input): add gamepad rumble support`).
