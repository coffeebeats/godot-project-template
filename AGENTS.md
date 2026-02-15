# AGENTS.md

Godot 4+ project template for 2D games. Game logic goes in `project/`; reusable infrastructure lives in `system/` (autoloads) and `addons/std/` (standard library, a git submodule).

## Project Structure

Three autoloads bootstrap the app (in order): `Lifecycle`, `Platform`, `System`.

- **`project/`** — Game-specific code and assets.
  - **`core/`** — Game logic (empty by default; extend here).
  - **`main/`** — Main scene and app orchestration. `lifecycle.gd` is an autoload that coordinates shutdown. `main.gd` manages screen flow (splash → menu → game) via `StdScreenManager`. Contains `menu/` (main menu) and `splash/` (splash screens).
  - **`maps/`** — Game scenes/levels. `example/` demonstrates save data integration.
  - **`save/`** — Save data schemas (`data/`) and save slot selection UI.
  - **`settings/`** — Settings menu with tabs for display, gameplay, sound, interface, and input rebinding.
  - **`input/`** — Input action definitions, including Steam Input actions.
  - **`locale/`** — i18n with 13 pre-configured languages (`.pot` template, `.po`/`.mo` per language).
  - **`ui/`** — Shared UI: screen transitions (fade, slide), input glyphs, modals, tooltips, theme, font.
- **`system/`** — Game-agnostic autoloaded subsystems (the `System` autoload). Accessed via `Systems.audio()`, `Systems.input()`, `Systems.saves()`.
  - **`audio/`** — Sound event player, audio bus layout.
  - **`input/`** — Focus-based UI navigation, cursor management, gamepad support, controller glyphs, Steam Input backend.
  - **`save/`** — Multi-slot save system (4 slots). Async save/load via background worker. Slot status tracking (OK/EMPTY/BROKEN).
  - **`setting/`** — Setting observers that sync `ProjectSettings` with UI (audio, video, interface).
- **`platform/`** — Platform abstraction (the `Platform` autoload). User profiles and storefront integration with Steam and fallback backends.
- **`addons/std/`** — Standard library (git submodule; do not edit directly). Classes use the `Std` prefix. Modules: `condition/`, `config/`, `editor/`, `event/`, `file/`, `fsm/`, `group/`, `input/`, `iter/`, `logging/`, `save/`, `scene/`, `screen/`, `setting/`, `sound/`, `statistic/`, `thread/`, `timer/`, `tween/`.
- **`addons/gut/`** — GUT testing framework.
- **`addons/phantom_camera/`** — Camera plugin (submodule).
- **`script_templates/`** — GDScript file templates enforcing project structure (Node, Object, Resource, test, library).
- **`.github/workflows/`** — CI/CD: format/lint checks, tests, multi-platform export (macOS/Windows/Web), release-please automation.

## Commands

```bash
# Format check (line length 88)
gdformat -l 88 --check $(find . -path ./addons -prune -o -name '*.gd' -print)

# Lint
gdlint $(find . -path ./addons -prune -o -name '*.gd' -print)

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit
```

## Code Style

Follows GDScript style guide. Key project-specific conventions:

### File Structure

- Lines are limited to 88 characters.
- Use the appropriate script template from `./script_templates` based on the base class.
- Overridden methods (whether private or engine) go in the `PRIVATE METHODS (OVERRIDES)` or `ENGINE METHODS (OVERRIDES)` section.
- Files begin with the following comment block:

  ```gdscript
  ##
  ## project/path/to/file.gd
  ##
  ## Brief description of the file's purpose.
  ##

  extends RefCounted

  # ...
  # Sections from script template go here
  ```

### Naming

- Class names: `Std` prefix for classes in `addons/std/` only (e.g., `StdConfigSchema`). Project classes do not use this prefix.
- Private members: underscore prefix (`_data`, `_mutex`)
- StringNames: use `&` prefix for literals (`&"category"`, `&"key"`)

### Comments

- Use `##` for public API documentation
- Use `# NOTE:` for important implementation details
- Assertions for preconditions: `assert(category != "", "invalid argument: missing category")`
- Don't wrap comment lines prematurely; use the full 88-character width before breaking. Exception: a URL may exceed the limit on the last line.
- Suppress expected lint warnings inline: `# gdlint:ignore=max-public-methods`

## Testing

Tests use GUT framework. Test files end in `_test.gd` and live alongside the code they test. Test cases are named like `test_<subject>_<scenario>_<expectation>` (e.g. `test_config_set_float_updates_value`).

### Test Structure

Use BDD-style Given/When/Then comments:

```gdscript
extends GutTest

func test_config_set_float_updates_value():
    # Given: A new, empty 'Config' instance.
    var config := Config.new()

    # When: A float value is set.
    config.set_float("category", "key", 1.0)

    # Then: The value is present.
    assert_true(config.has_float("category", "key"))
    assert_eq(config.get_float("category", "key", 0.0), 1.0)
```

## Commits

Use Conventional Commits format. Examples:

- `feat(input): add gamepad rumble support`
- `fix(config): prevent race condition in file sync`
- `chore(deps): bump actions/checkout`

Release automation via release-please triggers on merge to main.
