##
## std/setting/option_button_formatter_window_mode.gd
##
## `OptionButtonFormatterWindowMode` is a type which describes how to format
## `DisplayServer.WindowFlags` options.
##

extends StdSettingsControllerOptionButtonFormatter

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(value: Variant) -> String:
	assert(value is int, "invalid type: expected an int")

	match value:
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return "Fullscreen (exclusive)"
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return "Fullscreen (borderless)"
		DisplayServer.WINDOW_MODE_WINDOWED:
			return "Windowed"

	assert(false, "unimplemented")
	return ""
