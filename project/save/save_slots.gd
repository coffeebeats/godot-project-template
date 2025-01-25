##
## project/save/save_slots.gd
##
## SaveSlots is a menu which displays save slot information and, upon selecting one,
## proceeds to load the game scene.
##

extends PanelContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SceneHandle := preload("res://addons/std/scene/handle.gd")
const Saves := preload("res://system/save/saves.gd")
const SlotButton := preload("slot_button.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene_handle is an `std` scene handle used to emit transition events to the main
## scene state machine.
@export var scene_handle: SceneHandle = null

# -- INITIALIZATION ------------------------------------------------------------------ #

# NOTE: Accessing `Saves` via the `System` autoload works, but produces an error
# (seemingly when this script is loaded on another thread). The workaround, fetching the
# node via its path, prevents the error.
@onready var _saves: Saves = get_node(^"/root/System/Saves")
@onready var _delete_buttons: Control = %DeleteButtons
@onready var _slot_buttons: Control = %SlotButtons

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready():
	assert(scene_handle is SceneHandle, "invalid state; missing node")

	for child in _slot_buttons.get_children():
		var button: SlotButton = child
		if not button is SlotButton:
			continue

		button.pressed.connect(_on_slot_button_pressed.bind(button.slot))

	for slot in _delete_buttons.get_child_count():
		var button: Button = _delete_buttons.get_child(slot)
		if not button is Button:
			continue

		button.disabled = _saves.get_save_slot(slot).status == SaveSlot.STATUS_EMPTY
		button.pressed.connect(_on_delete_button_pressed.bind(button, slot))


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_delete_button_pressed(button: Button, slot: int) -> void:
	if _saves.get_save_slot(slot).status == SaveSlot.STATUS_EMPTY:
		return

	button.disabled = true

	if not _saves.erase_slot(slot):
		button.disabled = false


func _on_slot_button_pressed(slot: int) -> void:
	if not _saves.activate_slot(slot):
		return

	scene_handle.transition_to(^"Core/Loading/Scene")
