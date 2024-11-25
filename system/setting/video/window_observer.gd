##
## system/setting/video/window_observer.gd
##
## WindowObserver is a `StdSettingsObserver` which handles changing the window mode and
## display resolution.
##

extends StdSettingsObserver

# -- DEPENDENCIES -------------------------------------------------------------------- #

const StdSettingsPropertyResolution := preload("resolution_property.gd")
# const Feature := preload("res://platform/feature.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const WINDOW_WATCHER_DURATION_S := 2

static var window_modes_allowed: Array[DisplayServer.WindowMode] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]

# -- CONFIGURATION ------------------------------------------------------------------- #

## window_mode_property is a settings property defining the window mode property to
## observe.
@export var window_mode_property: StdSettingsPropertyInt = null

## resolution_property is a settings property defining the target resolution.
@export var resolution_property: StdSettingsPropertyResolution = null

## resolution_options_property is a settings property defining the list of supported
## target resolutions.
@export var resolution_options_property: StdSettingsPropertyVector2List = null

@export_category("Window size")

## window_height_property is a settings property for the project's window height
## override value.
##
## NOTE: This must be synced to project settings to work.
@export var window_height_property: StdSettingsPropertyInt = null

## window_width_property is a settings property for the project's window width
## override value.
##
## NOTE: This must be synced to project settings to work.
@export var window_width_property: StdSettingsPropertyInt = null

# -- INITIALIZATION ------------------------------------------------------------------ #

# FIXME(https://github.com/godotengine/godot/issues/94551): Remove this option.
## disable_resize_when_windowed adds a temporary workaround for
## https://github.com/godotengine/godot/issues/94551. Note that this workaround in turn
## suffers from https://github.com/godotengine/godot/issues/81640.
var _is_resize_enabled: bool = ProjectSettings.get_setting_with_override(
	&"display/window/size/resizable"
)

var _elapsed: float = 0.0
var _window_mode: Window.Mode = ProjectSettings.get_setting_with_override(
	&"display/window/size/mode"
)

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func set_resolution(resolution: Vector2) -> void:
	assert(resolution_property, "invalid state: missing resolution property")
	assert(
		Vector2i(resolution) <= DisplayServer.screen_get_size(),
		"invalid argument: resolution larger than screen",
	)

	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: set window resolution: %s" % resolution,
	)

	var window := get_window()
	var window_id := window.get_window_id()

	var has_resolution_changed: bool = false

	assert(
		window.mode != Window.MODE_MINIMIZED,
		"invalid state; updating resolution while minized"
	)

	# NOTE: Fullscreen always matches window size to screen size, so only update
	# resolution when windowed.
	if not _is_fullscreen(window.mode):
		var window_size_target := Vector2i(resolution)

		if window_size_target != window.size:
			print(
				"system/setting/video/window_observer.gd[",
				get_instance_id(),
				"]: updating window resolution: %s" % window_size_target,
			)

			window.size = window_size_target
			has_resolution_changed = true

		# NOTE: DON'T SET THIS - THIS IS A WINDOW CONTROL.
		# var screen := DisplayServer.get_display_safe_area().size - _get_title_size(window_id)
		# if resolution == Vector2(screen.x, screen.y) and window.mode != Window.MODE_MAXIMIZED:
		# 	window.mode = Window.MODE_MAXIMIZED

		# 	# NOTE: Update cached value so window resize handler doesn't re-trigger.
		# 	_window_mode = window.mode

	_save_resolution(resolution)

	if (
		has_resolution_changed
		and (
			window.mode == Window.MODE_WINDOWED or window.mode == Window.MODE_MAXIMIZED
		)
	):
		call_deferred(&"_center_window", window_id)


func set_window_mode(mode: Window.Mode) -> void:
	assert(resolution_property, "invalid state: missing property")
	assert(window_mode_property, "invalid state: missing property")
	assert(mode in window_modes_allowed, "invalid argument; unsupported window mode")

	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: set window mode: %d" % mode,
	)

	var window := get_window()

	var was_fullscreen := _is_fullscreen(window.mode)
	var is_fullscreen := _is_fullscreen(mode)

	var has_window_mode_changed: bool = false

	assert(
		window.mode != Window.MODE_MINIMIZED,
		"invalid state; updating resolution while minized"
	)

	# NOTE: Only change window mode if there's a need to transition between fullscreen
	# and windowed mode. Maximized and minimized should not force an update as these are
	# special cases of windowed that are intentionally entered by the player.
	if (was_fullscreen and not is_fullscreen) or not was_fullscreen and is_fullscreen:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: updating window mode: %d" % mode,
		)

		# NOTE: Update cached value so window resize handler doesn't re-trigger.
		_window_mode = mode

		window.mode = mode
		has_window_mode_changed = true

	if not has_window_mode_changed:
		return

	call_deferred(&"_update_resolution_options")

	if was_fullscreen and not is_fullscreen:
		call_deferred(&"_disable_fullscreen_effects")
		resolution_property.call_deferred(&"select_midpoint", true)
	elif not was_fullscreen and is_fullscreen:
		call_deferred(&"_enable_fullscreen_effects")


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	super._ready()

	set_process(false)

	var window := get_window()

	var err := window.titlebar_changed.connect(_on_Window_titlebar_changed)
	assert(err == OK, "failed to connect to signal")

	err = get_tree().root.size_changed.connect(_on_Window_size_changed)
	assert(err == OK, "failed to connect to signal")

	if window.mode < Window.MODE_FULLSCREEN:
		_center_window(window.get_window_id())


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= WINDOW_WATCHER_DURATION_S:
		_watch_window_mode_stop()

	_update_window_mode()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [window_mode_property, resolution_property]


