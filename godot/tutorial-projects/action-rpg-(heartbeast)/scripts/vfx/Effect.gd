extends AnimatedSprite

func _ready() -> void: 
	var _error:int = self.connect("animation_finished", self, "_on_Effect_animation_finished")
	self.play()
	
func _on_Effect_animation_finished(): self.queue_free()
