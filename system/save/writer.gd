##
## system/save/writer.gd
##
## SystemSaveWriter is a node for reading/writing save data for the configured save
## slot. File system operations occur in a background thread, so both sync and async
## APIs are provided.
##

extends StdSaveFile

# -- CONFIGURATION ------------------------------------------------------------------- #

## slot is the save slot which will be used to determine the save file's path. This must
## not be updated while a save operation is in progress.
@export var slot: int = 0:
	get = _get_slot,
	set = _set_slot

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_save_directory returns the directory containing save data for the specified save
## slot index. This does not guarantee that the directory exists or the slot is valid.
static func get_save_directory(index: int) -> String:
	if index < 0:
		assert(false, "invalid argument; slot index out of range")
		return ""

	var profile := Platform.get_user_profile()
	if not profile:
		assert(false, "invalid state; missing profile")
		return ""

	return "user://profiles/%s/saves/%d" % [profile.id, index]


@warning_ignore("SHADOWED_VARIABLE")


## delete_save_directory erases the save data for the specified slot. This is a
## destructive operation.
func delete_save_directory(slot: int) -> Error:
	var directory := get_save_directory(slot)
	if not directory:
		return ERR_FILE_BAD_PATH

	_worker_mutex.lock()

	if is_worker_in_progress():
		_worker_mutex.unlock()
		assert(false, "invalid state; cannot delete while worker in progress")
		return ERR_BUSY

	var path_absolute := FilePath.make_project_path_absolute(directory)
	if not DirAccess.dir_exists_absolute(path_absolute):
		_worker_mutex.unlock()
		(
			_logger
			. warn(
				"Tried to delete non-existent save directory.",
				{&"directory": directory},
			)
		)
		return OK

	var err := DirAccess.remove_absolute(path_absolute)
	_worker_mutex.unlock()

	if err != OK:
		assert(false, "failed to delete save directory")
		return err

	return OK


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_save_directory() -> String:
	_worker_mutex.lock()
	var index := slot
	_worker_mutex.unlock()

	return get_save_directory(index)


# -- SETTERS/GETTERS ----------------------------------------------------------------- #


func _get_slot() -> int:
	_worker_mutex.lock()
	var value := slot
	_worker_mutex.unlock()

	return value


func _set_slot(value: int) -> void:
	_worker_mutex.lock()

	if is_worker_in_progress():
		assert(false, "invalid state; worker in progress")
		_worker_mutex.unlock()
		return

	slot = value
	_worker_mutex.unlock()
