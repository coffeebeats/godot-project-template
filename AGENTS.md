# AGENTS.md

Godot 4+ project template for 2D games. Game logic goes in `project/`; reusable infrastructure lives in `system/` (autoloads) and `addons/std/` (standard library, a git submodule).

## Project Structure

Three autoloads bootstrap the app (in order): `Lifecycle`, `Platform`, `System`.

- **`project/`** — Game-specific code and assets.
  - **`core/`** — Game logic (empty by default; extend here).
  - **`main/`** — Main scene and app orchestration via `StdScreenManager`. Contains `menu/` and `splash/`.
  - **`maps/`** — Game scenes/levels. `example/` demonstrates save data integration.
  - **`save/`** — Save data schemas (`data/`) and save slot selection UI.
  - **`settings/`** — Settings menu with tabs for display, gameplay, sound, interface, and input rebinding.
  - **`input/`** — Input action definitions, including Steam Input actions.
  - **`locale/`** — i18n with 13 pre-configured languages (`.pot` template, `.po`/`.mo` per language).
  - **`ui/`** — Shared UI: screen transitions (fade, slide), input glyphs, modals, tooltips, theme, font.
- **`system/`** — Game-agnostic autoloaded subsystems (the `System` autoload). Accessed via `Systems.audio()`, `Systems.input()`, `Systems.saves()`.
  - **`audio/`** — Sound event player, audio bus layout.
  - **`input/`** — UI navigation, cursor management, gamepad/Steam Input support.
  - **`save/`** — Multi-slot save system (4 slots). Async save/load via background worker. Slot status tracking (OK/EMPTY/BROKEN).
  - **`setting/`** — Setting observers that sync `ProjectSettings` with UI (audio, video, interface).
- **`platform/`** — Platform abstraction (the `Platform` autoload). User profiles and storefront integration with Steam and fallback backends.
- **`addons/std/`** — Standard library (git submodule; do not edit directly). Classes use the `Std` prefix. Key modules: `config/`, `input/`, `save/`, `screen/`, `setting/`, `sound/`, and more.
- **`addons/gut/`** — GUT testing framework.
- **`addons/phantom_camera/`** — Camera plugin (submodule).
- **`script_templates/`** — GDScript file templates enforcing project structure (Node, Object, Resource, test, library).
- **`.github/workflows/`** — CI/CD: format/lint checks, tests, multi-platform export (macOS/Windows/Web), release-please automation.

Most changes involve both `.gd` scripts and `.tscn` scene files. Editing UI or wiring nodes typically requires touching both.

## Common Workflows

- **Adding a setting** — Create a `StdSettingsProperty*` resource in `system/setting/<category>/`. Add an observer (extends `StdSettingsObserver`) to react to value changes. Add UI in `project/settings/<tab>/` using `setting.tscn` and a controller node (e.g., `StdSettingsControllerRange`). Wire the observer into `system/setting/settings.tscn`.
- **Adding a save data field** — Create a class extending `StdConfigItem` in `project/save/data/`. Add an `@export` for it in `data.gd` and register it in `data.tres`. Access at runtime via `Main.get_active_save_data()`. If migrating existing saves, bump the version in `ProjectSaveData` and add a `StdConfigSchemaMigration`.
- **Adding a screen** — Create a `.tscn` scene and `.gd` script. Create a `StdScreen` resource (`.tres`) pointing to the scene with transition config. Export or preload the resource in `main.gd`. Navigate via `Main.screens().push()`, `.replace()`, `.pop()`, or `.reset()`.
- **Adding a translatable string** — Use the `add-translation` skill. Only edit `messages.pot` and `en_US.po` (key-based `msgid` values); other `.po` files use English text as `msgid` (swapped via `poswap`) and must not be edited directly. Reference keys in scenes via `text` property or in code via `tr("my_new_key")`.
- **Adding an input action** — Add the action to a `StdInputActionSet` resource in `project/input/actions/`. Add default binding in `project.godot` under `[input]`. Add translation with `msgctxt "actions_<SetName>"` to `messages.pot` and `en_US.po`. Scenes load action sets via `StdInputActionSetLoader` nodes.
- **Adding a sound** — Place audio file in `project/`. Create a `StdSoundEvent1D` resource (`.tres`) referencing the file and a bus from `system/audio/bus/`. Play via `Systems.audio().play(event)`. For concurrency limits, also create a `StdSoundGroup` resource.

## Pitfalls

- `Systems.*()` accessors only work after autoloads finish `_ready()`.
- Save schema changes without a version bump will silently drop fields from old saves.

## Commands

```bash
# Format check (line length 88)
gdformat -l 88 --check $(find . -path ./addons -prune -o -name '*.gd' -print)

# Lint
gdlint $(find . -path ./addons -prune -o -name '*.gd' -print)

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit

# Import resources and generate UID files 
godot --import --headless
```

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

## Commits

Use Conventional Commits format (e.g., `feat(input): add gamepad rumble support`).
