##
## tests/locale/translations_test.gd
##
## Tests that the project registers kit's translation catalogue. Godot reads only the
## catalogues listed in 'locale/translations', so a language kit adds that the list
## leaves out shows kit's strings as raw 'kit_*' keys, in that language only, with no
## error.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #

const GAME_LOCALE_DIR := "res://project/locale"
const KIT_LOCALE_DIR := "res://addons/kit/locale"

# -- TEST METHODS -------------------------------------------------------------------- #


func test_translations_list_every_kit_catalogue() -> void:
	# Given: The catalogues kit ships.
	var catalogues := _find_catalogues(KIT_LOCALE_DIR)
	assert_gt(catalogues.size(), 0, "kit ships catalogues")

	# When: The project's registered translations are read.
	var listed := _get_listed_catalogues()

	# Then: Every kit catalogue is registered.
	for path in catalogues:
		assert_has(listed, path, "'locale/translations' lists kit's catalogue")


func test_translations_list_the_game_catalogues_before_kit() -> void:
	# Given: The project's registered translations.
	var listed := _get_listed_catalogues()

	# When: The game's and kit's catalogues are located in the list.
	var last_game := -1
	var first_kit := listed.size()

	for index in listed.size():
		if listed[index].begins_with(GAME_LOCALE_DIR):
			last_game = maxi(last_game, index)
		elif listed[index].begins_with(KIT_LOCALE_DIR):
			first_kit = mini(first_kit, index)

	# Then: The game's come first, so its strings override kit's.
	assert_lt(last_game, first_kit, "the game's catalogues are listed before kit's")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _find_catalogues(directory: String) -> PackedStringArray:
	var out := PackedStringArray()

	for file in DirAccess.get_files_at(directory):
		if file.get_extension() == "mo":
			out.append(directory.path_join(file))

	return out


func _get_listed_catalogues() -> PackedStringArray:
	return ProjectSettings.get_setting(
		"internationalization/locale/translations", PackedStringArray()
	)
