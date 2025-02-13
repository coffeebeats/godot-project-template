##
## project/ui/animation/curve.gd
##
## AnimationCurve is a base class for describing animation curves that can be applied
## via `Tween` objects.
##

class_name AnimationCurve
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## delay is the duration of time prior to starting the animation.
@export var delay: float = 0.0

## duration is the duration (in seconds) over which the animation plays.
@export var duration: float = 0.0

## ease_type is the ease type for the animation.
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

## transition_type is the transition type for the animation.
@export var transition_type: Tween.TransitionType = Tween.TRANS_EXPO

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## apply_tween_property applies the set animation effects to the provided `Tween`.
##
## FIXME: There's a conflict between defining animations as resources and allowing the
## caller to specify the target value. Reconcile this by, for example, removing the
## `value` argument.
func apply_tween_property(
	tween: Tween,
	target: Object,
	value,
	parallel: bool = true,
) -> void:
	return _apply_tween_property(tween, target, value, parallel)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _apply_tween_property should be overridden by child classes to implement the
## animation effect on the provided tween.
func _apply_tween_property(_tween: Tween, _target, _value, _parallel: bool) -> void:
	assert(false, "unimplemented")
