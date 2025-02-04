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
enum TooltipPosition {  # gdlint:ignore=class-definitions-order
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

@export_subgroup("Focus")

## focus_delay is a wait time prior to starting the "show" tooltip animation when the
## action is triggered by the focus target. Ignored when `show_when_focused` is `false`.
@export var focus_delay: float = 0.0

## focus_target is an alternative `Control` node which, when it grabs focus, will reveal
## the tooltip. Ignored if `show_when_focused` is set to `false`.
##
## NOTE: If set, the `anchor` node will *not* be listened to for hover events. Ignored
## when `show_when_focused` is `false`.
@export var focus_target: Control = null

## show_when_focused controls whether the tooltip will be revealed by focusing the
## anchor node (or `focus_target` if set).
@export var show_when_focused: bool = true

@export_subgroup("Hover")

## hover_hide_delay is a wait time prior to starting the "hide" tooltip animation. This
## is to allow time for the cursor to hover over the tooltip.
@export var hover_hide_delay: float = 0.0

## hover_show_delay is a wait time prior to starting the "show" tooltip animation when
## the action is triggered by the hover target. Ignored when `show_when_hovered` is
## `false`.
@export var hover_show_delay: float = 0.0

## hover_target is an alternative `CanvasItem` node which, when hovered, will reveal the
## tooltip. Ignored if `show_when_hovered` is set to `false`.
##
## NOTE: If set, the `anchor` node will *not* be listened to for hover events. Ignored
## when `show_when_hovered` is `false`.
@export var hover_target: CanvasItem = null

## keep_open_when_tooltip_hovered controls whether the tooltip will remain open when the
## user hovers over it.
@export var keep_open_when_tooltip_hovered: bool = true

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
var _is_hover_target_hovered: bool = false
var _is_tooltip_hovered: bool = false
var _is_visible: bool = false
var _is_waiting_to_hide: bool = false
var _tween: Tween = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## hide_tooltip hides the tooltip after animating its outgoing effects. If `animate` is
## `false`, then animations will be skipped.
##
## NOTE: This method should be preferred over `hide`, which won't handle animations.
func hide_tooltip(delay: float = 0.0, animate: bool = true) -> void:
	if not _is_visible:
		return

	_reset_animation()
	_is_visible = false

	if animate:
		_hide_tooltip(delay)
	else:
		visible = false

	tooltip_closed.emit()


## show_tooltip reveals the tooltip after animating its incoming effects.
##
## NOTE: This method should be preferred over `show`, which will immediately toggle
## visibility - ignoring animations.
func show_tooltip(delay: float = 0.0) -> void:
	if _is_visible:
		return

	_reset_animation()
	_is_visible = true

	_show_tooltip(delay)

	tooltip_opened.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	visible = false
	top_level = true

	var anchor := _get_target_canvas_item()
	assert(anchor is CanvasItem, "invalid state; missing node")
	assert(anchor.is_inside_tree(), "invalid state; node must be in scene tree")

	Signals.connect_safe(anchor.item_rect_changed, _on_anchor_rect_changed)
	Signals.connect_safe(anchor.visibility_changed, _on_anchor_visibility_changed)

	if keep_open_when_tooltip_hovered:
		Signals.connect_safe(mouse_entered, _on_tooltip_mouse_entered)
		Signals.connect_safe(mouse_exited, _on_tooltip_mouse_exited)

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

	if anchor.is_node_ready():
		_reposition()
	else:
		Signals.connect_safe(anchor.ready, _reposition, CONNECT_ONE_SHOT)


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


func _hide_tooltip(delay: float) -> void:
	assert(not _is_visible, "invalid state; conflicting visible state")

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)

	_is_waiting_to_hide = true
	_tween.tween_interval(delay)
	_tween.tween_callback(func(): _is_waiting_to_hide = false)

	if fade_out:
		fade_out.apply_tween_property(_tween, self, 0, false)

	if slide_out:
		var animation_offset := _get_slide_offset(slide_out)

		(
			slide_out
			. apply_tween_property(
				_tween,
				self,
				_get_target_tooltip_global_position() + animation_offset,
				fade_out != null,
			)
		)

	_tween.chain().tween_callback(hide)
	_tween.chain().tween_callback(_reset_animation)


func _reposition() -> void:
	# TODO: This can be relaxed through use of `Tween.interpolate_value`.
	assert(not _tween, "invalid state; can't reposition during animation")

	var target_position := _get_target_tooltip_global_position()
	var animation_offset := _get_slide_offset(slide_in)

	set_global_position(target_position - animation_offset)


func _reset_animation() -> void:
	_is_waiting_to_hide = false

	if not _tween:
		return

	_tween.kill()
	_tween = null


func _show_tooltip(delay: float) -> void:
	assert(_is_visible, "invalid state; conflicting visible state")

	modulate.a = 1  # Ensure the alpha value has been restored.
	show()

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	_tween.tween_interval(delay)

	if fade_in:
		modulate.a = 0
		fade_in.apply_tween_property(_tween, self, 1, false)

	if slide_in:
		(
			slide_in
			. apply_tween_property(
				_tween,
				self,
				_get_target_tooltip_global_position(),
				fade_in != null,
			)
		)

	_tween.chain().tween_callback(_reset_animation)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_anchor_rect_changed() -> void:
	if _is_visible:
		_reposition()


func _on_anchor_visibility_changed() -> void:
	var anchor := _get_target_canvas_item()
	assert(anchor is CanvasItem, "invalid state; missing node")
	assert(anchor.is_inside_tree(), "invalid state; node must be in scene tree")

	if _is_visible and not anchor.visible:
		hide_tooltip(0.0, false)

	elif not _is_visible and anchor.visible:
		var anchor_rect: Rect2 = anchor.get_global_rect()
		var global_mouse_position := get_global_mouse_position()

		# FIXME(https://github.com/godotengine/godot/issues/87203): Remove workaround.
		# Note that this solution fails if the anchor is blocked by another node.
		if anchor_rect.has_point(global_mouse_position):
			_reposition()
			_on_hover_target_mouse_entered()


func _on_focus_target_focus_entered() -> void:
	_is_focused = true
	if not _is_visible:
		show_tooltip(focus_delay)


func _on_focus_target_focus_exited() -> void:
	_is_focused = false
	if not _is_hover_target_hovered and not _is_tooltip_hovered and _is_visible:
		hide_tooltip()


func _on_hover_target_mouse_entered() -> void:
	_is_hover_target_hovered = true

	if _is_waiting_to_hide:
		assert(visible, "invalid state; expected visible tooltip")

		_is_visible = true
		_reset_animation()

	if not _is_visible:
		show_tooltip(hover_show_delay)


func _on_hover_target_mouse_exited() -> void:
	_is_hover_target_hovered = false
	if not _is_focused and _is_visible:
		hide_tooltip(hover_hide_delay)


func _on_tooltip_mouse_entered() -> void:
	_is_tooltip_hovered = true

	if _is_waiting_to_hide:
		assert(visible, "invalid state; expected visible tooltip")

		_is_visible = true
		_reset_animation()


func _on_tooltip_mouse_exited() -> void:
	_is_tooltip_hovered = false
	if not _is_focused and not _is_hover_target_hovered and _is_visible:
		hide_tooltip(hover_hide_delay)
