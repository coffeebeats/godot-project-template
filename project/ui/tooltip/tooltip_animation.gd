##
## project/ui/tooltip_animation.gd
##
## TooltipAnimation is a base class for animations to apply during tooltip entry or
## exit.
##

class_name TooltipAnimation
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## animation_delay is the duration of time prior to starting the animation.
@export var animation_delay: float = 0.0

## animation_duration is the duration (in seconds) over which the animation plays.
@export var animation_duration: float = 0.0

## animation_ease is the ease type for the animation.
@export var animation_ease: Tween.EaseType = Tween.EASE_OUT

## animation_ease is the transition type for the animation.
@export var animation_transition: Tween.TransitionType = Tween.TRANS_EXPO

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## apply_tween_property applies the set animation effects to the provided `Tween`.
func apply_tween_property(
	tween: Tween,
	target: CanvasItem,
	value,
	parallel: bool = true,
) -> void:
	return _apply_tween_property(tween, target, value, parallel)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _apply_tween_property should be overridden by child classes to implement the
## animation effect on the provided tween.
func _apply_tween_property(
	_tween: Tween, _target: CanvasItem, _value, _parallel: bool
) -> void:
	assert(false, "unimplemented")
