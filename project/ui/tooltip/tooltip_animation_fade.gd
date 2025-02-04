##
## project/ui/tooltip_animation_fade.gd
##
## TooltipAnimationFade specifies a `Tooltip` fade animation that can be applied to the
## incoming or outgoing tooltip node. Note that this resource can be used for both fade
## in or fade out animations.
##

class_name TooltipAnimationFade
extends TooltipAnimation

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _apply_tween_property(
	tween: Tween,
	target: CanvasItem,
	value: float,
	parallel: bool,
) -> void:
	if parallel:
		tween.parallel()

	(
		tween
		. tween_property(target, ^"modulate:a", value, animation_duration)
		. set_delay(animation_delay)
		. set_ease(animation_ease)
		. set_trans(animation_transition)
	)
