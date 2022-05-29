extends Area2D

export (int) var push_away_multiplier:int = -24
func is_colliding() -> bool: return get_overlapping_areas().size() > 0

func get_push_vector() -> Vector2:
	var areas:Array = get_overlapping_areas()
	var push_vector:Vector2 = Vector2.ZERO
	if areas.size() > 0:
		areas.shuffle()
		for area in areas.slice(0, 3 if areas.size() > 3 else areas.size()-1):
			push_vector += area.global_position.direction_to(self.global_position)
		push_vector = push_vector.normalized()
	return push_vector

# works like a magnet, higher push_mult attracts things faster
func push_away() -> void:
	var areas:Array = get_overlapping_areas()
	for area in areas:
		var push_vector:Vector2 = area.global_position.direction_to(self.global_position)
		push_vector = push_vector.normalized()
		area.get_parent().velocity += push_vector * push_away_multiplier
