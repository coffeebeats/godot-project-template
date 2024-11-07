##
## std/setting/option_button_formatter_resolution.gd
##
## `OptionButtonFormatterResolution` is a type which describes how to format the
## `Vector2` resolution items.
##

extends StdSettingsControllerOptionButtonFormatter

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(value: Variant) -> String:
	var resolution: Vector2 = value

	return "%d x %d" % [resolution.x, resolution.y]
