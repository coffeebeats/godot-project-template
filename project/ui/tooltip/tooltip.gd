##
## project/ui/tooltip.gd
##
## Tooltip is a base class which renders its child node in a popover, anchored to a
## specified canvas item. It responds to hover and focus effects on configurable nodes
## (which can be different than the anchor).
##
## This implementation is opinionated in that it always displays the tooltip contents
## adjacent to one of the faces of the anchor node. Additionally, the anchor node cannot
## be rotated and the anchor cannot be moved while the tooltip is animating.
##
## NOTE: It extends `CenterContainer` because it's the easiest way to ensure that,
## regardless of tooltip contents, the `Tooltip` node itself will have a bounding box
## which is equal to its child's.
##

class_name Tooltip
extends CenterContainer

# -- SIGNALS ------------------------------------------------------------------------- #

## tooltip_opened is emitted when the tooltip is first triggered to be shown. If
## animations are required, this will be triggered as they begin.
signal tooltip_opened

## tooltip_closed is emitted when the tooltip is first triggered to be hidden. If
## animations are required, this will be triggered as they begin.
signal tooltip_closed

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## TooltipPosition defines one of the four faces of the anchor node's bounding box to
## which the tooltip can be anchored.
enum TooltipPosition {
	ABOVE = 0,
	RIGHT = 1,
	BELOW = 2,
	LEFT = 3,
}

const TOOLTIP_POSITION_ABOVE := TooltipPosition.ABOVE
const TOOLTIP_POSITION_BELOW := TooltipPosition.BELOW
const TOOLTIP_POSITION_LEFT := TooltipPosition.LEFT
const TOOLTIP_POSITION_RIGHT := TooltipPosition.RIGHT

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Display")

@export_subgroup("Positioning")

## tooltip_position is the target side of the anchor node at which to display the
## tooltip.
@export var tooltip_position: TooltipPosition = TooltipPosition.ABOVE

## tooltip_offset is a positional offset from the anchor when the tooltip is shown.
@export var tooltip_offset: Vector2 = Vector2.ZERO

@export_subgroup("Visibility")

## focus_target is an alternative `Control` node which, when it grabs focus, will reveal
## the tooltip. Ignored if `show_when_focused` is set to `false`.
##
## NOTE: If set, the `anchor` node will *not* be listened to for hover events.
@export var focus_target: Control = null

## hover_target is an alternative `CanvasItem` node which, when hovered, will reveal the
## tooltip. Ignored if `show_when_hovered` is set to `false`.
##
## NOTE: If set, the `anchor` node will *not* be listened to for hover events.
@export var hover_target: CanvasItem = null

## show_when_focused controls whether the tooltip will be revealed by focusing the
## anchor node (or `focus_target` if set).
@export var show_when_focused: bool = true

## show_when_hovered controls whether the tooltip will be revealed by hovering over the
## anchor node (or `hover_target` if set).
@export var show_when_hovered: bool = true

@export_group("Animation")

@export_subgroup("Fade")

## fade_out is an incoming fade animation to apply to the tooltip.
@export var fade_in: TooltipAnimationFade = null

## fade_out is an outgoing fade animation to apply to the tooltip.
@export var fade_out: TooltipAnimationFade = null

@export_subgroup("Slide")

## slide_in is an incoming slide animation to apply to the tooltip.
@export var slide_in: TooltipAnimationSlide = null

## slide_out is an outgoing slide animation to apply to the tooltip.
@export var slide_out: TooltipAnimationSlide = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_focused: bool = false
var _is_hovered: bool = false
var _is_visible: bool = false
var _tween: Tween = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## hide_tooltip hides the tooltip after animating its outgoing effects.
##
## NOTE: This method should be preferred over `hide`, which will immediately toggle
## visibility - ignoring animations.
func hide_tooltip() -> void:
	if not _is_visible:
		return

	_reset_animation()
	_is_visible = false

	_hide_tooltip()

	tooltip_closed.emit()


## show_tooltip reveals the tooltip after animating its incoming effects.
##
## NOTE: This method should be preferred over `show`, which will immediately toggle
## visibility - ignoring animations.
func show_tooltip() -> void:
	if _is_visible:
		return

	_reset_animation()
	_is_visible = true

	_reposition()
	_show_tooltip()

	tooltip_opened.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	visible = false
	top_level = true

	var anchor := _get_target_canvas_item()
	assert(anchor is CanvasItem, "invalid state; missing node")
	assert(anchor.is_inside_tree(), "invalid state; node must be in scene tree")

	Signals.connect_safe(anchor.item_rect_changed, _on_anchor_rect_changed)

	if show_when_hovered:
		var hover_node := hover_target if hover_target else anchor
		assert(
			hover_node.mouse_filter != MOUSE_FILTER_IGNORE,
			"invalid config; hover target cannot ignore mouse",
		)

		Signals.connect_safe(hover_node.mouse_entered, _on_hover_target_mouse_entered)
		Signals.connect_safe(hover_node.mouse_exited, _on_hover_target_mouse_exited)

	if show_when_focused:
		var focus_node := focus_target if focus_target else anchor
		Signals.connect_safe(focus_node.focus_entered, _on_focus_target_focus_entered)
		Signals.connect_safe(focus_node.focus_exited, _on_focus_target_focus_exited)

	_update()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _get_target_canvas_item should be overridden to return a reference to the anchor
