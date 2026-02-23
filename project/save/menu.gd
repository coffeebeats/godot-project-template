##
## project/save/menu.gd
##
## SaveSlots is a menu which displays save slot information and, upon selecting one,
## proceeds to load the game scene.
##

extends PanelContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ConfirmScene := preload("res://project/save/confirm.tscn")
const ConfirmScreen := preload("res://project/save/confirm_screen.tres")
const Signals := preload("res://addons/std/event/signal.gd")
const SlotButton := preload("slot_button.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _delete_buttons: Control = %DeleteButtons
@onready var _slot_buttons: Control = %SlotButtons

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	for child in _slot_buttons.get_children():
		var button: SlotButton = child
		if not button is SlotButton:
			continue

		button.pressed.connect(_on_slot_button_pressed.bind(button.slot))

	var saves := Systems.saves()

	for slot in _delete_buttons.get_child_count():
		var button: Button = _delete_buttons.get_child(slot)
		if not button is Button:
			continue

		var status := saves.get_save_slot(slot).status
		button.disabled = status == SaveSlot.STATUS_EMPTY
		button.pressed.connect(_on_delete_button_pressed.bind(button, slot))


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_delete_button_pressed(button: Button, slot: int) -> void:
	var saves := Systems.saves()
	if saves.get_save_slot(slot).status == SaveSlot.STATUS_EMPTY:
		return

	var scene := ConfirmScene.instantiate()
	var dialog: PanelContainer = scene.get_node("%AlertDialog")

	dialog.confirmed.connect(
		func():
			Main.screens().pop()
			button.disabled = true
			if not saves.erase_slot(slot):
				button.disabled = false,
		CONNECT_ONE_SHOT,
	)

	dialog.cancelled.connect(
		func(): Main.screens().pop(),
		CONNECT_ONE_SHOT,
	)

	Main.screens().push(ConfirmScreen, scene)


func _on_slot_button_pressed(slot: int) -> void:
	# TODO: Close the save menu on error.
	Main.load_game(slot)
