##
## project/settings/binding.gd
##
## Binding is a button node which allows a user to rebind an action.
##

@tool
extends "res://project/ui/glyph/glyph.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("res://addons/std/input/godot/binding.gd")
const Rebinder := preload("rebinder.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

## button is the `Button` node which, when pressed, will open the `Rebinder` panel.
@export var button: Button = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## has_user_override returns whether the input binding has a user-specified value (i.e.
## a non-default origin).
func has_user_override() -> bool:
	var active_device := _slot.get_active_device()
	if not active_device:
		return false

	return (
		Bindings
		. action_has_user_override(
			scope,
			action_set,
			action,
			active_device.device_category,
			binding_index,
		)
	)


## reset returns the input binding back to its default value.
func reset() -> void:
	var active_device := _slot.get_active_device()
	if not active_device:
		return

	(
		Bindings
		. reset_action(
			scope,
			action_set,
			action,
			active_device.device_category,
			binding_index,
		)
	)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	super._ready()

	if Engine.is_editor_hint():
		return

	assert(button is Button, "invalid state; missing node")
	Signals.connect_safe(button.pressed, _on_button_pressed)

	assert(scope is StdSettingsScope, "invalid config; missing scope")
	Signals.connect_safe(scope.config.changed, _on_bindings_changed)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_bindings_changed(category: StringName, key: StringName) -> void:
	var active_device := _slot.get_active_device()
	if not active_device:
		return

	if (
		category
		!= Bindings.get_action_set_category(action_set, active_device.device_category)
	):
		return

	if key != Bindings.get_action_key(action, binding_index):
		return

	_handle_update()


func _on_button_pressed() -> void:
	var rebinder: Rebinder = Rebinder.find_in_scene()
	rebinder.start(action_set, action, binding_index, player_id)
