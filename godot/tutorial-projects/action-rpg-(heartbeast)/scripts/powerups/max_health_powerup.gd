extends Area2D

func _on_MaxHealthPowerup_area_entered(_area) -> void:
	Powerups.emit_signal("max_health_up")
	self.queue_free()
