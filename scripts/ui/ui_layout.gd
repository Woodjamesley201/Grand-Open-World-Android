## UiLayout - anchor-relative placement helpers.
##
## Godot's Control.position is ABSOLUTE inside the parent: setting
## `position = Vector2(-160, -90)` on a center-anchored control puts it at
## (-160, -90) from the parent's top-left, i.e. off screen. These helpers set
## point anchors with explicit offsets so controls land where the anchor
## intends, at any window size.
class_name UiLayout
extends RefCounted

## Point-anchor the control at (ax, ay) in [0..1]; its top-left sits `off`
## pixels from that point and it is `sz` in size. If sz is omitted the
## control keeps its current size.
static func place(c: Control, ax: float, ay: float, off: Vector2, sz: Vector2 = Vector2()) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	if sz == Vector2():
		sz = c.size
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + sz.x
	c.offset_bottom = off.y + sz.y

## Full-width horizontal row: y spans [top, top + height].
static func row(c: Control, top: float, height: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = top
	c.offset_bottom = top + height

## Full-width row glued to the bottom edge: y spans [bottom - height - margin,
## bottom - margin].
static func bottom_row(c: Control, height: float, margin: float = 0.0) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = -(height + margin)
	c.offset_bottom = -margin

## Center a control on screen (call after its children are built so the
## final size is known).
static func center(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
