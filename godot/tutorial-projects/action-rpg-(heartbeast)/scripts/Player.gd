extends KinematicBody2D

enum states { MOVE, ROLL, ATTACK, DEATH }

const PlayerHurtSound = preload("res://scenes/sfx/player_hurt_sound.tscn")

export (int) var max_speed:int = 200
export (int) var speed:int = 100
export (int) var roll_speed:int = 200
export (int) var acceleration:int = 20
export (int) var friction:int = 25

onready var animation_player:AnimationPlayer = $AnimationPlayer
onready var animation_tree:AnimationTree = $AnimationTree
onready var animation_state:AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
onready var sword_hitbox:Area2D = $HitboxPivot/SwordHitbox
onready var hurtbox:Area2D = $Hurtbox
onready var stats:Node = $PlayerStats
onready var health_ui = $HealthUI
onready var shader_animation_player:AnimationPlayer = $ShaderAnimationPlayer

onready var soft_collision:Area2D = $SoftCollision

var roll_vector:Vector2 = Vector2.RIGHT
var velocity:Vector2 = Vector2.ZERO
var knockback:Vector2 = Vector2.ZERO
var state:int = states.MOVE

func _ready() -> void: 
	animation_tree.active = true
	var _error:int = stats.connect("zero_health", self, "_on_stats_zero_health")
	_error = Powerups.connect("max_health_up", self, "_on_pickup_max_health_powerup")
	_error = Powerups.connect("current_health_up", self, "_on_pickup_health_powerup")
	
	health_ui.full_hearts = stats.full_health
	health_ui.current_hearts = stats.current_health

func _physics_process(_delta:float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, friction)
	knockback = move_and_slide(knockback)
	match state:
		states.MOVE: move_state()
		states.ROLL: roll_state()
		states.ATTACK: attack_state()
		states.DEATH: death_state()
	soft_collision.push_away() # consider disabling for performance reasons
	
# returns input_vector, takes the named directional input strings as arguments
func get_input_vector(left:String="ui_left", right:String="ui_right", up:String="ui_up", down:String="ui_down", normalize:bool=false) -> Vector2:
	var input_vector:Vector2 = Vector2.ZERO
	input_vector.x = Input.get_action_strength(right) - Input.get_action_strength(left)
	input_vector.y = Input.get_action_strength(down) - Input.get_action_strength(up)
	if normalize: input_vector = input_vector.normalized()
	return input_vector

func move_state() -> void:
	var input_vector:Vector2 = get_input_vector("move_left", "move_right", "move_up", "move_down", true)
	if input_vector != Vector2.ZERO:
		animation_tree.set("parameters/Idle/blend_position", input_vector)
		animation_tree.set("parameters/Run/blend_position", input_vector)
		animation_tree.set("parameters/Attack/blend_position", input_vector) # commits the user to attacking in a direction (dont put in attack_state) (ie can't change their mind mid-attack)
		animation_tree.set("parameters/Roll/blend_position", input_vector)
		animation_state.travel("Run")
		velocity = velocity.move_toward(input_vector * speed, acceleration)
		velocity = velocity.clamped(max_speed)
		roll_vector = input_vector
		sword_hitbox.knockback_vector = input_vector
	else: 
		animation_state.travel("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, friction)
		
	move()
	if Input.is_action_pressed("attack"): state = states.ATTACK #_just
	if Input.is_action_just_pressed("roll"): state = states.ROLL
	
func attack_state() -> void: 
	velocity = Vector2.ZERO # prevents sliding during attack
	animation_state.travel("Attack")

func roll_state() -> void: 
	velocity = roll_vector * roll_speed
	animation_state.travel("Roll")
	move()

func death_state() -> void:
	self.queue_free()

func move() -> void: velocity = move_and_slide(velocity)

func attack_animation_finished() -> void: state = states.MOVE
func roll_animation_finished() -> void: 
	state = states.MOVE
	velocity *= 0.5

func _on_Hurtbox_damage_taken(area:Area2D) -> void:
	get_parent().add_child(PlayerHurtSound.instance())
	stats.take_damage(area.damage)
	health_ui.set_current_hearts(stats.current_health)
	hurtbox.start_invincibility()
	knockback = area.knockback_vector * area.knockback_strength

func _on_pickup_max_health_powerup() -> void: 
	if (stats.get_full_health() >= stats.max_health): return # no increase if at max
	stats.set_full_health(stats.get_full_health()+1)
	health_ui.set_full_hearts(stats.get_full_health())
	
func _on_pickup_health_powerup() -> void:
	stats.set_current_health(stats.get_current_health()+1)
	health_ui.set_current_hearts(stats.get_current_health())

func _on_stats_zero_health() -> void: state = states.DEATH

func _on_Hurtbox_invincibility_started(): if hurtbox.show_invincibility_effect: shader_animation_player.play("BlinkStart")
func _on_Hurtbox_invincibility_ended(): shader_animation_player.play("BlinkStop") # if show_invincibility_effect:

