##
## project/settings/input/checkbox.gd
##
## CheckBox is a `CheckBox` node which is driven by a `StdSettingsPropertyBool`.
##

@tool
extends CheckBox

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a `StdSettingsProperty` used to drive the control's value.
@export var property: StdSettingsPropertyBool = null:
	set(value):
		property = value
		$StdSettingsControllerToggleButton.property = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	return $StdSettingsControllerToggleButton._get_configuration_warnings()
