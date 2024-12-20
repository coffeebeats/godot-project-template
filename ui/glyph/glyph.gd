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

@export var show_label_if_texture_missing_kbm: bool = true

@export var show_label_if_texture_missing_joy: bool = false

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _label: Label = get_node("Label")
@onready var _texture_rect: TextureRect = get_node("TextureRect")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _update_glyph() -> bool:
	var label_prev: String = _label.text
	_label.text = ""

	var texture_prev: Texture = _texture_rect.texture
	_texture_rect.texture = null

	var is_kbm := _slot.device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD
	var is_compatible := (is_kbm and show_on_kbm) or (not is_kbm and show_on_joy)

	if is_compatible:
		_texture_rect.texture = _slot.get_action_glyph(action_set.name, action, _texture_rect.size)

		_label.text = (
			_slot.get_action_origin_label(action_set.name, action)
			if (
				not _texture_rect.texture
				and (
					(is_kbm and show_label_if_texture_missing_kbm)
					or (not is_kbm and show_label_if_texture_missing_joy)
				)
			)
			else ""
		)

	_texture_rect.visible = _texture_rect.texture != null
	_label.visible = _label.text != ""

	return _texture_rect.texture != texture_prev or _label.text != label_prev
