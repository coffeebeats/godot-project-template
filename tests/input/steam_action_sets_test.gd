##
## tests/input/steam_action_sets_test.gd
##
## Tests that the input system lists every action set the game's Steam Input manifest
## does. The manifest scans the project for sets while the Steam joypad monitor reads
## 'action_sets', so a set left out of the list still reaches Steam, and a controller
## binding only that set's actions looks opted out of Steam Input with no error.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const InputSystem := preload("res://addons/kit/system/input/input.gd")
const SystemScene := preload("res://project/main/system.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

## ADDONS_DIR holds the addons' own sets, which kit's tests cover.
const ADDONS_DIR := "res://addons/"

# -- TEST METHODS -------------------------------------------------------------------- #


func test_action_sets_with_game_sets_in_manifest_list_every_one() -> void:
	# Given: The game's sets and layers, found the way the manifest finds them.
	var game_sets: Array[Resource] = []
	for action_set in StdInputSteamInGameActions.find_resources(&"StdInputActionSet"):
		if not action_set.resource_path.begins_with(ADDONS_DIR):
			game_sets.append(action_set)

	assert_gt(game_sets.size(), 0, "the game defines action sets")

	# When: The input system is read from the 'System' autoload's scene.
	var system: Node = autofree(SystemScene.instantiate())
	var input := system.get_node_or_null(^"Input") as InputSystem

	assert_not_null(input, "'system.tscn' places the input system at 'Input'")
	if not input:
		return

	# Then: Its 'action_sets' list every one of them.
	for action_set in game_sets:
		assert_true(
			action_set in input.action_sets,
			(
				"'action_sets' on 'Input' in 'system.tscn' lists '%s'"
				% action_set.resource_path
			)
		)
