##
## tests/config/schema/schema_test.gd
##
## Unit tests for StdConfigSchema dirty delegation.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("res://addons/std/config/config.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_schema_is_not_dirty_after_load() -> void:
	# Given: A schema with data stored in a Config.
	var schema := ProjectSaveData.new()
	schema.example.count = 5
	var config := Config.new()
	schema.store(config)

	# When: A fresh schema loads from that config.
	var loaded := ProjectSaveData.new()
	loaded.load(config)

	# Then: The loaded schema is not dirty.
	assert_false(loaded.is_dirty())


func test_schema_is_dirty_when_item_mutated() -> void:
	# Given: A freshly reset schema.
	var schema := ProjectSaveData.new()
	schema.reset()

	# When: An item property is mutated.
	schema.example.count = 42

	# Then: The schema reports dirty.
	assert_true(schema.is_dirty())


func test_schema_clear_dirty_resets_all_items() -> void:
	# Given: A schema with a mutated item.
	var schema := ProjectSaveData.new()
	schema.reset()
	schema.example.count = 42
	assert_true(schema.is_dirty())

	# When: clear_dirty is called on the schema.
	schema.clear_dirty()

	# Then: The schema is no longer dirty.
	assert_false(schema.is_dirty())


func test_schema_mark_critical_makes_dirty() -> void:
	# Given: A freshly reset schema.
	var schema := ProjectSaveData.new()
	schema.reset()
	assert_false(schema.is_dirty())

	# When: The schema is marked critical.
	schema.mark_critical()

	# Then: The schema reports dirty.
	assert_true(schema.is_dirty())
	assert_true(schema.is_critical())


func test_schema_is_not_dirty_after_reset() -> void:
	# Given: A schema that has been mutated and marked critical.
	var schema := ProjectSaveData.new()
	schema.example.count = 99
	schema.mark_critical()

	# When: The schema is reset.
	schema.reset()

	# Then: The schema is not dirty.
	assert_false(schema.is_dirty())
	assert_false(schema.is_critical())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
