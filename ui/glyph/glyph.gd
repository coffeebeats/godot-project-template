##
## ui/glyph/glyph.gd
##
## UiGlyph is an opinionated implementation of a dynamic origin icon which updates its
## contents based on what the action is currently bound to and which device the player
## is currently using.
##

@tool
extends StdInputGlyph

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _label: Label = get_node("Label")
@onready var _texture_rect: TextureRect = get_node("TextureRect")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _update_glyph() -> bool:
	var texture_prev: Texture = _texture_rect.texture
	var label_prev: String = _label.text

	_texture_rect.texture = _slot.get_action_glyph(action_set.name, action, _texture_rect.size)
	_texture_rect.visible = _texture_rect.texture != null

	_label.text = (
		_slot.get_action_origin_label(action_set.name, action)
		if not _texture_rect.texture
		else ""
	)

	_label.text = _label.text.to_upper()
	_label.visible = _label.text != ""

	return _texture_rect.texture != texture_prev or _label.text != label_prev
