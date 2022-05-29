extends "res://scripts/overlap/hitbox.gd"

# should not be needed, but it keeps changing the value back
func _ready() -> void: $CollisionShape2D.set_deferred("disabled", true)

func _on_SwordHitbox_area_entered(area) -> void: if area.has_method("picked_up"): area.picked_up()
