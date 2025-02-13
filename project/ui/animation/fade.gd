##
## project/ui/animation/fade.gd
##
## AnimationFade specifies a fade animation that can be applied to canvas elements. Note
## that this resource can be used for both fade in or fade out animations.
##

class_name AnimationFade
extends AnimationCurve

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
		.tween_property(target, ^"modulate:a", value, duration)
		.set_delay(delay)
		.set_ease(ease_type)
		.set_trans(transition_type)
	)
