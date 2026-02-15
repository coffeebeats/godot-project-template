# AGENTS.md

Godot 4+ project template for 2D games with save systems, settings, input handling, screen management, localization, Steam integration, and CI/CD. Game logic goes in `project/`; reusable infrastructure lives in `system/` (autoloads) and `addons/std/` (standard library, a git submodule). Three autoloads bootstrap the app in order: `Lifecycle`, `Platform`, `System`.

## Project Structure

- **`project/`** — Game-specific code and assets.
  - **`core/`** — Game logic (empty by default; extend here).
  - **`main/`** — Main scene and app orchestration. `lifecycle.gd` is an autoload that coordinates shutdown. `main.gd` manages screen flow (splash → menu → game) via `StdScreenManager`.
  - **`main/menu/`** — Main menu (Continue/Play/Options/Quit) with background music.
  - **`maps/`** — Game scenes/levels. `example/` demonstrates save data integration.
  - **`save/`** — Save data schemas. `ProjectSaveData` extends `StdSaveData`; `ProjectSaveSummary` extends `StdSaveSummary`. UI for save slot selection.
  - **`settings/`** — Settings menu with tabs for display, gameplay, sound, interface, and input rebinding.
  - **`input/`** — Input action definitions, including Steam Input actions.
  - **`locale/`** — i18n with 13 pre-configured languages (`.pot` template, `.po`/`.mo` per language).
  - **`ui/`** — Shared UI: screen transitions (fade, slide), input glyphs, modals, tooltips, theme, font.
- **`system/`** — Game-agnostic autoloaded subsystems (the `System` autoload). Accessed via static methods on `Systems`: `Systems.audio()`, `Systems.input()`, `Systems.saves()`.
  - **`audio/`** — Sound event player, audio bus layout.
  - **`input/`** — Focus-based UI navigation, cursor management, gamepad support, controller glyphs, Steam Input backend.
  - **`save/`** — Multi-slot save system (4 slots). Async save/load via background worker. Slot status tracking (OK/EMPTY/BROKEN).
  - **`setting/`** — Setting observers that sync `ProjectSettings` with UI (audio, video, interface).
- **`platform/`** — Platform abstraction (the `Platform` autoload). User profiles and storefront integration with Steam and fallback backends.
- **`addons/std/`** — Standard library (git submodule). Self-contained modules under subdirectories (e.g., `config/`, `fsm/`, `screen/`, `sound/`). Classes use the `Std` prefix. Explore subdirectories for available utilities.
- **`addons/gut/`** — GUT testing framework.
- **`addons/phantom_camera/`** — Camera plugin (submodule).
- **`script_templates/`** — GDScript file templates enforcing project structure (Node, Object, Resource, test, static library).
- **`custom.py`** — Engine build config optimized for 2D (disables 3D, networking, VR/XR).
- **`.github/workflows/`** — CI/CD: format/lint checks, tests, multi-platform export (macOS/Windows/Web), release-please automation, itch.io publishing.
- **`.patches/`** — Custom Godot engine patches applied during export template compilation.

## Commands

```bash
# Format check (line length 88)
gdformat -l 88 --check (^addons*)/**/*.gd

# Lint
gdlint (^addons*)/**/*.gd

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit
```

## Code Style

Follows GDScript style guide. Key project-specific conventions:

### File Structure

- Lines are limited to 88 characters.
- Use the appropriate script template from `./script_templates` based on the base class.
- Overridden methods (whether private or engine) go in the `<PRIVATE|ENGINE> METHODS (OVERRIDES)` section.
- Files begin with the following comment block:

  ```gdscript
  ##
  ## std/path/to/file.gd
  ##
  ## Brief description of the file's purpose.
  ##

  extends RefCounted

  # ...
  # Sections from script template go here
  ```

### Naming

- Class names: `Std` prefix for exported classes (e.g., `StdConfigSchema`)
- Private members: underscore prefix (`_data`, `_mutex`)
- StringNames: use `&` prefix for literals (`&"category"`, `&"key"`)

### Comments

- Use `##` for public API documentation
- Use `# NOTE:` for important implementation details
- Assertions for preconditions: `assert(category != "", "invalid argument: missing category")`
- Each comment line should use the full line length when possible, but not exceed it; the exception is a URL on the last line.

### Linting

When necessary, use inline directives to suppress expected warnings:

```gdscript
# gdlint:ignore=max-public-methods
return OK  # gdlint:ignore=max-returns
```

## Testing

Tests use GUT framework. Test files end in `_test.gd`. Test cases are named like `test_<subject>_<scenario>_<expectation>` (e.g. `test_config_set_float_updates_value`).

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
