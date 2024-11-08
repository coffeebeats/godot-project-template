##
## project/settings/input/option_button.gd
##
## OptionButton is a base `OptionButton` node which implements common cosmetic behavior.
##

@tool
extends OptionButton

# -- CONFIGURATION ------------------------------------------------------------------- #

## checkable controls whether the available options contain a `CheckBox` node.
@export var checkable: bool = true

## radio_checkable controls whether the available options contain a radio button node.
@export var radio_checkable: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready():
	assert(
		not (checkable and radio_checkable),
		"invalid state: cannot set checkable and radio_checkable",
	)

	var popup_menu := get_popup()

	for i in popup_menu.get_item_count():
		popup_menu.set_item_as_checkable(i, checkable)
		popup_menu.set_item_as_radio_checkable(i, radio_checkable)
