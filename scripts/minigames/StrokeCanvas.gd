extends RefCounted
class_name StrokeCanvas

## Shared Line2D stroke helpers for Drawing minigame and Dreamlands hub canvas.

const MIN_POINT_DIST: float = 4.0


static func begin_stroke(parent: Node, color: Color, width: float, pos: Vector2, z_index: int = 10) -> Line2D:
	var line := Line2D.new()
	line.default_color = color
	line.width = width
	line.antialiased = true
	line.z_index = z_index
	line.add_point(pos)
	parent.add_child(line)
	return line


static func extend_stroke(line: Line2D, pos: Vector2) -> void:
	if line == null or line.get_point_count() == 0:
		return
	var last := line.get_point_position(line.get_point_count() - 1)
	if last.distance_to(pos) >= MIN_POINT_DIST:
		line.add_point(pos)


static func stroke_count(strokes: Array) -> int:
	return strokes.size()
