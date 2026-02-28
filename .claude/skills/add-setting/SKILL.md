---
name: add-setting
description: Add a new user-configurable setting with property, observer, UI, and translations. Covers audio, video, interface, and controls categories.
user-invokable: true
argument-hint: "<category> <setting_name> <type>"
---

Add a user-configurable setting to the project. This involves creating a settings property resource, an observer to react to changes, UI in the settings menu, and translations. The `type` determines which property class and UI control to use.

## Setting types

| Type | Property class | UI control | Controller script |
|---|---|---|---|
| `bool` | `StdSettingsPropertyBool` | `checkbox.tscn` | `controller_toggle_button.gd` |
| `float_range` | `StdSettingsPropertyFloatRange` | `slider.tscn` | `controller_range.gd` |
| `option_string` | `StdSettingsPropertyString` | `option_button.tscn` | `controller_option_button_string.gd` |
| `option_int` | `StdSettingsPropertyInt` | `option_button.tscn` | `controller_option_button_int.gd` |

## Steps

1. **Read reference files** to understand the existing patterns:
   - `system/setting/audio/volume/master_property.tres` — property resource pattern
   - `system/setting/audio/volume/observer.gd` — observer pattern
   - `system/setting/settings.tscn` — observer wiring
   - The settings tab `.tscn` for the target category (e.g., `project/menu/settings/sound/sound.tscn`)

2. **Create the property resource** at `system/setting/<category>/<name>_property.tres`:

   ```
   [gd_resource type="Resource" script_class="<PropertyClass>" format=3 uid="uid://..."]

   [ext_resource type="Resource" uid="uid://..." path="res://system/setting/<scope>.tres" id="1_xxxxx"]
   [ext_resource type="Script" uid="uid://..." path="res://addons/std/setting/<property_script>.gd" id="2_xxxxx"]

   [resource]
   script = ExtResource("2_xxxxx")
   category = &"<category>"
   name = &"<setting_path>"
   default = <default_value>
   scope = ExtResource("1_xxxxx")
   ```

   For `float_range`, also include `minimum`, `maximum`, and `step` fields.

   Choose the correct scope resource:
   - `system/setting/user_settings_scope.tres` — per-user settings (most common: audio, controls, interface)
   - `system/setting/project_settings_scope.tres` — project-wide settings

3. **Create the observer** at `system/setting/<category>/<subcategory>/observer.gd`. Observers are grouped by subcategory (e.g., `audio/volume/observer.gd` handles all volume settings, `audio/mute/observer.gd` handles mute settings). If an observer already exists for the subcategory, add the new property to it instead of creating a new file:

   ```gdscript
   ##
   ## system/setting/<category>/<name>/observer.gd
   ##
   ## <ObserverName> is a `StdSettingsObserver` that applies <description>.
   ##

   extends StdSettingsObserver

   # -- CONFIGURATION ------------------------------------------------------------------- #

   ## property is the settings property to observe.
   @export var property: <PropertyClass> = null

   # -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


   func _get_settings_properties() -> Array[StdSettingsProperty]:
   	return [property]


   func _handle_value_change(
   	_property: StdSettingsProperty, value: <ValueType>
   ) -> void:
   	# Apply the setting change here.
   	pass
   ```

4. **Wire the observer into `system/setting/settings.tscn`** under `Observers/<Category>`:

   Add a new node entry for the observer under the appropriate category node. Reference the observer script and the property resource via `ext_resource`.

5. **Add UI to the settings tab** `.tscn` file at `project/menu/settings/<tab>/<tab>.tscn`:

   The UI structure follows this hierarchy:
   ```
   GroupNode (instance of group.tscn)       — label = "options_<category>_<group>"
     └─ SettingNode (instance of setting.tscn) — label = "options_<category>_<setting>"
          ├─ InputControl (slider/checkbox/option_button .tscn)
          └─ ControllerNode (StdSettingsController*)
                property = <property .tres>
                target = NodePath("../InputControl")  # for sliders
   ```

   Follow the exact pattern in the reference `.tscn` files. Each node needs a `unique_id`, `layout_mode = 2`, and proper resource references.

   For sliders (`controller_range.gd`), the controller needs:
   - `property` — the settings property resource
   - `target` — `NodePath("../HSlider")`

   For checkboxes (`controller_toggle_button.gd`), the controller needs:
   - `property` — the settings property resource

   For option buttons (`controller_option_button_string.gd`), the controller needs:
   - `property` — the settings property resource
   - `options_property` — a separate options list property resource

6. **Add translations** using the `add-translation` skill:
   - Group label: `options_<category>_<group>` (if creating a new group)
   - Setting label: `options_<category>_<setting_name>`

7. **Run `godot --import --headless`** and verify the setting appears correctly in the settings menu.

## Key reference files

- `system/setting/audio/volume/master_property.tres` — property resource (FloatRange)
- `system/setting/audio/mute/background_property.tres` — property resource (Bool)
- `system/setting/audio/volume/observer.gd` — observer pattern
- `system/setting/audio/device/observer.gd` — observer with multiple properties
- `system/setting/settings.tscn` — observer wiring under `Observers/<Category>`
- `system/setting/user_settings_scope.tres` — per-user scope
- `system/setting/project_settings_scope.tres` — project-wide scope
- `project/menu/settings/sound/sound.tscn` — full settings tab UI (slider, option button, checkbox examples)
- `project/menu/settings/controls/controls.tscn` — controls tab UI
- `project/menu/settings/setting.tscn` — setting container scene
- `project/menu/settings/group.tscn` — group container scene
- `project/ui/input/slider.tscn` — slider input control
- `project/ui/input/checkbox.tscn` — checkbox input control
- `project/ui/input/option_button.tscn` — option button input control
- `addons/std/setting/controller_range.gd` — range controller
- `addons/std/setting/controller_toggle_button.gd` — toggle controller
- `addons/std/setting/controller_option_button_string.gd` — string option controller
- `addons/std/setting/controller_option_button_int.gd` — int option controller