## node. Note that it must be a canvas item (i.e. `Node2D` or `Control`).
func _get_target_canvas_item() -> CanvasItem:
	assert(false, "unimplemented")
	return null


## _get_target_global_rect returns the global bounding box for the node to which
## this tooltip should be attached.
func _get_target_global_rect() -> Rect2:
	assert(false, "unimplemented")
	return Rect2()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_slide_offset(animation: TooltipAnimationSlide) -> Vector2:
	if not animation:
		return Vector2.ZERO

	var animation_offset: Vector2
	var motion := animation.animation_translation

	match tooltip_position:
		TOOLTIP_POSITION_ABOVE:
			animation_offset = Vector2(motion.y, -motion.x)
		TOOLTIP_POSITION_BELOW:
			animation_offset = Vector2(motion.y, motion.x)
		TOOLTIP_POSITION_RIGHT:
			animation_offset = Vector2(motion.x, motion.y)
		TOOLTIP_POSITION_LEFT:
			animation_offset = Vector2(-motion.x, motion.y)

	return animation_offset


func _get_target_tooltip_global_position() -> Vector2:
	assert(
		not _get_target_canvas_item().get_rotation(),
		"invalid config; rotated target not supported",
	)

	var target_rect := _get_target_global_rect()
	var tooltip_rect := get_global_rect()

	var distance := (target_rect.size / 2.0) + (tooltip_rect.size / 2.0)

	match tooltip_position:
		TOOLTIP_POSITION_ABOVE:
			distance = Vector2(0.0, -distance.y)
		TOOLTIP_POSITION_RIGHT:
			distance = Vector2(distance.x, 0.0)
		TOOLTIP_POSITION_BELOW:
			distance = Vector2(0.0, distance.y)
		TOOLTIP_POSITION_LEFT:
			distance = Vector2(-distance.x, 0.0)

	return (
		target_rect.get_center()
		+ distance
		- (tooltip_rect.get_center() - tooltip_rect.position)
		+ tooltip_offset
	)


func _hide_tooltip() -> void:
	assert(not _is_visible, "invalid state; conflicting visible state")

	_tween = create_tween()

	if fade_out:
		fade_out.apply_tween_property(_tween, self, 0)

	if slide_out:
		var animation_offset := _get_slide_offset(slide_out)

		(
			slide_out
			. apply_tween_property(
				_tween,
				self,
				_get_target_tooltip_global_position() + animation_offset,
			)
		)

	_tween.chain().tween_callback(hide)
	_tween.chain().tween_callback(_reset_animation)


func _reposition() -> void:
	assert(not _tween, "invalid state; can't reposition during animation")

	var target_position := _get_target_tooltip_global_position()
	var animation_offset := _get_slide_offset(slide_in)

	set_global_position(target_position - animation_offset)


func _reset_animation() -> void:
	if not _tween:
		return

	_tween.kill()
	_tween = null


func _show_tooltip() -> void:
	assert(_is_visible, "invalid state; conflicting visible state")

	modulate.a = 1  # Ensure the alpha value has been restored.
	show()

	_tween = create_tween()

	if fade_in:
		modulate.a = 0
		fade_in.apply_tween_property(_tween, self, 1)

	if slide_in:
		(
			slide_in
			. apply_tween_property(
				_tween,
				self,
				_get_target_tooltip_global_position(),
			)
		)

	_tween.chain().tween_callback(_reset_animation)


func _update() -> void:
	if not _is_focused and not _is_hovered and _is_visible:
		hide_tooltip()
		return

	if (_is_focused or _is_hovered) and not _is_visible:
		show_tooltip()
		return


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_anchor_rect_changed() -> void:
	if _is_visible:
		_reposition()


func _on_anchor_visibility_changed() -> void:
	if not _get_target_canvas_item().visible and _is_visible:
		_reset_animation()
		visible = false


func _on_focus_target_focus_entered() -> void:
	_is_focused = true
	_update()


func _on_focus_target_focus_exited() -> void:
	_is_focused = false
	_update()


func _on_hover_target_mouse_entered() -> void:
	_is_hovered = true
	_update()


func _on_hover_target_mouse_exited() -> void:
	_is_hovered = false
	_update()
