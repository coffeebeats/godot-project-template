##
## tests/save/save_test_base.gd
##
## Shared base class for save system tests providing reflection-driven data
## population and comparison helpers.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const GOLDEN_SEED := 42

const PROPERTY_USAGE_SERDE := PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE

# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _create_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = GOLDEN_SEED
	return rng


static func _sorted_serde_properties(obj: Object) -> Array:
	var result := []

	for property in obj.get_property_list():
		var usage: int = property[&"usage"]
		if usage & PROPERTY_USAGE_SERDE == PROPERTY_USAGE_SERDE:
			result.append(property)

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"name"]) < str(b[&"name"])
	)

	return result


func _assert_items_equal(
	a: StdConfigItem,
	b: StdConfigItem,
	context: StringName,
) -> void:
	for property in a.get_property_list():
		var usage: int = property[&"usage"]
		if usage & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var property_name: StringName = property[&"name"]
		assert_eq(
			a.get(property_name),
			b.get(property_name),
			"%s.%s" % [context, property_name],
		)


func _assert_schemas_equal(a: StdConfigSchema, b: StdConfigSchema) -> void:
	for property in a.get_property_list():
		var usage: int = property[&"usage"]
		if usage & PROPERTY_USAGE_SERDE != PROPERTY_USAGE_SERDE:
			continue

		var property_name: StringName = property[&"name"]

		var item_a: Variant = a.get(property_name)
		var item_b: Variant = b.get(property_name)

		if not item_a is StdConfigItem:
			continue

		_assert_items_equal(item_a, item_b, property_name)


func _create_save_data() -> ProjectSaveData:
	return Systems.saves().create_new_save_data()


func _get_random_value_for_type(
	type: int,
	rng: RandomNumberGenerator,
) -> Variant:
	match type:
		TYPE_BOOL:
			return true
		TYPE_INT:
			return rng.randi_range(1, 1000)
		TYPE_FLOAT:
			return rng.randf_range(1.0, 1000.0)
		TYPE_STRING:
			return "test_%d" % rng.randi()
		TYPE_VECTOR2:
			var x := rng.randf_range(1.0, 100.0)
			var y := rng.randf_range(1.0, 100.0)
			return Vector2(x, y)
		TYPE_PACKED_INT64_ARRAY:
			return PackedInt64Array([rng.randi_range(1, 1000)])
		TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(["test_%d" % rng.randi()])
		TYPE_PACKED_VECTOR2_ARRAY:
			var x := rng.randf_range(1.0, 100.0)
			var y := rng.randf_range(1.0, 100.0)
			return PackedVector2Array([Vector2(x, y)])
		_:
			fail_test("unsupported type: %d" % type)
			return null


func _populate_item(item: StdConfigItem, rng: RandomNumberGenerator) -> void:
	for property in _sorted_serde_properties(item):
		var value: Variant = _get_random_value_for_type(property[&"type"], rng)
		if value != null:
			item.set(property[&"name"], value)


func _populate_schema(schema: StdConfigSchema, rng: RandomNumberGenerator) -> void:
	for property in _sorted_serde_properties(schema):
		var item: Variant = schema.get(property[&"name"])
		if not item is StdConfigItem:
			continue

		_populate_item(item, rng)
