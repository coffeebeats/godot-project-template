##
## project/settings/input/option_button_string.gd
##
## `OptionButtonString` is an `OptionButton` node which is driven by a
## `StdSettingsPropertyString` and `StdSettingsPropertyStringList`.
##

@tool
extends "option_button.gd"

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a `StdSettingsPropertyString` used to drive the control's value.
@export var property: StdSettingsPropertyString = null:
	set(value):
		property = value

		$StdSettingsControllerOptionButtonString.property = value
		update_configuration_warnings()

## options_property is a `StdSettingsPropertyStringList` used to drive the control's
## list of allowed values.
@export var options_property: StdSettingsPropertyStringList = null:
	set(value):
		options_property = value
		$StdSettingsControllerOptionButtonString.options_property = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	return $StdSettingsControllerOptionButtonString._get_configuration_warnings()


func _ready() -> void:
	$StdSettingsControllerOptionButtonString.property = property
	$StdSettingsControllerOptionButtonString.options_property = options_property
