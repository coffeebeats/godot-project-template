##
## Splash is a splash screen Runner state implementation.
##

extends "../../../addons/std/scene/runner/state.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

const RunnerState := preload("../../../addons/std/scene/runner/state.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## duration is the amount of time the screen will be displayed before transitioning.
@export_range(0.0, 3.0) var duration: float = 1.5

## target is the next state to transition to after the specified duration elapses.
@export var target: NodePath

# -- INITIALIZATION ------------------------------------------------------------------ #

var _elapsed: float = 0.0

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

## A virtual method called when this state is entered (after exiting previous state).
##
## NOTE: This method *can* be overridden to customize behavior for the 'State' node.
##
## NOTE: If this 'State' is a derived 'State' node, then this 'enter' method is
## called *after* to the parent 'State' node's 'enter' method.
##
## @args:
## 	previous - the 'State' node being transitioned *from*
func _on_enter(_previous: State) -> void:
    _elapsed = 0.0

## A virtual method called to process a frame/tick, given the frame time 'delta'.
##
## NOTE: This method *can* be overridden to customize behavior for the 'State' node.
##
## NOTE: This method should either return 'null', meaning the frame/tick has been
## handled, or a reference to a parent 'State'. Returning a reference delegates
## handling of the frame/tick from the current 'State' to the parent 'State'. If
## there is no parent 'State' (i.e. this is a "top" 'State' node) then processing
## stops.
##
## @args:
##  delta - the elapsed time since the last update
func _on_update(delta: float) -> State:
    _elapsed += delta
    if _elapsed > duration:
        return _transition_to(NodePath("%s/%s" % [_path, target]))

    return _parent

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
