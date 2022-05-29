extends KinematicBody2D

# could create an export var for max_health and then in _ready() set the stats max_health equal to it
# this would allow setting all variable from the root bat node, however the code would need to be added  
# on everything that has health, so I am unsure if it is a good idea 

enum states { IDLE, WANDER, CHASE }
enum drops { HEALTH, MAX_HEALTH }

export (int) var max_speed:int = 125
export (int) var speed:int = 50
export (int) var friction:int = 15
export (int) var acceleration:int = 50
export (int) var push_multiplier:int = 25
export (int) var blob_area:int = 5

onready var stats:Node = $Stats
onready var sprite:AnimatedSprite = $BatSprite
onready var player_detector:Area2D = $PlayerDetectionZone
onready var soft_collision:Area2D = $SoftCollision
onready var hurtbox:Area2D = $Hurtbox
onready var hitbox:Area2D = $Hitbox
onready var drops_node:YSort = get_node("/root/World/Objects/Drops")
onready var wander_controller:Node2D = $WanderController
onready var shader_animation_player:AnimationPlayer = $ShaderAnimationPlayer
onready var blob:Vector2 = get_rand_blob(blob_area)

var velocity:Vector2 = Vector2.ZERO
var knockback:Vector2 = Vector2.ZERO
var state:int = states.IDLE

var powerups:Dictionary = { drops.HEALTH:Powerups.powerup_health, drops.MAX_HEALTH:Powerups.powerup_max_health }
var drop_chances:Dictionary = { drops.HEALTH:0.5, drops.MAX_HEALTH:0.1 }

func _ready() -> void: 
	var _error:int = stats.connect("zero_health", self, "_on_stats_zero_health")
	choose_next_state()

func _physics_process(_delta) -> void: 
	knockback = knockback.move_toward(Vector2.ZERO, friction)
	knockback = move_and_slide(knockback)
	
	match state:
		states.IDLE: idle_state()
		states.WANDER: wander_state()
		states.CHASE: chase_state()
	
	velocity = move_and_slide(velocity)	

func seek_player() -> void: if player_detector.can_see_player(): state = states.CHASE	
func pick_random_state(States:Array) -> int: return States[randi() % States.size()]
func choose_next_state() -> void:
	state = pick_random_state([states.IDLE, states.WANDER])
	wander_controller.start_wander_timer(rand_range(wander_controller.min_wander_time, wander_controller.max_wander_time))
func accelerate_towards(target_position:Vector2, speed_multiplier:float=1.0) -> Vector2: 
	var direction:Vector2 = self.global_position.direction_to(target_position)
	velocity = velocity.move_toward(direction * speed * speed_multiplier, acceleration)
	velocity = velocity.clamped(max_speed)
	sprite.flip_h = velocity.x < 0
	return direction
	
func idle_state() -> void: 
	velocity = velocity.move_toward(Vector2.ZERO, friction)
	seek_player()
	if wander_controller.get_time_left() == 0: choose_next_state()
	
func wander_state() -> void: 
	seek_player()
	if wander_controller.get_time_left() == 0: choose_next_state()
	var _direction:Vector2 = accelerate_towards(wander_controller.target_position, wander_controller.wander_speed_multiplier)
	if self.global_position.distance_to(wander_controller.target_position) <= wander_controller.wander_stop_distance: choose_next_state()


func get_rand_blob(radius:int=2) -> Vector2: return Vector2(rand_range(-radius, radius), rand_range(-radius, radius))

func chase_state() -> void:
	var player = player_detector.player
	if player != null: 
		if self.global_position.distance_to(player.global_position) > blob.length() + 0.5:
			var direction:Vector2 = accelerate_towards(player.global_position + blob)
			hitbox.knockback_vector = direction
		else: velocity = Vector2.ZERO
	else: state = states.IDLE
	if soft_collision.is_colliding(): velocity += soft_collision.get_push_vector() * push_multiplier

func _on_Hurtbox_damage_taken(area) -> void:
	stats.take_damage(area.damage)
	knockback = area.knockback_vector * area.knockback_strength

func _on_stats_zero_health() -> void: 
	sprite.animation = "Death"
	$AudioStreamPlayer.play()
	var _error:int = sprite.connect("animation_finished", self, "_on_death_animation_finished")

func _on_death_animation_finished() -> void: 
	var chance:float = randf()
	if (chance < drop_chances[drops.MAX_HEALTH]): 
		var powerup = powerups[drops.MAX_HEALTH].instance()
		drops_node.add_child(powerup)
		powerup.position = self.global_position + hurtbox.hit_position_modifier
	elif (chance < drop_chances[drops.HEALTH]): 
		var powerup = powerups[drops.HEALTH].instance()
		drops_node.add_child(powerup)
		powerup.position = self.global_position + hurtbox.hit_position_modifier
	self.queue_free() 

func _on_Hurtbox_invincibility_started(): if hurtbox.show_invincibility_effect: shader_animation_player.play("BlinkStart")
func _on_Hurtbox_invincibility_ended(): shader_animation_player.play("BlinkStop")
