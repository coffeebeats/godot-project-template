##
## project/save/slot_button.gd
##
## SlotButton is a button which displays information about a save slot. When pressed, it
## activates the corresponding save slot.
##

extends Button

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## slot is the save slot index (0-based) which this button corresponds to.
@export var slot: int = 0

# -- INITIALIZATION ------------------------------------------------------------------ #

var _save_slot: SaveSlot = null

@onready var _label_active: Label = %Active
@onready var _label_empty: Label = %Empty
@onready var _label_broken: Label = %Broken
@onready var _container_contents: Control = %Contents
@onready var _label_last_updated: Label = %LastUpdated

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	Signals.disconnect_safe(System.saves.slot_activated, _on_save_slot_updated)
	Signals.disconnect_safe(System.saves.slot_deactivated, _on_save_slot_updated)
	Signals.disconnect_safe(System.saves.slot_erased, _on_save_slot_updated)
	Signals.disconnect_safe(_save_slot.changed, _on_save_slot_changed)
	Signals.disconnect_safe(pressed, _on_pressed)


func _ready():
	_save_slot = System.saves.get_save_slot(slot)
	assert(_save_slot is SaveSlot, "invalid state; missing save summary")

	Signals.connect_safe(System.saves.slot_activated, _on_save_slot_updated)
	Signals.connect_safe(System.saves.slot_deactivated, _on_save_slot_updated)
	Signals.connect_safe(System.saves.slot_erased, _on_save_slot_updated)
	Signals.connect_safe(_save_slot.changed, _on_save_slot_changed)
	Signals.connect_safe(pressed, _on_pressed)

	_update_contents()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_contents() -> void:
	assert(_save_slot is SaveSlot, "invalid state; missing save summary")

	var is_empty := _save_slot.status == SaveSlot.STATUS_EMPTY
	var is_broken := (
		_save_slot.status == SaveSlot.STATUS_BROKEN
		or _save_slot.status == SaveSlot.STATUS_UNKNOWN
	)

	_container_contents.visible = _save_slot.status == SaveSlot.STATUS_OK
	_label_active.visible = slot == System.saves.get_active_save_slot()
	_label_empty.visible = is_empty
	_label_broken.visible = is_broken

	disabled = is_broken

	if is_empty or is_broken:
		return

	# See https://github.com/godotengine/godot/issues/66695
	_label_last_updated.text = (
		Time
		. get_datetime_string_from_unix_time(
			int(_save_slot.summary.time_last_saved),
			true,
		)
	)

	# TODO: Populate additional display information as needed.


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_pressed() -> void:
	System.saves.activate_slot(slot)


func _on_save_slot_updated(index: int) -> void:
	if index != slot:
		return

	_update_contents()


func _on_save_slot_changed() -> void:
	_update_contents()
