##
## project/ui/animation/slide.gd
##
## AnimationSlide specifies a slide animation that can be used to add motion to canvas
## elements.
##

class_name AnimationSlide
extends AnimationCurve

# -- CONFIGURATION ------------------------------------------------------------------- #

## translation is the motion vector defining the slide animation.
##
## Here, the `x` value represents the primary axis (formed between the anchor's center
## and the tooltip's center), while the `y` value is the perpendicular axis. Values
## along the primary axis should be negative if they move towards the anchor and
## positive if they move away. Perpendicular axis values are applied directly (i.e. they
## aren't changed).
@export var translation: Vector2 = Vector2.ZERO

## use_global_position defines whether the animated node's `global_position` will be
## animated instead of its `position` property.
@export var use_global_position: bool = false

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _apply_tween_property(
	tween: Tween,
	target: CanvasItem,
	value: Vector2,
	parallel: bool,
) -> void:
	if parallel:
		tween.parallel()

	(
		tween
		. tween_property(
			target,
			^"global_position" if use_global_position else ^"position",
			value,
			duration,
		)
		. set_delay(delay)
		. set_ease(ease_type)
		. set_trans(transition_type)
	)
