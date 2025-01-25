##
## system/save/save.gd
##
## SystemSave is a system for saving progress to `Config` files, suitable for small-to-
## medium sized games. Multiple slots are supported, though this implementation assumes
## a fixed (though configurable) limit.
##
## NOTE: This class is *not* thread-safe; save operations should be called from the main
## thread.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## slot_activated is emitted when a slot is newly activated.
signal slot_activated(index: int)

## slot_deactivated is emitted when a slot was just deactivated.
signal slot_deactivated(index: int)

## slot_erased is emitted when a save slot's data was just erased.
signal slot_erased(index: int)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("res://addons/std/config/config.gd")
const FilePath := preload("res://addons/std/file/path.gd")
const Signals := preload("res://addons/std/event/signal.gd")
const SaveFileWriter := preload("writer.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const CATEGORY_SLOT_DATA := &"__slots__"
const KEY_ACTIVE_SLOT := &"active"

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Saves")

## schema is a config object schema defining the game's save data. This resource will
## *not* be updated itself. Rather, it will be cloned when loading save data.
@export var schema: StdSaveData = null

@export_subgroup("Slots")

## slot_scope is the settings scope containing metadata about the player's save data.
@export var slot_scope: StdSettingsScope = null

## slot_count is the number of save slots supported by the save system.
@export var slot_count: int = 4

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active_slot: int = -1
var _logger := StdLogger.create(&"system/save").with_timestamp()
var _save_data: StdSaveData = null
var _save_slots: Array[SaveSlot] = []

@onready var _writer: SaveFileWriter = get_node(^"SaveFileWriter")

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# Slot operations


## activate_slot sets the specified slot index as active. All subsequent save operations
## will operate against this slot.
func activate_slot(index: int) -> bool:
	var logger := _logger.with({&"slot": index})
	logger.info("Activating save slot.")

	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		logger.warn(
			"Refusing to activate save slot.", {&"error": ERR_INVALID_PARAMETER}
		)
		return false

	if index >= _save_slots.size() or _save_slots[index] == null:
		assert(false, "invalid argument; index out of bounds")
		logger.warn("Refusing to activate save slot.", {&"error": ERR_BUG})
		return false

	# Don't activate an invalid save slot.
	if _save_slots[index].status == SaveSlot.STATUS_BROKEN:
		logger.warn("Refusing to activate save slot.", {&"error": ERR_INVALID_DATA})
		return false

	if _writer.is_worker_in_progress():
		assert(false, "invalid state; cannot change slot while worker is in progress")
		logger.warn("Refusing to change active save slot; worker in progress.")
		return false

	# No change required.
	if index == _active_slot:
		return true

	var slot_previous := _active_slot
	_active_slot = index
	_writer.slot = index
	_save_data = null

	if not slot_scope.config.set_int(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT, index):
		logger.warn("Found stored value for active slot already updated.")

	if slot_previous != -1:
		slot_deactivated.emit(slot_previous)

	# Emit even if persisted value wasn't changed because it's still a change for this
	# system component/application.
	slot_activated.emit(index)

	return true


## clear_active_slot removes the currently active save slot index. Save operations
## cannot be used without an active save slot.
func clear_active_slot() -> bool:
	if _active_slot == -1:
		return false

	var slot := _active_slot

	var logger := _logger.with({&"slot": slot})
	logger.info("Clearing active save slot.")

	if _writer.is_worker_in_progress():
		assert(false, "invalid state; cannot change slot while worker is in progress")
		logger.warn("Refusing to change active save slot; worker in progress.")
		return false

	_active_slot = -1
	_writer.slot = -1
	_save_data = null

	var is_change := slot_scope.config.erase(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT)
	assert(is_change, "invalid state; expected active slot to be updated")

	if is_change:
		slot_deactivated.emit(slot)

	return true


## erase_slot deletes all saved data for the specified index. This is a destructive
## operation, so ensure player has consented to this twice.
func erase_slot(index: int) -> bool:
	var logger := _logger.with({&"slot": index})
	logger.info("Erasing save slot.")

	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		logger.warn(
			"Refusing to activate save slot.", {&"error": ERR_INVALID_PARAMETER}
		)
		return false

	if index >= _save_slots.size() or _save_slots[index] == null:
		assert(false, "invalid argument; index out of bounds")
		logger.warn("Refusing to activate save slot.", {&"error": ERR_BUG})
		return false

	var save_slot := _save_slots[index]
	assert(save_slot is SaveSlot, "invalid state; missing save slot")

	if index == _active_slot:
		if not clear_active_slot():
			assert(false, "failed to clear active slot")
			return false

	logger.debug("Deleting save slot directory.")

	var err := _writer.delete_save_directory(index)
	match err:
		OK:
			save_slot.status = SaveSlot.STATUS_EMPTY
			save_slot.summary.reset()

			slot_erased.emit(index)

			return true
		ERR_FILE_BAD_PATH, ERR_BUSY, _:
			logger.error("Failed to delete directory for save slot.", {&"error": err})
			return false


## get_active_save_slot returns the index of the currently active save slot. If not save
## slot is active, `-1` is returned.
func get_active_save_slot() -> int:
	return _active_slot


## get_save_slot returns metadata about the specified save slot index, including its
## status and a summary of progress, if available.
func get_save_slot(index: int) -> SaveSlot:
	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		return null

	if index >= _save_slots.size():
		assert(false, "invalid state; index out of bounds")
		return null

	var save_slot := _save_slots[index]
	assert(save_slot is SaveSlot, "invalid state; missing save slot")

	return save_slot


# Save operations


## create_new_save_data creates a new, empty instance of the save data resource.
func create_new_save_data() -> StdSaveData:
	var data: StdSaveData = schema.duplicate(true)
	data.reset()
	return data


## get_save_data copies the cached save data for the active save slot into the provided
## resource. The return value denotes whether this operation succeeded; if `false` is
## returned, no cached data was found.
func get_save_data(data: StdSaveData) -> bool:
	if _writer.is_worker_in_progress() or not _save_data is StdSaveData:
		return false

	data.copy(_save_data)
	return true


## load_save_data asynchronously hydrates the provided save data resource with the
## latest data for the active save slot and returns whether this operation succeeded.
func load_save_data(data: StdSaveData) -> bool:
	var index := _active_slot

	var logger := _logger.with({&"slot": index})
	logger.info("Loading save data.")

	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		logger.warn("Refusing to load save data for invalid save slot index.")
		return false

	if index >= _save_slots.size():
		assert(false, "invalid state; index out of bounds")
		logger.warn("Refusing to load save data for invalid save slot index.")
		return false

	# TODO: Determine how and when this constraint can be relaxed. For now, this
	# requires that the caller wait for the result of each save operation.
	if _writer.is_worker_in_progress():
		assert(false, "invalid state; save operation already in progress")
		logger.warn("Refusing to load save data; save operation already in progress.")
		return false

	# If data has already been loaded, return the cached value.
	if _save_data is StdSaveData:
		data.copy(_save_data)
		return true

	var save_slot := _save_slots[index]
	assert(save_slot is SaveSlot, "invalid state; missing save slot")

	_save_data = create_new_save_data()

	save_slot.status = await _writer.load_save_data(_save_data)
	save_slot.summary = _save_data.summary  # Don't duplicate; '_save_data' is private.

	logger = logger.with({&"status": save_slot.status})

	match save_slot.status:
		SaveSlot.STATUS_OK:
			logger.info("Successfully loaded save slot.")
			data.copy(_save_data)

			return true

		SaveSlot.STATUS_EMPTY:
			logger.info("Found save slot is empty.")
			data.copy(_save_data)  # Copy the empty value to "reset" argument.

			return true

		SaveSlot.STATUS_BROKEN, SaveSlot.STATUS_UNKNOWN:
			logger.warn("Failed to load save; slot is broken or corrupted.")
			_save_data = null  # Clear this so that next load can retry.
			save_slot.summary = null

	return false


## store_save_data asynchronously stores the provided save data to the currently active
## save slot and returns whether this operation succeeded.
func store_save_data(data: StdSaveData) -> bool:
	assert(data is StdSaveData, "invalid argument: missing data")

	var index := _active_slot

	var logger := _logger.with({&"slot": index})
	logger.info("Storing save data.")

	if index < 0 or index >= slot_count:
		assert(false, "invalid argument; index out of range")
		logger.warn("Refusing to load save data for invalid save slot index.")
		return false

	if index >= _save_slots.size():
		assert(false, "invalid state; index out of bounds")
		logger.warn("Refusing to load save data for invalid save slot index.")
		return false

	var save_slot := _save_slots[index]
	assert(save_slot is SaveSlot, "invalid state; missing save slot")

	# TODO: Determine how and when this constraint can be relaxed. For now, this
	# requires that the caller wait for the result of each save operation.
	if _writer.is_worker_in_progress():
		assert(false, "invalid state; save operation already in progress")
		logger.warn("Refusing to load save data; save operation already in progress.")
		return false

	_save_data = data.duplicate(true)
	_save_data.summary.time_last_saved = Time.get_unix_time_from_system()

	save_slot.status = await _writer.store_save_data(_save_data)
	save_slot.summary = _save_data.summary  # Don't duplicate; '_save_data' is private.

	logger = logger.with({&"status": save_slot.status})

	match save_slot.status:
		SaveSlot.STATUS_OK:
			logger.info("Successfully saved game.")
			return true

		SaveSlot.STATUS_EMPTY:
			logger.error("Failed to save game; found save slot to be empty.")

		SaveSlot.STATUS_BROKEN, SaveSlot.STATUS_UNKNOWN:
			logger.error(
				"Failed to save game; found save slot to be broken or corrupted."
			)
			_save_data = null  # Clear this so that next load can retry.
			save_slot.summary = null

	return false


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(schema is StdSaveData, "invalid config; missing schema")
	assert(slot_scope is StdSettingsScope, "invalid config; missing settings scope")

	_load_save_slots()

	var last_active_slot := (
		slot_scope
		. config
		. get_int(
			CATEGORY_SLOT_DATA,
			KEY_ACTIVE_SLOT,
			-1,
		)
	)

	if last_active_slot >= _save_slots.size():
		slot_scope.config.erase(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT)

	elif (
		last_active_slot > -1
		and _save_slots[last_active_slot].status == SaveSlot.STATUS_OK
	):
		if not activate_slot(last_active_slot):
			assert(false, "failed to activate slot")
			return

		slot_scope.config.set_int(CATEGORY_SLOT_DATA, KEY_ACTIVE_SLOT, -1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _load_save_slots synchronously loads save data for each slot.
##
## NOTE: This implementation assumes that loading save slots will be fast due to the
## relatively small amout of data stored per slot. This should be revisited for larger
## games.
func _load_save_slots() -> void:
	_save_slots.resize(slot_count)

	for i in slot_count:
		assert(_save_slots[i] == null, "invalid state; found dangling save file")

		var logger := _logger.with({&"slot": i})
		logger.info("Loading save data.")

		_writer.slot = i  # Update slot so '_writer' can use correct path.

		var data := create_new_save_data()

		var save_slot := SaveSlot.new()
		_save_slots[i] = save_slot

		# TODO: Replace this with an asynchronous call to `load_save_data`.
		save_slot.status = _writer.load_save_data_sync(data)
		save_slot.summary = data.summary  # Don't duplicate; 'data' is private.

		logger = logger.with({&"status": save_slot.status})

		match save_slot.status:
			SaveSlot.STATUS_OK:
				# Okay to use directly because 'data' is dropped after here.
				logger.info("Successfully loaded save slot.")

			SaveSlot.STATUS_EMPTY:
				logger.info("Save slot is empty.")

			SaveSlot.STATUS_BROKEN, SaveSlot.STATUS_UNKNOWN:
				logger.warn("Save slot is broken or corrupted.")
				save_slot.summary = null


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_slot_activated(index: int) -> void:
	assert(index > -1 and index < slot_count, "invalid argument: out of range")
	assert(index < _save_slots.size(), "invalid argument: out of range")

	# TODO: Consider starting a load of the save slot's game data. This would require
	# caching the save operation result and allowing callers to "join" the pending work.
