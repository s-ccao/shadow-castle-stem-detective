extends "res://scripts/clue_list_item.gd"


func _ready() -> void:
	super._ready()
	focus_entered.connect(_on_mouse_entered)
	focus_exited.connect(_on_mouse_exited)
	visibility_changed.connect(
		func() -> void:
			if not is_visible_in_tree():
				ArchiveUi.settle_motion(self)
				scale = Vector2.ONE
	)


func set_selected(selected: bool) -> void:
	ArchiveUi.settle_motion(self)
	super.set_selected(selected)


func _on_mouse_entered() -> void:
	_hovered = true
	hover_glow.visible = true
	# Keep the index's hit/focus bounds fixed; the brass rail carries hover.
	hover_glow.modulate = Color(1.0, 0.90, 0.70, 1.0)


func _on_mouse_exited() -> void:
	_hovered = false
	hover_glow.visible = false
	ArchiveUi.settle_motion(self)
	scale = Vector2.ONE


func _on_button_down() -> void:
	var motion := ArchiveUi.begin_motion(self)
	motion.tween_property(self, "scale", Vector2(0.99, 0.99), 0.06)
	motion.tween_property(self, "scale", Vector2.ONE, 0.12)


func _on_button_up() -> void:
	ArchiveUi.settle_motion(self)
	scale = Vector2.ONE
