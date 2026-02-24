##
## tests/save/save_e2e_test.gd
##
## End-to-end tests for save infrastructure through the public save system API.
##

extends "save_test_base.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SaveFileWriter := preload("res://system/save/writer.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _temp_dir: String = ""

# -- TEST METHODS -------------------------------------------------------------------- #


func test_store_and_load_round_trip_slot_0() -> void:
	# Given: A schema populated with non-default data.
	var saves := Systems.saves()
	var data := _create_save_data()
	data.example.count = 1
	saves.activate_slot(0)

	# Given: Data is initially written to the save file.
	var stored := await saves.store_save_data(data)
	assert_true(stored, "store")

	# Given: The in-memory data cache is cleared.
	saves.clear_save_data_cache()

	# When: Data is loaded back again.
	var loaded := _create_save_data()
	var did_load := await saves.load_save_data(loaded)

	# Then: Loaded data matches stored data.
	assert_true(did_load, "load")
	assert_eq(loaded.example.count, 1)


func test_store_and_load_round_trip_slot_max() -> void:
	# Given: A schema populated with non-default data.
	var saves := Systems.saves()
	var max_slot := saves.slot_count - 1
	var data := _create_save_data()
	data.example.count = 2
	saves.activate_slot(max_slot)

	# Given: Data is initially written to the save file.
	var stored := await saves.store_save_data(data)
	assert_true(stored, "store")

	# Given: The in-memory data cache is cleared.
	saves.clear_save_data_cache()

	# When: Data is loaded back again.
	var loaded := _create_save_data()
	var did_load := await saves.load_save_data(loaded)

	# Then: Loaded data matches stored data.
	assert_true(did_load, "load")
	assert_eq(loaded.example.count, 2)


func test_load_empty_slot_returns_empty() -> void:
	# Given: An unused save slot.
	var saves := Systems.saves()
	saves.activate_slot(2)

	# When: Data is loaded from the empty slot.
	var data := _create_save_data()
	var did_load := await saves.load_save_data(data)

	# Then: The load succeeds and the slot status is empty.
	assert_true(did_load)
	var slot := saves.get_save_slot(2)
	assert_eq(slot.status, SaveSlot.STATUS_EMPTY)


func test_slot_isolation() -> void:
	# Given: A schema populated with non-default data.
	var saves := Systems.saves()
	var data := _create_save_data()
	data.example.count = 10
	saves.activate_slot(0)

	# Given: Data is stored in slot 0.
	var stored := await saves.store_save_data(data)
	assert_true(stored, "store")

	# When: A different slot is activated and loaded.
	saves.clear_active_slot()
	saves.activate_slot(1)

	var loaded := _create_save_data()
	var did_load := await saves.load_save_data(loaded)

	# Then: The other slot is empty.
	assert_true(did_load)
	var slot := saves.get_save_slot(1)
	assert_eq(slot.status, SaveSlot.STATUS_EMPTY)


func test_overwrite_returns_latest_data() -> void:
	# Given: A schema populated with non-default data.
	var saves := Systems.saves()
	saves.activate_slot(0)
	var data := _create_save_data()
	data.example.count = 1

	# Given: Data is initially written to the save file.
	var s1 := await saves.store_save_data(data)
	assert_true(s1, "store 1")

	# When: Data is overwritten with a new value and loaded back.
	data.example.count = 2
	var s2 := await saves.store_save_data(data)
	assert_true(s2, "store 2")

	saves.clear_save_data_cache()

	var loaded := _create_save_data()
	var did_load := await saves.load_save_data(loaded)

	# Then: The latest value is returned.
	assert_true(did_load, "load")
	assert_eq(loaded.example.count, 2)


func test_erase_slot_then_load_returns_empty() -> void:
	# Given: A schema populated with non-default data.
	var saves := Systems.saves()
	saves.activate_slot(0)
	var data := _create_save_data()
	data.example.count = 99

	# Given: Data is initially written to the save file.
	var stored := await saves.store_save_data(data)
	assert_true(stored, "store")

	# When: The save slot is erased and then re-activated and loaded.
	saves.clear_active_slot()
	var erased := saves.erase_slot(0)
	assert_true(erased, "erase")

	saves.activate_slot(0)

	var loaded := _create_save_data()
	var did_load := await saves.load_save_data(loaded)

	# Then: The slot is empty.
	assert_true(did_load)
	var slot := saves.get_save_slot(0)
	assert_eq(slot.status, SaveSlot.STATUS_EMPTY)


func test_non_default_values_persisted() -> void:
	# Given: A schema with all fields set to non-default values.
	var saves := Systems.saves()
	saves.activate_slot(0)
	var data := _create_save_data()
	var rng := _create_rng()
	_populate_schema(data, rng)

	# Given: Data is initially written to the save file.
	var stored := await saves.store_save_data(data)
	assert_true(stored, "store")

	# Given: The expected data is synced with the stored timestamp.
	data.summary.time_last_saved = (saves.get_save_slot(0).summary.time_last_saved)

	# Given: The in-memory data cache is cleared.
	saves.clear_save_data_cache()

	# When: Data is loaded back again.
	var loaded := _create_save_data()
	var did_load := await saves.load_save_data(loaded)
	assert_true(did_load, "load")

	# Then: All fields match the stored values.
	_assert_schemas_equal(data, loaded)


func test_negative_slot_asserts() -> void:
	# Given/When: activate_slot is called with a negative index.
	Systems.saves().activate_slot(-1)

	# Then: An engine error about the invalid argument is generated.
	assert_engine_error("invalid argument")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	SaveFileWriter._save_root_override = ""
	if DirAccess.dir_exists_absolute(_temp_dir):
		OS.move_to_trash(_temp_dir)


func after_each() -> void:
	var saves := Systems.saves()
	saves.clear_active_slot()

	for i in saves.slot_count:
		saves.erase_slot(i)


func before_all() -> void:
	var saves := Systems.saves()
	if not saves.are_slots_loaded():
		await saves.slots_loaded

	_temp_dir = OS.get_cache_dir().path_join("gut_saves_%d" % randi())
	DirAccess.make_dir_recursive_absolute(_temp_dir)
	SaveFileWriter._save_root_override = _temp_dir
