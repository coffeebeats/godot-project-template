##
## project/main/load/loading.gd
##
## Loading implements a loading screen scene. It emits a signal when loading completes
## with the result.
##

extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## finished is emitted when loading finishes.
signal finished(success: bool, data)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	await _load_save_data()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _load_save_data() -> void:
	var saves := Systems.saves()
	var data := saves.create_new_save_data()

	if not await saves.load_save_data(data):
		finished.emit(false, null)
		return

	# TODO: Add behavior to load the necessary resources and set game system state.

	finished.emit(true, data)
