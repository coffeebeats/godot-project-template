##
## Insert class description here.
##

@tool
extends VBoxContainer

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var label: String = "":
	set(value):
		label = value
		update_configuration_warnings()

		if _label != null:
			_label.text = value

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _label: Label = $Label

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_label.text = label


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if label == "":
		out.append("Invalid config; missing label")

	return out

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
