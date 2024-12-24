##
## project/ui/input/binding.gd
##
## InputBinding is a button node which allows a user to rebind an action.
##

@tool
extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Rebinder := preload("res://project/settings/rebinder.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Binding")

@export_subgroup("Action")

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null

## action is the name of the input action which the glyph icon will correspond to.
@export var action := &""

@export_subgroup("Player")

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1

# -- INITIALIZATION ------------------------------------------------------------------ #

var _custom_minimum_size := Vector2.ZERO

@onready var _button: Button = get_node("Prompt")
@onready var _glyph: StdInputGlyph = get_node("CenterContainer/Glyph")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	Signals.disconnect_safe(_button.pressed, _on_pressed)
	Signals.disconnect_safe(_glyph.glyph_updated, _on_glyph_updated)


func _get_configuration_warnings() -> PackedStringArray:
	return _glyph._get_configuration_warnings()


func _ready():
	assert(_glyph is StdInputGlyph, "invalid state; missing node")
	_glyph.action_set = action_set
	_glyph.action = action
	_glyph.player_id = player_id

	_custom_minimum_size = custom_minimum_size

	Signals.connect_safe(_button.pressed, _on_pressed)
	Signals.connect_safe(_glyph.glyph_updated, _on_glyph_updated)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_glyph_updated(_has_contents: bool) -> void:
	custom_minimum_size = _custom_minimum_size.max(_glyph.get_combined_minimum_size())


func _on_pressed() -> void:
	var binding_prompt: Rebinder = Rebinder.find_in_scene()
	binding_prompt.start(action_set, action, player_id)