func _handle_value_change(property: StdSettingsProperty, value) -> void:
	if property == window_mode_property:
		set_window_mode(value)

	if property == resolution_property:
		if get_window().mode == Window.MODE_MAXIMIZED:
			set_window_mode(Window.MODE_WINDOWED)
			call_deferred(&"set_resolution", value)
		else:
			set_resolution(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _center_window(window_id: int = 0) -> void:
	var size_screen := DisplayServer.screen_get_size()
	var size_window := DisplayServer.window_get_size_with_decorations(window_id)
	var size_title := DisplayServer.window_get_title_size("Godot", window_id)

	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: centering window",
	)

	DisplayServer.window_set_position(
		(size_screen / 2 - size_window / 2) + Vector2i(0, size_title.y), window_id
	)


func _disable_fullscreen_effects(window_id: int = 0) -> void:
	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: disabling fullscreen effects",
	)

	_set_borderless(true, window_id)

	# FIXME: Upon first loading a game in fullscreen mode, assuming the window is
	# resizable, resizing via code *after* changing to windowed mode fails if window
	# resize is enabled. Therefore, manually disable it here, then conditionally
	# enable it after resizing the window.
	_set_resizable(false)

	# FIXME(https://github.com/godotengine/godot/issues/94551): Remove this and utilize
	# window resizing in project settings.
	if _is_resize_enabled:
		_set_resizable(true)


func _enable_fullscreen_effects() -> void:
	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: enabling fullscreen effects",
	)

	# Fullscreen mode forces the resolution to match the screen size. Update the
	# selected resolution to match this
	var size := DisplayServer.window_get_size_with_decorations()
	if not resolution_property.set_value(Vector2(size.x, size.y)):
		_update_resolution()


func _get_title_size(window_id: int = 0) -> Vector2i:
	var title := (
		DisplayServer
		. window_get_title_size(
			# ProjectSettings.get_setting_with_override("application/config/name"),
			"",
			window_id,
		)
	)

	return Vector2i(0, title.y)


func _is_fullscreen(mode: Window.Mode) -> bool:
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func _save_resolution(size: Vector2i) -> void:
	assert(
		window_height_property is StdSettingsPropertyInt,
		"invalid state; missing property"
	)
	assert(
		window_width_property is StdSettingsPropertyInt,
		"invalid state; missing property"
	)

	window_height_property.set_value(size.y)
	window_width_property.set_value(size.x)


func _set_borderless(value: bool, window_id: int = 0) -> void:
	(
		DisplayServer
		. window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			value,
			window_id,
		)
	)


func _set_resizable(value: bool, window_id: int = 0) -> void:
	(
		DisplayServer
		. window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			not value,
			window_id,
		)
	)


func _update_resolution() -> void:
	var resolution: Vector2 = resolution_property.get_value()
	resolution_property.value_changed.emit(resolution)


func _update_resolution_options() -> void:
	var resolution_options: PackedVector2Array = resolution_options_property.get_value()
	resolution_options_property.value_changed.emit(resolution_options)


func _update_window_mode() -> void:
	var window := get_window()
	var window_mode_target: Window.Mode = window_mode_property.get_value()

	if window_mode_target != window.mode:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: window mode update required: %d" % window.mode,
		)

		set_window_mode(window.mode)

		_watch_window_mode_stop()


func _watch_window_mode_start() -> void:
	_elapsed = 0.0
	if not is_processing():
		set_process(true)


func _watch_window_mode_stop() -> void:
	_elapsed = 0.0
	if is_processing():
		set_process(false)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Window_size_changed() -> void:
	var window := get_window()

	var window_mode_prev := _window_mode
	_window_mode = window.mode

	if window.mode != window_mode_prev:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			(
				"]: detected change in window size: %s (%s)"
				% [get_window().size, window.mode]
			),
		)

		# NOTE: Entered maximize state; update mode to fullscreen.
		if (
			window.mode == Window.MODE_MAXIMIZED
			and window_mode_prev == Window.MODE_WINDOWED
		):
			window_mode_property.call_deferred(&"set_value", Window.MODE_FULLSCREEN)


func _on_Window_titlebar_changed() -> void:
	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: detected change in titlebar visibility",
	)

	_watch_window_mode_start()
