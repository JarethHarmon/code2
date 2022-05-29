extends Area2D

func _on_HealthPowerup_area_entered(_area) -> void:
	Powerups.emit_signal("current_health_up")
	self.queue_free()

