extends Area2D

# want to rewrite this, need to figure out exactly how it interacts with player, etc

signal damage_taken(area)
signal invincibility_started
signal invincibility_ended

const HitEffect = preload("res://scenes/vfx/hit_effect.tscn")

onready var timer:Timer = $Timer

export (bool) var show_hit_effect:bool = true
export (Vector2) var hit_position_modifier:Vector2 = Vector2.ZERO
export (bool) var can_be_invincible:bool = true
export (bool) var show_invincibility_effect:bool = true
export (float) var invinciblility_duration:float = 0.5 

var invincible:bool = false setget set_invincible, get_invincible

func get_invincible() -> bool: return invincible
func set_invincible(value:bool) -> void: 
	invincible = value
	if invincible: 
		emit_signal("invincibility_started")
		self.set_deferred("monitoring", false)
	else: 
		emit_signal("invincibility_ended")
		self.set_deferred("monitoring", true)

# now automatically deals with damage and invincibility itself
func _on_Hurtbox_area_entered(area:Area2D) -> void:
	if get_invincible(): return
	if can_be_invincible: self.invincible = true
	if show_hit_effect:
		var hit_effect = HitEffect.instance()
		hit_effect.position = self.position + hit_position_modifier
		self.add_child(hit_effect)
	emit_signal("damage_taken", area)
	timer.start(invinciblility_duration)
	
# now used only for special situations (like mario invincibility star)
func start_invincibility(duration:float=invinciblility_duration) -> void: 
	self.invincible = true
	timer.start(duration)
	
func _on_Timer_timeout() -> void: self.invincible = false
