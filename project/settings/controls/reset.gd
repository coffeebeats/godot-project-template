##
## project/settings/reset.gd
##
## Reset is a button node which resets the bindings for an action.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Bindings := preload("res://addons/std/input/godot/binding.gd")
const Binding := preload("binding.gd")
const Rebinder := preload("rebinder.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

@export_subgroup("Action set")

## action_set specifies an action set to reset *all* bindings for.
##
## NOTE: Only one of `action_set` and `bindings` may be specified.
@export var action_set: StdInputActionSet = null

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
##
## ## NOTE: This property is only used if `action_set` is specified.
@export var player_id: int = 1

@export_subgroup("Bindings ")

## bindings is a list of `Binding`-typed nodes which this `Reset` node will apply to.
##
## NOTE: Only one of `action_set` and `bindings` may be specified.
@export var bindings: Array[Binding] = []

# -- INITIALIZATION ------------------------------------------------------------------ #

var _category: StringName = &""
var _key: StringName = &""
var _slot: StdInputSlot = null

@onready var _button: Button = get_node("Prompt")
@onready var _icon: TextureRect = get_node("CenterContainer/TextureRect")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	_slot = StdInputSlot.for_player(player_id)
	assert(_slot is StdInputSlot, "invalid state; missing player slot")


func _ready() -> void:
	assert(scope is StdSettingsScope, "invalid config; missing scope")
	assert(
		(action_set is StdInputActionSet and not bindings) or not action_set,
		"invalid config; can only specify one of `action_set` and `bindings`"
	)

	Signals.connect_safe(_button.pressed, _on_pressed)
	Signals.connect_safe(scope.config.changed, _on_config_changed)
	Signals.connect_safe(_slot.device_activated, _on_device_activated)

	custom_minimum_size = custom_minimum_size.max(_icon.get_combined_minimum_size())

	# Defer this call so parent nodes can set properties on this one.
	call_deferred(&"_update_visibility")

	for binding in bindings:
		assert(binding is Binding, "invalid state; missing binding")
		assert(binding.glyph is StdInputGlyph, "invalid state; missing glyph")
		assert(binding.glyph.action, "invalid state; missing action")
		assert(
			binding.glyph.action_set is StdInputActionSet,
			"invalid state; missing action set",
		)

		assert(
			not _category or binding.glyph.action_set.name + "/" == _category,
			"invalid config; conflicting binding",
		)
		_category = binding.glyph.action_set.name + "/"

		assert(
			not _key or binding.glyph.action + "/" == _key,
			"invalid config; conflicting binding",
		)
		_key = binding.glyph.action + "/"


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_visibility() -> void:
	if action_set is StdInputActionSet:
		var active_device := _slot.get_active_device()
		if not active_device:
			return

		visible = (
			Bindings
			. category_has_user_override(
				scope,
				action_set,
				active_device.device_category,
			)
		)

		return

	for binding in bindings:
		if binding.has_user_override():
			visible = true
			return

	visible = false


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_config_changed(category: StringName, key: StringName) -> void:
	if not category.begins_with(_category) or not key.begins_with(_key):
		return

	if not visible:
		_update_visibility()


func _on_device_activated(_device: StdInputDevice) -> void:
	_update_visibility.call_deferred()


func _on_pressed() -> void:
	if action_set is StdInputActionSet:
		var active_device := _slot.get_active_device()
		if not active_device:
			return

		Bindings.reset_all_actions(scope, action_set, active_device.device_category)
	else:
		for binding in bindings:
			binding.reset()

	var next := find_valid_focus_neighbor(SIDE_RIGHT)
	if not next:
		next = find_valid_focus_neighbor(SIDE_BOTTOM)

	if not next:
		return

	next.grab_focus()
	_update_visibility()
