extends Node2D
var blocked: PackedVector2Array = PackedVector2Array()
var step: float = 8.0
func _draw() -> void:
	for p in blocked:
		draw_rect(Rect2(p - Vector2(step, step) * 0.5, Vector2(step, step)), Color(1.0, 0.18, 0.18, 0.5))
