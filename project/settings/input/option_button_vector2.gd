##
## project/settings/input/option_button_resolution.gd
##
## `OptionButtonResolution` is an `OptionButton` node which is driven by a
## `StdSettingsPropertyVector2` and `StdSettingsPropertyVector2List`. This is meant for
## selecting a display resolution.
##

@tool
extends "option_button.gd"

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a `StdSettingsPropertyVector2` used to drive the control's value.
@export var property: StdSettingsPropertyVector2 = null:
	set(value):
		property = value
		$StdSettingsControllerOptionButtonVector2.property = value
		update_configuration_warnings()

## options_property is a `StdSettingsPropertyVector2List` used to drive the control's
## list of allowed values.
@export var options_property: StdSettingsPropertyVector2List = null:
	set(value):
		options_property = value
		$StdSettingsControllerOptionButtonVector2.options_property = value
		update_configuration_warnings()

## formatter is a type which formats the option button's items.
@export var formatter: StdSettingsControllerOptionButtonFormatter = null:
	set(value):
		formatter = value
		$StdSettingsControllerOptionButtonVector2.formatter = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	return $StdSettingsControllerOptionButtonVector2._get_configuration_warnings()


func _ready() -> void:
	$StdSettingsControllerOptionButtonVector2.property = property
	$StdSettingsControllerOptionButtonVector2.options_property = options_property

	var popup_menu := get_popup()

	for i in popup_menu.get_item_count():
		popup_menu.set_item_as_checkable(i, true)
		popup_menu.set_item_as_radio_checkable(i, false)
