##
## error.gd
##
## A canonical error descriptor for both pending errors (enqueued before the UI exists)
## and runtime errors (passed to `Main.show_error()`).
##

class_name ProjectError
extends RefCounted

# -- DEFINITIONS --------------------------------------------------------------------- #

## Severity is a visual classification (icon, color, sound). Reserved for future use;
## does not drive dialog buttons.
enum Severity { WARNING, ERROR, CRITICAL }

## Action drives dialog buttons; one button per action, ordered left-to-right.
enum Action { RETRY, CONTINUE, RETURN_TO_MENU, QUIT }

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _pending: Array[ProjectError] = []

var actions: Array[Action]
var message: String
var severity: Severity
var title: String

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## enqueue appends an error to the pending queue for later display.
static func enqueue(error: ProjectError) -> void:
	_pending.append(error)


## drain_pending returns all pending errors and clears the queue.
static func drain_pending() -> Array[ProjectError]:
	var errors := _pending
	_pending = []
	return errors


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(
	p_title: String,
	p_message: String,
	p_severity: Severity,
	p_actions: Array[Action],
) -> void:
	title = p_title
	message = p_message
	severity = p_severity
	actions = p_actions
