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
		Vector2(3024, 1964), # MacBook Pro 14"
		Vector2(3456, 2234), # MacBook Pro 16"
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
		Vector2(4096, 2304), # iMac Retina 21.5"
		Vector2(4480, 2520), # iMac Retina 24"
		Vector2(5120, 2880), # iMac Retina 27"
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
		Vector2(2560, 1664), # Macbook Air 13"
		Vector2(2560, 1600),
		Vector2(2880, 1800),
		Vector2(2880, 1864), # Macbook Air 15"
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

	var size_max = DisplayServer.get_display_safe_area().size - _get_title_size()
	var target_aspects := [DisplayServer.screen_get_size().aspect()]

	for resolutions in resolutions_by_aspect:
		var is_matching_aspect := false

		for resolution in resolutions:
			for target_aspect in target_aspects:
				if abs(target_aspect - resolution.aspect()) <= 0.02:
					is_matching_aspect = true
					break

		if not is_matching_aspect:
			continue

		for resolution in resolutions:
			if resolution.x > size_max.x or resolution.y > size_max.y:
				continue

			out.append(resolution)

	# # If no resolutions match the screen's aspect ratio, just provide all resolutions
	# # smaller than the screen and let the user decide.
	# if out.is_empty():
	# 	for resolutions in resolutions_by_aspect:
	# 		for resolution in resolutions:
	# 			if resolution.x > size_max.x or resolution.y > size_max.y:
	# 				continue

	# 			out.append(resolution)

	return out


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_title_size(window_id: int = 0) -> Vector2i:
	var title := (
		DisplayServer
		.window_get_title_size(
			ProjectSettings.get_setting_with_override("application/config/name"),
			window_id,
		)
	)

	return Vector2i(0, title.y)


func _round_to_vector2i(value: Vector2) -> Vector2i:
	return Vector2i(round(value.x), round(value.y))
