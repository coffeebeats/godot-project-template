# AGENTS.md

Godot 4+ project template for 2D games. Game logic goes in `project/`; reusable infrastructure lives in `addons/kit/` (game infrastructure) and `addons/std/` (standard library), both git submodules.

## Project Structure

Three autoloads bootstrap the app (in order): `Lifecycle`, `Platform`, `System`.

- **`project/`** — Game-specific code and assets.
  - **`core/`** — Game logic (empty by default; extend here).
  - **`main/`** — Main scene and app orchestration via `StdScreenManager`. Contains `menu/` and `splash/`, and the `Platform` and `System` autoload scenes (`platform.tscn`, `system.tscn`), which place kit's bricks and set the game's values on them.
  - **`audio/`** — The audio bus layout and the `master`, `music`, `sound_effects` and `voice` bus handles.
  - **`menu/`** — The game's own settings tab (`settings/gameplay/`), which `system.tscn` registers in `menu_tabs` on the `Settings` instance.
  - **`save/`** — Save data schemas (save slot data, summaries).
  - **`input/`** — The game's action sets, and its Steam Input manifest (`steam_in_game_actions.tres`, which writes `game_actions_480.vdf`).
  - **`locale/`** — The game's own strings, in 13 languages (`.pot` template, `.po`/`.mo` per language). `locale/translations` lists these before kit's catalogue, so a key defined here overrides kit's.
  - **`ui/`** — The game's theme (`theme.tres`, set as `[gui] theme/custom`) and font (`font.tres`, `font/`).
