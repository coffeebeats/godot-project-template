##
## project/menu/save/menu.gd
##
## SaveSlots is a menu which displays save slot information and, upon selecting one,
## proceeds to load the game scene.
##

extends PanelContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const SlotButton := preload("slot_button.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## confirm_delete_scene is the confirmation dialog shown before erasing a save slot.
@export var confirm_delete_scene: PackedScene

# -- INITIALIZATION ------------------------------------------------------------------ #

var _confirm_delete: AlertDialog

@onready var _delete_buttons: Control = %DeleteButtons
@onready var _slot_buttons: Control = %SlotButtons

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(_confirm_delete):
			_confirm_delete.free()
			_confirm_delete = null


func _ready() -> void:
	_confirm_delete = confirm_delete_scene.instantiate()

	for child in _slot_buttons.get_children():
		var button: SlotButton = child
		if not button is SlotButton:
			continue

		Signals.connect_safe(button.pressed, _on_slot_button_pressed.bind(button.slot))

	var saves := Systems.saves()

	for slot in _delete_buttons.get_child_count():
		var button: Button = _delete_buttons.get_child(slot)
		if not button is Button:
			continue

		var status := saves.get_save_slot(slot).status
		button.disabled = status == SaveSlot.STATUS_EMPTY
		(
			Signals
			. connect_safe(
				button.pressed,
				_on_delete_button_pressed.bind(button, slot),
			)
		)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_delete_button_pressed(
	button: Button,
	slot: int,
) -> void:
	var saves := Systems.saves()
	if saves.get_save_slot(slot).status == SaveSlot.STATUS_EMPTY:
		return

	_confirm_delete.open()
	var action: AlertDialog.Action = await _confirm_delete.closed
	if action == AlertDialog.Action.PRIMARY:
		button.disabled = true
		if not saves.erase_slot(slot):
			var error := (
				ProjectError
				. new(
					"error_delete_failed_title",
					"error_delete_failed_message",
					ProjectError.Severity.ERROR,
				)
			)
			await Main.show_error(error, &"alert_continue")
			button.disabled = false


func _on_slot_button_pressed(slot: int) -> void:
	Main.screens().pop(slot)
