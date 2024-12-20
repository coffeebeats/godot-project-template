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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_device_compatible: bool = true

@onready var _label: Label = get_node("Label")
@onready var _texture_rect: TextureRect = get_node("TextureRect")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_device_activated(_slot)
	super._ready()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _device_activated(device: StdInputDevice) -> void:
	_is_device_compatible = (
		show_on_kbm if device.device_type == StdInputDevice.DEVICE_TYPE_KEYBOARD else show_on_joy
	)


func _update_glyph() -> bool:
	var texture_prev: Texture = _texture_rect.texture
	var label_prev: String = _label.text

	_texture_rect.texture = null
	_label.text = ""

	if _is_device_compatible:
		_texture_rect.texture = _slot.get_action_glyph(action_set.name, action, _texture_rect.size)
		_label.text = (
			_slot.get_action_origin_label(action_set.name, action)
			if not _texture_rect.texture
			else ""
		)

	_texture_rect.visible = _texture_rect.texture != null
	_label.visible = _label.text != ""

	return _texture_rect.texture != texture_prev or _label.text != label_prev
