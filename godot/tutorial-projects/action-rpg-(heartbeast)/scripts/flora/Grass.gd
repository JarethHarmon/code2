extends Node2D

func _on_GrassDestroyEffect_animation_finished() -> void: self.queue_free()
func _on_Hurtbox_area_entered(_area) -> void:
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	$Sprite.hide()
	$GrassDestroyEffect.show()
	$GrassDestroyEffect.play()

