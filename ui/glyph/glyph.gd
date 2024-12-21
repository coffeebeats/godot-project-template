##
## ui/glyph/glyph.gd
##
## UiGlyph is an opinionated implementation of a dynamic origin icon which updates its
## contents based on what the action is currently bound to and which device the player
## is currently using.
##

@tool
extends StdInputGlyph

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Display")

@export_subgroup("Visibility")

## show_on_kbm controls whether this glyph is displayed when the active device is a
## keyboard and mouse.
@export var show_on_kbm: bool = true

## show_on_joy controls whether this glyph is displayed when the active device is a
## joypad.
@export var show_on_joy: bool = true

@export_subgroup("Labels")

## show_label_if_texture_missing_kbm controls whether to show the origin display name if
## there's no glyph icon available for the keyboard and mouse device.
@export var show_label_if_texture_missing_kbm: bool = true

## show_label_if_texture_missing_joy controls whether to show the origin display name if
## there's no glyph icon available for the joypad device.
@export var show_label_if_texture_missing_joy: bool = false

@export_subgroup("Sizing")

@export_subgroup("Fallback")

@export var fallback_label: String = ""

@export_group("Components")

## label is the `Label` node which origin display names will be rendered in.
@export var label: Label = null

## texture_rect is the `TextureRect` node which the origin glyph icon will be rendered
## in.
@export var texture_rect: TextureRect = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _custom_minimum_size: Vector2 = Vector2.ZERO

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	super._ready()  # gdlint:ignore=private-method-call

	if Engine.is_editor_hint():
		return

	assert(label is Label, "invalid state; missing node")
	assert(texture_rect is TextureRect, "invalid state; missing node")

	_custom_minimum_size = custom_minimum_size


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _update_glyph() -> bool:
	var label_prev: String = label.text
	label.text = ""

	var texture_prev: Texture = texture_rect.texture
	texture_rect.texture = null

	var is_kbm := _slot.device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
	var is_compatible := (is_kbm and show_on_kbm) or (not is_kbm and show_on_joy)

	if is_compatible:
		texture_rect.texture = (
			_slot
			. get_action_glyph(
				action_set.name,
				action,
				custom_minimum_size,
			)
		)

		var contents := _slot.get_action_origin_label(action_set.name, action)
		label.text = (
			(contents if contents else fallback_label)
			if (
				not texture_rect.texture
				and (
					(is_kbm and show_label_if_texture_missing_kbm)
					or (not is_kbm and show_label_if_texture_missing_joy)
				)
			)
			else ""
		)

	texture_rect.visible = texture_rect.texture != null
	label.visible = label.text != ""

	var minimum_size := _custom_minimum_size

	if texture_rect.visible:
		minimum_size = minimum_size.max(texture_rect.get_combined_minimum_size())

	if label.visible:
		minimum_size = minimum_size.max(label.get_combined_minimum_size())

	custom_minimum_size = minimum_size

	return texture_rect.texture != texture_prev or label.text != label_prev
