##
## tests/config/schema/item_test.gd
##
## Unit tests for StdConfigItem snapshot dirty tracking.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("res://addons/std/config/config.gd")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_item_is_not_dirty_after_load() -> void:
	# Given: A config item with data stored in a Config.
	var item := ProjectExampleData.new()
	item.count = 5
	var config := Config.new()
	item.store(config)

	# When: A fresh item loads from that config.
	var loaded := ProjectExampleData.new()
	loaded.load(config)

	# Then: The loaded item is not dirty.
	assert_false(loaded.is_dirty())


func test_item_is_dirty_after_mutation() -> void:
	# Given: A freshly reset config item.
	var item := ProjectExampleData.new()
	item.reset()

	# When: A property is mutated.
	item.count = 42

	# Then: The item is dirty.
	assert_true(item.is_dirty())


func test_item_clear_dirty_resets_after_mutation() -> void:
	# Given: A config item that has been mutated.
	var item := ProjectExampleData.new()
	item.reset()
	item.count = 42
	assert_true(item.is_dirty())

	# When: clear_dirty is called.
	item.clear_dirty()

	# Then: The item is no longer dirty.
	assert_false(item.is_dirty())


func test_item_is_not_dirty_after_reset() -> void:
	# Given: A config item that has been mutated.
	var item := ProjectExampleData.new()
	item.count = 99

	# When: The item is reset.
	item.reset()

	# Then: The item is not dirty.
	assert_false(item.is_dirty())


func test_item_is_not_dirty_after_copy() -> void:
	# Given: Two config items, one with non-default data.
	var source := ProjectExampleData.new()
	source.count = 7
	var target := ProjectExampleData.new()

	# When: The target copies from the source.
	target.copy(source)

	# Then: The target is not dirty.
	assert_false(target.is_dirty())


func test_item_set_same_value_not_dirty() -> void:
	# Given: A config item with a known value.
	var item := ProjectExampleData.new()
	item.reset()
	var original_count := item.count

	# When: The same value is re-assigned.
	item.count = original_count

	# Then: The item is not dirty.
	assert_false(item.is_dirty())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)
