##
## system/setting/property/video/resolution_options_property.gd
##
## `VideoResolutionOptions` is a read-only settings property that provides a list of
## display resolution options based on various video preferences.
##

extends StdSettingsPropertyVector2List

# -- CONFIGURATION ------------------------------------------------------------------- #

## window_mode_property is a settings property defining the window mode.
@export var window_mode_property: StdSettingsPropertyInt = null

## use_viewport_aspect_when_windowed controls whether the viewport's aspect ratio is
## used instead of the screen's when in non-fullscreen windowed mode.
@export var use_viewport_aspect_when_windowed: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

static var resolutions_4_3 := PackedVector2Array(
	[
		# 4:3
		Vector2(800, 600),
		Vector2(1024, 768),
		Vector2(2048, 1536),
	]
)

static var resolutions_5_4 := PackedVector2Array(
	[
		# 5:4
		Vector2(1280, 1024),
	]
)

static var resolutions_14_9 := PackedVector2Array(
	[
		# 14:9
		Vector2(3024, 1964),  # MacBook Pro 14"
		Vector2(3456, 2234),  # MacBook Pro 16"
	]
)

static var resolutions_16_9 := PackedVector2Array(
	[
		# 16:9
		Vector2(1280, 720),
		Vector2(1360, 768),
		Vector2(1366, 768),
		Vector2(1600, 900),
		Vector2(1920, 1080),
		Vector2(2048, 1152),
		Vector2(2560, 1440),
		Vector2(3840, 2160),
		Vector2(4096, 2304),  # iMac Retina 21.5"
		Vector2(4480, 2520),  # iMac Retina 24"
		Vector2(5120, 2880),  # iMac Retina 27"
		Vector2(7680, 4320),
	]
)

static var resolutions_16_10 := PackedVector2Array(
	[
		# 16:10
		Vector2(960, 600),
		Vector2(1280, 800),
		Vector2(1440, 900),
		Vector2(1680, 1050),
		Vector2(1920, 1200),
		Vector2(2048, 1280),
		Vector2(2304, 1440),
		Vector2(2560, 1664),  # Macbook Air 13"
		Vector2(2560, 1600),
		Vector2(2880, 1800),
		Vector2(2880, 1864),  # Macbook Air 15"
		Vector2(3024, 1890),
		Vector2(3072, 1920),
		Vector2(3456, 2160),
	]
)

static var resolutions_21_9 := PackedVector2Array(
	[
		# 21:9
		Vector2(2560, 1080),
		Vector2(3440, 1440),
		Vector2(3840, 1600),
	]
)

static var resolutions_by_aspect: Array[PackedVector2Array] = [
	resolutions_4_3,
	resolutions_5_4,
	resolutions_14_9,
	resolutions_16_9,
	resolutions_16_10,
	resolutions_21_9,
]

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(_config: Config) -> Variant:
	var out := PackedVector2Array()

	var window_mode: DisplayServer.WindowMode = window_mode_property.get_value()
	if (
		window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		or window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	):
		out.append(DisplayServer.window_get_size_with_decorations())
		return out

	var screen := DisplayServer.get_display_safe_area().size
	var viewport := Vector2(
		ProjectSettings.get_setting_with_override(
			&"display/window/size/viewport_width"
		),
		ProjectSettings.get_setting_with_override(
			&"display/window/size/viewport_height"
		),
	)

	var has_screen_resolution: bool = false
	var target_aspect := (
		viewport.aspect() if use_viewport_aspect_when_windowed else screen.aspect()
	)

	for resolutions in resolutions_by_aspect:
		var is_matching_aspect := false

		for resolution in resolutions:
			if resolution.aspect() == target_aspect:
				is_matching_aspect = true
				break

		if not is_matching_aspect:
			continue

		var to_add: PackedVector2Array = resolutions
		if resolutions == resolutions_14_9:
			to_add = resolutions.duplicate()
			to_add.append_array(resolutions_16_10)

		for resolution in to_add:
			if resolution.x > screen.x or resolution.y > screen.y:
				continue

			out.append(resolution)

			var current := Vector2i(round(resolution.x), round(resolution.y))
			if current == screen:
				has_screen_resolution = true

	# If no resolutions match the screen's aspect ratio, just provide all resolutions
	# smaller than the screen and let the user decide.
	if out.is_empty():
		for resolutions in resolutions_by_aspect:
			for resolution in resolutions:
				if resolution.x > screen.x or resolution.y > screen.y:
					continue

				out.append(resolution)

	if not has_screen_resolution:
		out.append(screen)

	out.sort()

	return out
