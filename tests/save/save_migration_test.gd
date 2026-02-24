##
## tests/save/save_migration_test.gd
##
## Schema-property-based migration tests that validate migrations are correct and
## complete by comparing structural snapshots of each schema version.
##

extends "save_test_base.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("res://addons/std/config/config.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GOLDEN_DIR := "res://tests/testdata/golden/saves"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _current_properties: Dictionary = {}
var _current_version: int = 0
var _schema: ProjectSaveData = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_schema_properties_match_committed() -> void:
	# Given: The committed schema properties for the current version.
	var committed := _load_schema_properties(_current_version)

	# When: The current schema is introspected.
	var actual := _current_properties

	# Then: The introspected properties match the committed file.
	assert_eq(
		actual,
		committed,
		"schema changed without version bump",
	)


func test_migrated_data_has_no_orphaned_keys() -> void:
	if _current_version == 0:
		pass_test("no past versions to migrate")
		return

	for v in range(_current_version):
		# Given: A config populated with v<N> schema properties.
		var old_props := _load_schema_properties(v)
		var config := _generate_config(old_props, v)

		# When: Migrations are applied to bring it to the current version.
		_apply_migrations(config, v)

		# Then: Every category and key in the migrated config has the correct type.
		for category_sn in config._data.keys():
			var category := str(category_sn)
			if category == "__meta__":
				continue

			assert_true(
				category in _current_properties,
				"v%d: orphaned category '%s'" % [v, category],
			)

			if category not in _current_properties:
				continue

			var expected: Dictionary = _current_properties[category]
			var cat_data: Dictionary = config._data[category_sn]

			for key_sn in cat_data.keys():
				var key := str(key_sn)

				assert_true(
					key in expected,
					"v%d: orphaned key '%s.%s'" % [v, category, key],
				)

				if key not in expected:
					continue

				var value: Variant = cat_data[key_sn]
				var expected_type: int = expected[key]

				assert_eq(
					typeof(value),
					expected_type,
					"v%d: type mismatch '%s.%s'" % [v, category, key],
				)


func test_migrated_data_preserves_shared_values() -> void:
	if _current_version == 0:
		pass_test("no past versions to migrate")
		return

	for v in range(_current_version):
		# Given: A config populated with v<N> schema properties.
		var old_props := _load_schema_properties(v)
		var config := _generate_config(old_props, v)

		# Given: The pre-migration values of keys shared with the current schema.
		var shared := {}
		for category in old_props.keys():
			if category not in _current_properties:
				continue

			for key in old_props[category].keys():
				var cur_keys: Dictionary = _current_properties[category]
				if key not in cur_keys:
					continue

				var old_type: int = old_props[category][key]
				var cur_type: int = cur_keys[key]
				if old_type != cur_type:
					continue

				if category not in shared:
					shared[category] = {}

				shared[category][key] = (
					config
					. get_variant(
						StringName(category),
						StringName(key),
						null,
					)
				)

		# When: Migrations are applied to bring it to the current version.
		_apply_migrations(config, v)

		# Then: Every shared key retains its pre-migration value.
		for category in shared.keys():
			for key in shared[category].keys():
				var expected: Variant = shared[category][key]
				var actual: Variant = (
					config
					. get_variant(
						StringName(category),
						StringName(key),
						null,
					)
				)

				assert_eq(
					actual,
					expected,
					"v%d: shared key '%s.%s' changed" % [v, category, key],
				)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	_schema = Systems.saves().create_new_save_data()
	assert_not_null(_schema, "loaded save data schema")

	_current_version = _schema.version
	_current_properties = _get_schema_properties(_schema)
	_ensure_schema_properties_exist(_current_version)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_schema_properties(schema: StdConfigSchema) -> Dictionary:
	var unsorted := {}

	for property in _sorted_serde_properties(schema):
		var item: Variant = schema.get(property[&"name"])
		if not item is StdConfigItem:
			continue

		var category := str(item.get_category())
		var keys := {}

		for item_prop in _sorted_serde_properties(item):
			keys[str(item_prop[&"name"])] = int(item_prop[&"type"])

		unsorted[category] = keys

	# Sort categories and keys for deterministic JSON output.
	var result := {}
	var categories := unsorted.keys()
	categories.sort()

	for category in categories:
		result[category] = {}
		var keys: Array = unsorted[category].keys()
		keys.sort()
		for key in keys:
			result[category][key] = unsorted[category][key]

	return result


func _apply_migrations(config: Config, from_version: int) -> void:
	var sorted := _schema.migrations.duplicate()
	sorted.sort_custom(
		func(
			a: StdConfigSchemaMigration,
			b: StdConfigSchemaMigration,
		) -> bool:
			return a.version_from < b.version_from
	)

	for migration in sorted:
		if (
			migration.version_from >= from_version
			and migration.version_from < _current_version
		):
			migration._migrate(config)


func _ensure_schema_properties_exist(version: int) -> void:
	var path := _get_schema_properties_path(version)
	if FileAccess.file_exists(path):
		return

	var generate := OS.get_environment("TEST_GENERATE_GOLDENS")
	if generate.to_lower() not in ["1", "true", "yes"]:
		fail_test(
			(
				"missing schema properties v%d.json;" % version
				+ " set TEST_GENERATE_GOLDENS=1 to generate"
			)
		)
		return

	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var json := JSON.stringify(_current_properties, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		assert_not_null(file, "create v%d.json" % version)
		return

	file.store_string(json)
	file.close()

	gut.p("Generated schema properties: v%d.json" % version)


func _generate_config(properties: Dictionary, version: int) -> Config:
	var config := Config.new()
	config.set_int(&"__meta__", &"version", version)

	var rng := _create_rng()

	# Iterate in sorted order for deterministic RNG.
	var categories := properties.keys()
	categories.sort()

	for category in categories:
		var keys: Array = properties[category].keys()
		keys.sort()

		for key in keys:
			var type: int = properties[category][key]
			var value: Variant = _get_random_value_for_type(type, rng)
			if value != null:
				(
					config
					. _set_variant(
						StringName(category),
						StringName(key),
						value,
					)
				)

	return config


func _get_schema_properties_path(version: int) -> String:
	var rel := GOLDEN_DIR.path_join("v%d.json" % version)
	return ProjectSettings.globalize_path(rel)


func _load_schema_properties(version: int) -> Dictionary:
	var path := _get_schema_properties_path(version)
	assert_true(
		FileAccess.file_exists(path),
		"schema properties v%d.json exists" % version,
	)

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		assert_eq(err, OK, "parse v%d.json" % version)
		return {}

	# Convert loaded data to match introspected types.
	var result := {}
	for category in json.data.keys():
		result[str(category)] = {}
		for key in json.data[category].keys():
			result[str(category)][str(key)] = (int(json.data[category][key]))

	return result
