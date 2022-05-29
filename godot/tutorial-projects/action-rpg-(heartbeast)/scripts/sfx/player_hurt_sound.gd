extends AudioStreamPlayer

func _on_PlayerHurtSound_finished() -> void: self.queue_free()
