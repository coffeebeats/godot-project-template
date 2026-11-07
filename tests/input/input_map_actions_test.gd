##
## tests/input/input_map_actions_test.gd
##
## Tests that the project's input map declares every action a set or layer names, kit's
## sets included, since 'project.godot' and the sets are kept in step by hand and an
## undeclared action binds nothing.
##

extends GutTest

# -- TEST METHODS -------------------------------------------------------------------- #


func test_action_sets_in_project_name_only_declared_actions() -> void:
	# Given: Every set and layer, kit's included, found the way the manifest finds them.
	var action_sets := StdInputSteamInGameActions.find_resources(&"StdInputActionSet")

	# Then: The project has sets to check.
	assert_gt(action_sets.size(), 0, "the project defines action sets")

	# Then: The input map declares every digital and 1D analog action they name.
	# NOTE: A 2D analog action names a stick rather than an input map action, and its
	# four directions are listed in 'actions_digital'.
	for action_set: StdInputActionSet in action_sets:
		for action in action_set.actions_digital + action_set.actions_analog_1d:
			assert_true(
				InputMap.has_action(action),
				(
					"'[input]' in 'project.godot' declares '%s', which '%s' names"
					% [action, action_set.resource_path]
				)
			)