- **`addons/kit/`** — Game infrastructure (git submodule; do not edit directly). Classes use the `Kit` prefix. Every value the game owns is set on a kit instance, never by editing kit: in `project/main/system.tscn` and `platform.tscn`, or on the root of a map inheriting a kit template. Kit's menus read theirs from `system.tscn` too: `Input.action_sets` for the controls tab, `Settings.menu_tabs` for the game's settings tabs and `Saves.slot_count` for the save menu. Two values are passed at runtime instead: `main.gd` hands the screen manager to `KitSystems.audio()` and `go_to_main_menu` to `KitPauseMenu.return_to_main_menu`. A screen manager also reaches a `KitAlertDialog`, through its `open()`. `addons/kit/README.md` lists every one.
  - **`system/`** — Subsystems the `System` autoload places. Accessed via `KitSystems.audio()`, `KitSystems.input()`, `KitSystems.saves()`, `KitSystems.settings()`.
    - **`audio/`** — Sound event player, music player, mix snapshots, the `game` and `ui` bus handles.
    - **`input/`** — UI navigation, cursor management, gamepad/Steam Input support. `actions/` holds the menu action sets and the splash screen's.
    - **`save/`** — Multi-slot save system (`slot_count` slots; the template sets 4). Async save/load via background worker. Slot status tracking (OK/EMPTY/BROKEN).
    - **`setting/`** — Setting observers that sync `ProjectSettings` with UI (audio, video, interface).
    - **`debug/`** — The bridge `tools/bridge.sh` drives.
    - **`lifecycle.gd`** — The `Lifecycle` autoload's script.
  - **`platform/`** — Platform abstraction (the `Platform` autoload places it). User profiles, storefront integration with Steam and fallback backends, and logging.
  - **`ui/`** — Shared UI: screen transitions (fade, slide), input glyphs, modals, tooltips, world-space trackers. `hud/` is the HUD layer, its anchor and group, and the stock elements; `feel/` is camera shake, hit-stop and flash; `splash/` is the splash screen script and the Godot splash.
  - **`menu/`** — Ready-to-use screens: settings (`settings/`, with its tabs and the rebinder), save slot selection (`save/`) and pause (`pause/`). Each ships its `StdScreen`, and settings and pause a pusher, so the game references them rather than copying them.
  - **`map/`** — Style-specific map templates: `2d/`, `2d_pixel/` and `3d/`. Each is a standalone scene and script with the full apparatus (SubViewport, InputActionSetLoader, feel and HUD layers). `2d_pixel/` extends `2d/` at the script level so it inherits the 2D world-to-screen bridge; the `.tscn` files remain standalone siblings (don't chain scene inheritance). The 3D template includes settings observers for render quality.
  - **`locale/`** — `Locales` (`locales.gd`) and kit's own catalogue, whose keys take a `kit_` prefix.
- **`addons/std/`** — Standard library (git submodule; do not edit directly). Classes use the `Std` prefix. Key modules: `config/`, `input/`, `save/`, `screen/`, `setting/`, `sound/`, and more.
- **`addons/gut/`** — GUT testing framework.
- **`script_templates/`** — GDScript file templates enforcing project structure (Node, Object, Resource, test, library).
- **`.github/workflows/`** — CI/CD: format/lint checks, tests, multi-platform export (macOS/Windows/Web), release-please automation.

Most changes involve both `.gd` scripts and `.tscn` scene files. Editing UI or wiring nodes typically requires touching both.

## Common Workflows

Seven of these have a skill that owns the details — invoke it rather than working from memory or from a summary here. The four without one are written out below, and move into skills if those skills are ever written.

- **Adding a setting** — the `add-setting` skill. Property resource, observer, settings-tab UI, translations.
- **Adding a save data field** — the `add-save-field` skill. Config item, schema wiring, version bump and migration.
- **Adding a translatable string** — the `add-translation` skill. Only `messages.pot` and `en_US.po` are ever hand-edited.
- **Adding an input action** — the `add-input-action` skill. Action set, default bindings, translations, and the binding-collision check.
- **Adding a sound** — the `add-sound` skill. Event resource, bus routing, concurrency groups, mix snapshots.
- **Adding a screen** — Create a `.tscn` scene and `.gd` script. Create a `StdScreen` resource (`.tres`) pointing to the scene with transition config. Export or preload the resource in `main.gd`. Navigate via `Main.screens().push()`, `.replace()`, `.pop()`, or `.reset()`. Keys that close a screen go in the `StdScreen`'s `close_actions`, beside `overlay_click_to_close`; a closer needs no pusher and no placement. This works with `pause_when_covered` (it disables the covered scene, not the overlay) but not under `get_tree().paused`, which the template never sets. To open a screen with an input action, list a `StdScreenPusher` scene in the `StdScreen`'s `attachment_scenes` instead of placing it in the scene. Write `scene_path`, `attachment_scenes` and `dependency_scenes` as `uid://` strings (the target's header uid), since Godot's move/rename fixup rewrites `ext_resource` references but never a path held in a string; the checker's `path-ref` rule enforces this and `--fix` converts them. Attachments mount into the screen's overlay, so `pause_when_covered` does not touch them and the scene stays runnable on its own. An opener goes on the screen it opens **from**, since it must outlive its target (`addons/kit/menu/settings/pusher.tscn` on `project/main/menu/screen.tres`). Both mechanisms only fire if the topmost screen's action set binds the action, since loading an action set rebinds the whole `InputMap`. Pick an action bound by the screen that should respond and unbound by the screens that should stay quiet.
- **Adding a map** — Pick a style template from `addons/kit/map/` (`2d/`, `2d_pixel/`, or `3d/`). Right-click the template's `scene.tscn` → `New Inherited Scene`. Save in `project/maps/<your_map>/scene.tscn`. On the root, set `action_set` to `project/input/actions/gameplay.tres` and `action_set_layers` to `gameplay_options.tres`; a map without an action set reports an error when it enters the tree. Add a `World` node (Node2D or Node3D) as a child of the SubViewport and place game content under it. Create a `StdScreen` resource (`.tres`) pointing to the new scene with a transition, `pause_when_covered = true` (so the map subtree's `process_mode` flips to `DISABLED` when the pause menu is on top — pause is achieved via `process_mode`, NOT `get_tree().paused`), `dependency_screens` listing pause + settings, and `attachment_scenes` listing `addons/kit/menu/pause/pusher.tscn` by its `uid://`, which opens the pause menu on `ui_toggle_menu` (closing is handled by the pause screen's `close_actions`; the templates carry no pusher node). If the map needs custom logic, attach a script extending the template's `.gd`. To wire as the default game scene, assign the screen to `Main.game` in `main.tscn`. Gotchas: don't rename the root node of an inherited scene; don't chain more than one level of scene inheritance. If scene inheritance causes issues, copy the template and extend the script directly.
- **Giving an entity a HUD** — the `add-entity-hud` skill. Group scene, anchor, off-screen behavior, and the two ordering traps that fail silently.
- **Adding a HUD element** — the `add-hud-element` skill. A new element kind: its own API, style resource and theme variation. No shared base class to change.
- **Adding feel** — `map.feel.impulse(config, direction)` shakes and kicks the camera, `map.feel.hit_stop(config)` freezes the world, `map.feel.flash(config)` washes the screen, and a `KitFeelHitFlash2D`/`3D` child of a sprite or mesh flashes just that one. Each takes a `Resource` (`KitFeelImpulse`, `KitFeelHitStop`, `KitFeelFlash`) with presets in `addons/kit/ui/feel/`, so tuning how a hit feels is a `.tres` edit. **The feel layer owns the camera's offset**; a camera controller must follow through `position`/`global_transform` and leave the offset alone. `hit_stop` is global to the game, not to the map, so only the active map calls it. A world node reaches the layer with `KitMap.for_node(self).feel`.
- **Adding a world-tracked widget outside a HUD group** — Attach a `KitWorldTracker2D` (or `KitWorldTracker3D`) as a child of the screen-space `Control` that should follow a world entity. Set `map` to the `KitMap` and `target` to the tracked `Node2D`/`Node3D`. The tracker must live in a subtree later than the map's `SubViewport` (typically the `UI` layer) or it reads a stale camera transform — a startup assertion enforces this. Use `offset` to shift the widget, `clamped` with `viewport_margin` to pin it to the viewport edge while off-screen, and the `target_entered_view`/`target_exited_view`/`started`/`stopped` signals to react to visibility and lifecycle changes. Prefer a HUD group; this is the escape hatch when one entity needs a widget with its own tracking policy.

## Save Data Runtime API

Game scenes access save data via `Main` statics in `project/main/main.gd`:

- `Main.get_active_save_data()` — read/write fields on the returned `ProjectSaveData`.
- `Main.save_game()` — awaitable; accumulates play time, stores, clears dirty.
- `Main.request_save()` — fire-and-forget; skips if in-flight or clean.
- `Main.load_game(slot)` / `Main.go_to_main_menu()` — game flow transitions.

Dirty tracking is automatic (`StdConfigItem` snapshots); use `mark_critical()` to force a save without field changes. Shutdown uses synchronous `flush_save_data()` as a last-resort path (`addons/kit/system/save/saves.gd`).

## Logging

`StdLogger` instances are named by hierarchical path (e.g. `system/save`, `std/config/writer/binary`). Levels are `DEBUG=0, INFO=1, WARN=2, ERROR=3`; the global default is `WARN`, so `debug`/`info` are opt-in (`debug` is compiled out of non-debug builds).

Levels are set declaratively by `StdLogProfile` resources, applied at startup by kit's `Logging` brick: `profile_editor` (editor) and `profile_default` (exported builds), which default to kit's profiles in `addons/kit/platform/logging/`. Each profile has a global `level` plus `level_overrides` (`{prefix: level}`); a logger's effective level is the longest matching prefix override, else the global. To trace a subsystem while developing, copy kit's `profile_editor.tres` under `project/`, lower its prefix, and set it as `profile_editor` on the `Logging` instance in `project/main/platform.tscn`, rather than calling `StdLogger.set_level_override(...)` in code (`apply()` clears code-set overrides at startup).

## Pitfalls

Every entry below fails silently: no error, no crash, no failing test, and the wrong behavior surfaces somewhere else. Only the ones nothing else can catch are listed here — see [Tooling placement](#tooling-placement) for where the rest live.

- `KitSystems.*()` accessors only work after autoloads finish `_ready()`.
- Save schema changes without a version bump will silently drop fields from old saves.
- Never filter `*.aseprite` in an export preset. A filter matching a source also drops the baked `.res`/`.sample` beside it, and nothing says so until an exported build looks for the asset at runtime.
- Fire an input action from code with `StdInputEvent.trigger_action`, or GUT's `InputSender` in tests. `Input.action_press` sets only the polled state `Input.is_action_pressed` reads; it raises no event, so `_input`, `_unhandled_input`, and everything built on them — screen pushers, overlay close actions — never see it. Both build an `InputEventAction`, which matches by name and never consults the `InputMap`, so a handler fires whether or not the action is bound to anything. Checking a binding takes the real `InputEventKey` or `InputEventJoypadButton`.

The `.tscn` and `.tres` file-format pitfalls are rules in the `godot` agent plugin's project checker rather than entries here: a missing `uid=` header, a file path held in a string property, an `[ext_resource]` naming a file that does not exist, a property assigned ahead of `script =`, and a `NodePath` export whose type does not match. The plugin's edit hook runs the checker on every `Edit` and `Write`, and `--fix` repairs the first two — follow it with `godot --import --headless` or the new uids do not resolve. Run `godot-check --list` for what each rule covers. A file changed any other way, such as by a move, stays unchecked until `godot-check` or CI runs.

## Commands

```bash
# Format check (settings in `.gdformatrc`)
uv run gdformat --check .

# Lint (settings in `.gdlintrc`)
uv run gdlint .

# Lint the Python tooling and check `uv.lock` against `pyproject.toml`
uv run ruff check .
uv lock --check

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit

# Import resources and write `.uid` sidecars for scripts (scene and resource uid headers
# are not generated)
godot --import --headless

# Boot the app headless. `--quit` alone tears down while threaded loads are still in
# flight and prints 5-7 scene parse errors that are not real faults.
godot --headless --quit-after 30

# Check project files for problems a normal load does not surface (compile errors,
# missing uid headers, properties dropped before `script =`, unresolvable NodePath
# exports). Exits non-zero when there is something to read. From the `godot` agent
# plugin, so on Claude's PATH only.
godot-check                          # every rule, every file
godot-check path/to/file.tscn        # one file or directory
godot-check --fix path/to/file.tscn  # repair, then re-check
godot-check --list                   # what each rule covers

# Bake `.aseprite` sources to a PNG sheet plus a tag manifest for the stock importer.
tools/aseprite.sh --out assets/baked assets/src
```

To see a change working in the real app rather than in a test, use the `run-game`
skill, which drives a live game through `tools/bridge.sh`.

CI has no `Steam` singleton, because GodotSteam ships no Linux binary. The checker
skips the scripts naming its API there on its own.

The same checker runs on every `Edit`/`Write` through the plugin's hook, so most
problems surface before they are committed, and over the whole project in the `test`
job of `check-project.yaml`, which is the backstop for what the hook never saw — an
editor save, or a move that breaks a file nobody touched. Checker rules live in
`godot-infra`; add one only after a pitfall has bitten twice.

## Tooling placement

`tools/` holds scripts with a consumer other than Claude — CI, a hook, or a human. A
script only ever run by Claude, as one step of one workflow, ships beside its `SKILL.md`
in `.claude/skills/<name>/`, so the skill installs as a unit in a repository that does not
have this one's `tools/`. A skill may still front a `tools/` script it did not ship — `run-game`
does — since the test is who else runs it, not who documents it. Tooling that is the same in every
Godot repository, such as the edit hook, the project checker and the `godot-api` skill, lives
in the `godot` agent plugin in `godot-infra`, enabled in `.claude/settings.json`.

A pitfall goes in the first tier below that can hold it. This file is the last resort,
because it is read in full by every session before the task is known, so a line here is
paid for by every session that never goes near it:

1. **Make it unrepresentable** — an assert, or an API that only does the right thing.
   `KitWorldTracker`'s startup assertion and `StdInputEvent.trigger_action` both exist for
   this reason.
2. **Catch it** — a rule in the project checker in `godot-infra`. It fires at the moment
   of the mistake with the file in hand, and costs no context until then.
3. **Put it in the task** — the skill whose workflow provokes it, loaded on demand by the
   session doing that work.
4. **Write it here** — only what none of the above can reach.

So before adding a pitfall, ask whether a rule could catch it or a skill could own it. If
either can, write that instead. Add a checker rule only after a pitfall has bitten twice.

## Code Style

Follows GDScript style guide. Key project-specific conventions:

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

- Class names: `Std` prefix for `addons/std/` and `Kit` for `addons/kit/`. Project classes have no prefix.
- Private members: underscore prefix (`_data`, `_mutex`).
- StringNames: use `&` prefix for literals (`&"category"`, `&"key"`).
- Use `##` for public API docs, `# NOTE:` for implementation details.
- Assertions for preconditions: `assert(category != "", "invalid argument: missing category")`
- Don't wrap comment lines prematurely; use the full line width before breaking.
- Suppress lint warnings inline: `# gdlint:ignore=max-public-methods`; a directive
  covers its own line and the one after it. `gdformat` leaves some long lines alone and
  collapses manual wrapping back, so a line it accepts can still fail `max-line-length`
  — suppress those rather than reformatting.

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
