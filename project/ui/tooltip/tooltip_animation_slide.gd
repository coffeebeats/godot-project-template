##
## project/ui/tooltip_animation_slide.gd
##
## TooltipAnimationSlide specifies a `Tooltip` slide animation that can be used to add
## motion to the incoming or outgoing tooltip node.
##

class_name TooltipAnimationSlide
extends TooltipAnimation

# -- CONFIGURATION ------------------------------------------------------------------- #

## animation_translation is the motion vector defining the slide animation.
##
## Here, the `x` value represents the primary axis (formed between the anchor's center
## and the tooltip's center), while the `y` value is the perpendicular axis. Values
## along the primary axis should be negative if they move towards the anchor and
## positive if they move away. Perpendicular axis values are applied directly (i.e. they
## aren't changed).
@export var animation_translation: Vector2 = Vector2.ZERO

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
			^"global_position",
			value,
			animation_duration,
		)
		. set_ease(animation_ease)
		. set_trans(animation_transition)
	)
