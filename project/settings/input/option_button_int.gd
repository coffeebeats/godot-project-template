##
## project/settings/input/option_button_int.gd
##
## `OptionButtonInt` is an `OptionButton` node which is driven by a
## `StdSettingsPropertyInt` and `StdSettingsPropertyIntList`.
##

@tool
extends "option_button.gd"

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a `StdSettingsPropertyInt` used to drive the control's value.
@export var property: StdSettingsPropertyInt = null:
	set(value):
		property = value

		$StdSettingsControllerOptionButtonInt.property = value
		update_configuration_warnings()

## options_property is a `StdSettingsPropertyIntList` used to drive the control's
## list of allowed values.
@export var options_property: StdSettingsPropertyIntList = null:
	set(value):
		options_property = value

		$StdSettingsControllerOptionButtonInt.options_property = value
		update_configuration_warnings()

## formatter is a type which formats the option button's items.
@export var formatter: StdSettingsControllerOptionButtonFormatter = null:
	set(value):
		formatter = value
		$StdSettingsControllerOptionButtonInt.formatter = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	return $StdSettingsControllerOptionButtonInt._get_configuration_warnings()


func _ready() -> void:
	$StdSettingsControllerOptionButtonInt.property = property
	$StdSettingsControllerOptionButtonInt.options_property = options_property
