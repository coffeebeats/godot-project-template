##
## system/setting/video/window_observer.gd
##
## WindowObserver is a `StdSettingsObserver` which handles changing the window mode and
## other window-related properties.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## fullscreen_property is a settings property for fullscreen mode.
@export var fullscreen_property: StdSettingsPropertyBool = null

## borderless_property is a settings property for borderless windows.
@export var borderless_property: StdSettingsPropertyBool = null

@export_category("Window")

## window_mode_property is a settings property for the project's explicit window mode.
##
## NOTE: This must be synced to project settings to work.
@export var window_mode_property: StdSettingsPropertyInt = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_resizable: bool = ProjectSettings.get_setting_with_override(
	&"display/window/size/resizable"
)

var _window_mode: Window.Mode = ProjectSettings.get_setting_with_override(
	&"display/window/size/mode"
)

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func set_borderless(value: bool, window_id: int = 0) -> void:
	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: set borderless: %s" % value,
	)

	(
		DisplayServer
		. window_set_flag(
			DisplayServer.WINDOW_FLAG_BORDERLESS,
			value,
			window_id,
		)
	)


func set_fullscreen(value: bool) -> void:
	var window := get_window()
	var window_id := window.get_window_id()

	# NOTE: Always save the target window mode in case window-level controls drove the
	# change in value (instead of the settings UI).
	var mode: Window.Mode = Window.MODE_FULLSCREEN if value else Window.MODE_WINDOWED
	_save_window_mode(window.mode)

	# No change required, but some reconciliation is required if this change was driven
	# by window-level controls.
	if value == (window.mode >= Window.MODE_FULLSCREEN):
		call_deferred(&"_update_borderless")
		return

	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: updating window mode: %d" % mode,
	)

	if value:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: entering fullscreen",
		)

		# FIXME: On macOS, after entering fullscreen with borderless enabled, disabling
		# borderless and the exiting fullscreen causes the title bar to be inaccessible.
		# As a workaround, disable borderless prior to entering fullscreen (it will be
		# set correctly after exiting fullscreen anyway).
		if Feature.is_macos_platform():
			call_deferred(&"set_borderless", false, window_id)

		call_deferred(&"_set_window_mode", mode, window_id)

	else:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: exiting fullscreen",
		)

		# FIXME: On macOS, when exiting fullscreen with resizable enabled, the window
		# shrinks to a zero size. To fix, disable resize before exiting fullscreen.
		if Feature.is_macos_platform():
			call_deferred(&"_set_resizable", false, window_id)

		call_deferred(&"_set_window_mode", mode, window_id)
		call_deferred(&"_shrink_window", window_id)
		call_deferred(&"_update_borderless")
		call_deferred(&"_center_window", window_id)

		if Feature.is_macos_platform() and _is_resizable:
			call_deferred(&"_set_resizable", true, window_id)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	super._ready()

	var window := get_window()

	# Reconcile the user-level properties with the actual initial window state.
	borderless_property.set_value(window.borderless)
	fullscreen_property.set_value(window.mode >= Window.MODE_FULLSCREEN)

	if window.mode < Window.MODE_FULLSCREEN:
		_center_window(window.get_window_id())


func _process(_delta: float) -> void:
	var window: Window = get_window()

	if window.mode != _window_mode:
		_handle_window_mode_change(window)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [fullscreen_property, borderless_property]


func _handle_value_change(property: StdSettingsProperty, value) -> void:
	if property == fullscreen_property:
		assert(fullscreen_property, "invalid state: missing property")
		assert(window_mode_property, "invalid state: missing property")

		set_fullscreen(value)

	if property == borderless_property:
		assert(borderless_property, "invalid state: missing property")

		set_borderless(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _center_window(window_id: int = 0) -> void:
	var size_screen := DisplayServer.screen_get_size()
	var size_window := DisplayServer.window_get_size_with_decorations(window_id)
	var size_title := _get_title_size(window_id)

	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: centering window",
	)

	(
		DisplayServer
		. window_set_position(
			(size_screen / 2 - size_window / 2) + Vector2i(0, size_title.y),
			window_id,
		)
	)


func _get_title_size(window_id: int = 0) -> Vector2i:
	var title := (
		DisplayServer
		. window_get_title_size(
			ProjectSettings.get_setting_with_override("application/config/name"),
			window_id,
		)
	)

	return Vector2i(0, title.y)


func _handle_window_mode_change(window: Window) -> void:
	var window_mode_prev := _window_mode
	_window_mode = window.mode

	if window.mode == window_mode_prev:
		return

	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		(
			"]: detected change in window mode (%d, previously %d)"
			% [window.mode, window_mode_prev]
		),
	)

	if not fullscreen_property.set_value(window.mode >= Window.MODE_FULLSCREEN):
		_update_fullscreen()


func _save_window_mode(mode: Window.Mode) -> void:
	assert(
		window_mode_property is StdSettingsPropertyInt,
		"invalid state; missing property"
	)

	window_mode_property.set_value(mode)


func _set_resizable(value: bool, window_id: int = 0) -> void:
	(
		DisplayServer
		. window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			not value,
			window_id,
		)
	)


func _set_window_mode(mode: DisplayServer.WindowMode, window_id: int = 0) -> void:
	if mode == DisplayServer.window_get_mode(window_id):
		return

	_window_mode = mode as Window.Mode
	DisplayServer.window_set_mode(mode, window_id)

	_save_window_mode(mode as Window.Mode)


func _shrink_window(window_id: int = 0) -> void:
	var size := DisplayServer.get_display_safe_area().size / 2
	if size == DisplayServer.window_get_size(window_id):
		return

	DisplayServer.window_set_size(size, window_id)


func _update_borderless() -> void:
	var is_borderless: bool = borderless_property.get_value()
	borderless_property.value_changed.emit(is_borderless)


func _update_fullscreen() -> void:
	var is_fullscreen: bool = fullscreen_property.get_value()
	fullscreen_property.value_changed.emit(is_fullscreen)
