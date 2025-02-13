##
## project/ui/animation/fade.gd
##
## AnimationBorderFade specifies a fade animation that can be applied to `StyleboxFlat`
## resources. Note that this resource can be used for both fade in or fade out
## animations.
##

class_name AnimationBorderFade
extends AnimationCurve

# -- CONFIGURATION ------------------------------------------------------------------- #

## color is the target color for the animation.
@export var color: Color = Color.TRANSPARENT

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _apply_tween_property(
	tween: Tween,
	target: StyleBoxFlat,
	value: Color,
	parallel: bool,
) -> void:
	if parallel:
		tween.parallel()

	(
		tween
		. tween_property(target, ^"border_color", value, duration)
		. set_delay(delay)
		. set_ease(ease_type)
		. set_trans(transition_type)
	)
