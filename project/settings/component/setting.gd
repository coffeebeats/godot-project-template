##
## project/settings/component/setting.gd
##
## Setting is a single entry in the settings menu. This consists of a `Label` and an
## input `Control` for updating the setting value.
##

@tool
extends HBoxContainer

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var label: String = "":
	set(value):
		label = value
		update_configuration_warnings()

		if _label != null:
			_label.text = value

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _label: Label = $Label

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_label.text = label


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if label == "":
		warnings.append("Invalid config; missing label")

	return warnings
