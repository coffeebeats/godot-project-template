##
## project/ui/glyph/glyph.gd
##
## UiGlyph is an opinionated implementation of a dynamic origin icon which updates its
## contents based on what the action is currently bound to and which device the player
## is currently using.
##

@tool
extends StdInputGlyph

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Display")

## always_show_kbm forcibly shows glyph information for keyboard and mouse devices. When
## enabled, `device_type_override` will be ignored.
##
## NOTE: Only one of `always_show_kbm` and `always_show_joy` may be `true`. If neither
## are enabled then either the active device's type is used or the
## `device_type_override` if it's set.
@export var always_show_kbm: bool = false:
	set(value):
		always_show_kbm = value
		if value and always_show_joy:
			always_show_joy = false

## always_show_joy forcibly shows glyph information for joypad devices. When enabled,
## `device_type_override` will be ignored.
##
## NOTE: Only one of `always_show_joy` and `always_show_kbm` may be `true`. If neither
## are enabled then either the active device's type is used or the
## `device_type_override` if it's set.
@export var always_show_joy: bool = false:
	set(value):
		always_show_joy = value
		if value and always_show_kbm:
			always_show_kbm = false

## hide_if_kbm_active controls whether this glyph is displayed when the active device is
## a keyboard and mouse. Note that this applies regardless of whether `always_show_kbm`
## is selected.

@export var hide_if_kbm_active: bool = false

## hide_if_joy_active controls whether this glyph is displayed when the active device is
## a joypad. Note that this applies regardless of whether `always_show_joy`
## is selected.
@export var hide_if_joy_active: bool = false

@export_subgroup("Labels")

## show_origin_label_as_fallback_kbm controls whether to show the origin display name if
## there's no glyph icon available for the keyboard and mouse device.
@export var show_origin_label_as_fallback_kbm: bool = true

## show_origin_label_as_fallback_joy controls whether to show the origin display name if
## there's no glyph icon available for joypad devices.
@export var show_origin_label_as_fallback_joy: bool = false

## Fallback properties apply when neither a glyph or a label (if configured) are found
## for the configured action. When fallbacks are used, *both* of the label and textures
## are used if set.
@export_subgroup("Fallback")

## fallback_label is a label to display when no glyph or label is found.
@export var fallback_label: String = ""

## fallback_texture is a texture to display when no glyph or label is found.
@export var fallback_texture: Texture2D = null

@export_group("Components")

## label is the `Label` node which origin display names will be rendered in.
@export var label: Label = null

## texture_rect is the `TextureRect` node which the origin glyph icon will be rendered
## in.
@export var texture_rect: TextureRect = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _custom_minimum_size: Vector2 = Vector2.ZERO
var _keyboard_language: String = _get_keyboard_language()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	var keyboard_language := _get_keyboard_language()

	if keyboard_language != _keyboard_language:
		_keyboard_language = keyboard_language
		update()


func _ready() -> void:
	super._ready() # gdlint:ignore=private-method-call

	
	if Engine.is_editor_hint():
		set_process(false)
		return

	set_process(_slot.device_type == DeviceType.KEYBOARD)

	assert(label is Label, "invalid state; missing node")
	assert(texture_rect is TextureRect, "invalid state; missing node")

	_custom_minimum_size = custom_minimum_size


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _device_activated(device: StdInputDevice) -> void:
	set_process(device.device_type == DeviceType.KEYBOARD)


func _get_device_type() -> DeviceType:
	if always_show_kbm:
		return DeviceType.KEYBOARD

	var property_value: DeviceType = DEVICE_TYPE_UNKNOWN
	if device_type_override is StdSettingsPropertyInt:
		property_value = device_type_override.get_value()

	if always_show_joy:
		# When showing joypad glyphs, still check if an override was set in settings,
		# but only use it if a joypad type is selected.
		if device_type_override is StdSettingsPropertyInt:
			if (
				property_value != DEVICE_TYPE_UNKNOWN
				and property_value != DEVICE_TYPE_KEYBOARD
			):
				return property_value

		var last_active_joy := _slot.get_last_active_joypad_device()
		if last_active_joy:
			return last_active_joy.device_type

		var connected := _slot.get_connected_devices(false)
		return connected[0].device_type if connected else DeviceType.GENERIC

	return (
		property_value if property_value != DEVICE_TYPE_UNKNOWN else _slot.device_type
	)


func _update_glyph(device_type: DeviceType) -> bool:
	var label_prev: String = label.text
	label.text = ""

	var texture_prev: Texture = texture_rect.texture
	texture_rect.texture = null

	var should_hide := (
		(_slot.device_type == DEVICE_TYPE_KEYBOARD and hide_if_kbm_active)
		or (
			_slot.device_type != DEVICE_TYPE_KEYBOARD
			and _slot.device_type != DEVICE_TYPE_UNKNOWN
			and hide_if_joy_active
		)
	)

	if not should_hide:
		texture_rect.texture = (
			_slot
			.get_action_glyph(
				action_set,
				action,
				binding_index,
				custom_minimum_size,
				device_type,
			)
		)

		if (
			texture_rect.texture == null
			and (
				(
					show_origin_label_as_fallback_kbm
					and device_type == DEVICE_TYPE_KEYBOARD
				)
				or (
					show_origin_label_as_fallback_joy
					and device_type != DEVICE_TYPE_KEYBOARD
					and device_type != DEVICE_TYPE_UNKNOWN
				)
			)
		):
			label.text = (
				_slot
				.get_action_origin_label(
					action_set,
					action,
					binding_index,
					device_type,
				)
			)

	if not should_hide and texture_rect.texture == null and label.text == "":
		label.text = fallback_label
		texture_rect.texture = fallback_texture

	texture_rect.visible = texture_rect.texture != null
	label.visible = label.text != ""

	var minimum_size := _custom_minimum_size

	if texture_rect.visible:
		minimum_size = minimum_size.max(texture_rect.get_combined_minimum_size())

	if label.visible:
		minimum_size = minimum_size.max(label.get_combined_minimum_size())

	custom_minimum_size = minimum_size

	return texture_rect.texture != texture_prev or label.text != label_prev


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_keyboard_language() -> String:
	var index := DisplayServer.keyboard_get_current_layout()
	return DisplayServer.keyboard_get_layout_language(index)
