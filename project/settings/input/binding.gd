##
## project/settings/input/binding.gd
##
## SettingsBinding is an input node which facilitates rebinding an action.

extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

signal started(action: StringName)
signal completed(action: StringName, success: bool)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Binding := preload("res://addons/std/input/binding.gd")
const Signals := preload("res://addons/std/event/signal.gd")


# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var scope: StdSettingsScope = null

@export_group("Display nodes")

@export var label: NodePath = "Label"
@export var glyph: NodePath = "Glyph"


# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_listening: bool = false

@onready var _label: StdInputGlyph = get_node(label)
@onready var _glyph: StdInputGlyph = get_node(glyph)

# -- PUBLIC METHODS ------------------------------------------------------------------ #

func start() -> void:
	set_process_input(true)

	_label.visible = true
	_glyph.visible = false

	_is_listening = true

func cancel() -> void:
	completed.emit(_glyph.action, false)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

#func _draw() -> void:
#	pass

#func _enter_tree() -> void:
#	pass

#func _exit_tree() -> void:
#	pass

func _input(event: InputEvent) -> void:
	if not _glyph.action_set.is_matching_event_origin(_glyph.action, event):
		return

#func _notification(what) -> void:
#	pass

#func _physics_process(delta: float) -> void:
#	pass

#func _process(delta: float) -> void:
#	pass

func _ready() -> void:
	Signals.connect_safe(completed, _on_completed)

#func _unhandled_input(event: InputEvent) -> void:
#	pass

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_completed(action: StringName, success: bool) -> void:
	_is_listening = false

	_label.visible = false
	_glyph.visible = true

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
