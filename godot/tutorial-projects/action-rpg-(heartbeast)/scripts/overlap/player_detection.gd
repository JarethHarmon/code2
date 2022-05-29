extends Area2D

var player = null

# these two functions will need to be changed to actually support multiple players
# currently I think it would chase the newest player to enter its zone, and would 
# stop chasing when any player leaves its zone, until a player enters again

func _on_PlayerDetectionZone_body_entered(body) -> void: player = body
func _on_PlayerDetectionZone_body_exited(_body) -> void: player = null

func can_see_player() -> bool: return player != null
