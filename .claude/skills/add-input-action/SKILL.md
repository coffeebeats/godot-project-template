---
name: add-input-action
description: Add a new input action with default bindings, action set registration, and translations. Creates new action sets if needed.
user-invokable: true
argument-hint: "<action_set> <action_name> [type]"
---

Add an input action to the project. The action is registered in an action set, given default key/gamepad bindings in `project.godot`, and translated for display in the controls settings tab. The `type` defaults to `digital` but can be `analog_1d` or `analog_2d`.

## Steps

1. **Read reference files** to understand existing actions:
   - `project/input/actions/` — all existing action set `.tres` files
   - `project.godot` — `[input]` section for existing default bindings
   - `project/locale/messages.pot` — existing `msgctxt "actions_*"` entries
   - `project/menu/settings/controls/controls.tscn` — controls tab wiring

2. **Check if the action set exists** in `project/input/actions/`. Action set files are `StdInputActionSet` resources (`.tres`). If the specified action set does not exist, create it (see step 3). If it does exist, skip to step 4.

3. **Create a new action set** (only if it doesn't exist):

   a. Create the action set resource at `project/input/actions/<set_name>.tres`. Copy the `ext_resource` UID for `action_set.gd` from an existing action set file (e.g., `gameplay.tres`) rather than hardcoding it — the UID may change when the `std` submodule is updated:

   ```
   [gd_resource type="Resource" script_class="StdInputActionSet" format=3 uid="uid://..."]

   [ext_resource type="Script" uid="uid://..." path="res://addons/std/input/action_set.gd" id="1_xxxxx"]

   [resource]
   script = ExtResource("1_xxxxx")
   name = &"<SetName>"
   ```

   The `name` should be PascalCase (e.g., `&"Gameplay"`, `&"Combat"`).

   b. Run `godot --import --headless` to generate the UID.

   c. Wire the action set into `project/menu/settings/controls/controls.tscn` by adding a new node that instances `action_set.tscn` with the `action_set` and `scope` properties:

   ```
   [node name="<SetName>" parent="." instance=ExtResource("id_for_action_set_tscn")]
   layout_mode = 2
   action_set = ExtResource("id_for_new_action_set_tres")
   scope = ExtResource("id_for_bindings_scope")
   ```

   Reference `project/menu/settings/controls/action_set.tscn` for the instance and `system/input/unknown/bindings_scope.tres` for the scope. Add the corresponding `ext_resource` entries at the top of the file.

   d. Add a translation for the action set name using the `add-translation` skill. Action set display names use a **different convention** than action names — they have **no `msgctxt`** and use a prefixed `msgid`:
   - `msgid "options_controls_<SetName>"` — e.g., `options_controls_Gameplay`
   - `msgstr "<Display Name>"` — the English display name shown as the group header

   This is because `locales.gd:tr_action_set()` translates via `tr("options_controls_" + action_set)`.

4. **Add the action to the action set** `.tres` file. Actions are `StringName` values in one of three arrays:

   - `actions_digital` — boolean on/off actions (buttons, keys)
   - `actions_analog_1d` — single-axis analog actions (triggers)
   - `actions_analog_2d` — dual-axis analog actions (sticks)

   Add the action's `StringName` (e.g., `&"jump"`) to the correct array. If the array doesn't exist in the `.tres` file yet, add it under the `[resource]` section.

5. **Add default bindings in `project.godot`** under the `[input]` section. Each action needs a block like:

   ```
   <action_name>={
   "deadzone": 0.5,
   "events": [Object(InputEventKey,...), Object(InputEventJoypadButton,...)]
   }
   ```

   Common binding objects:
   - **Keyboard key**: `Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":<KEY_CODE>,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)`
   - **Gamepad button**: `Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":<BUTTON_INDEX>,"pressure":0.0,"pressed":false,"script":null)`
   - **Gamepad axis**: `Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":<AXIS>,"axis_value":<1.0 or -1.0>,"script":null)`

   Common key codes: Space=32, Enter=4194309, Escape=4194305, W=87, A=65, S=83, D=68, E=69, Q=81, Shift=4194325, Ctrl=4194326.
   Common button indices: A/Cross=0, B/Circle=1, X/Square=2, Y/Triangle=3, LB=9, RB=10, LT=trigger axis, RT=trigger axis.

   Ask the user what default bindings they want if not specified.

6. **Add translations** using the `add-translation` skill:
   - Use `msgctxt "actions_<SetName>"` for the action's display name
   - `msgid "<action_name>"` — the key matches the action's StringName
   - `msgstr "<Display Name>"` — the English display name shown in controls settings

7. **Run `godot --import --headless`** to validate everything compiles. The action should appear automatically in the controls settings tab under its action set.

## Key reference files

- `project/input/actions/gameplay.tres` — action set resource pattern
- `project/input/actions/gameplay_options.tres` — action set layer pattern (StdInputActionSetLayer)
- `project/menu/settings/controls/controls.tscn` — controls tab wiring (instances `action_set.tscn` per set)
- `project/menu/settings/controls/action_set.tscn` — action set UI instance
- `system/input/unknown/bindings_scope.tres` — bindings scope used in controls tab
- `project.godot` — `[input]` section for default bindings
- `project/locale/messages.pot` — `msgctxt "actions_*"` translation entries
- `project/locale/en_US.po` — corresponding English translations
- `project/locale/locales.gd` — `tr_action()` and `tr_action_set()` resolution
- `addons/std/input/action_set.gd` — `StdInputActionSet` class