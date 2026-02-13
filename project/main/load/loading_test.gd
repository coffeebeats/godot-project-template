##
## project/main/load/loading_test.gd
##
## Tests pertaining to the loading screen.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Loading := preload("res://project/main/load/loading.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _loading: Control = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_emits_finished_true_on_success() -> void:
	# Given: A loading screen with watched signals.
	watch_signals(_loading)

	# When: The finished signal is emitted with success and data.
	var data := {"key": "value"}
	_loading.finished.emit(true, data)

	# Then: The signal is emitted with the correct parameters.
	assert_signal_emitted(_loading, "finished")
	assert_signal_emitted_with_parameters(_loading, "finished", [true, data])


func test_emits_finished_false_on_failure() -> void:
	# Given: A loading screen with watched signals.
	watch_signals(_loading)

	# When: The finished signal is emitted with failure and no data.
	_loading.finished.emit(false, null)

	# Then: The signal is emitted with the correct parameters.
	assert_signal_emitted(_loading, "finished")
	assert_signal_emitted_with_parameters(_loading, "finished", [false, null])


func test_signal_has_correct_parameters() -> void:
	# Given: A loading screen with watched signals.
	assert_has_signal(_loading, "finished")
	watch_signals(_loading)

	# When: The finished signal is emitted with expected parameter types.
	var data := {"key": "value"}
	_loading.finished.emit(true, data)

	# Then: The signal is emitted with the correct parameters.
	assert_signal_emitted(_loading, "finished")
	assert_signal_emitted_with_parameters(_loading, "finished", [true, data])


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_loading = partial_double(Loading).new()
	stub(_loading, "_ready").to_do_nothing()
	add_child_autofree(_loading)
