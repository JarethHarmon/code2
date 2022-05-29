extends Node2D

onready var start_position:Vector2 = self.global_position
onready var target_position:Vector2 = self.global_position
onready var timer:Timer = $Timer

export (int) var wander_range_x:int = 32
export (int) var wander_range_y:int = 32
export (float) var min_wander_time:float = 1.0
export (float) var max_wander_time:float = 4.0
export (float) var wander_stop_distance:float = 3.0
export (float) var wander_speed_multiplier:float = 0.5

func _ready() -> void: update_target_position()

func update_target_position() -> void:
	var target_vector:Vector2 = Vector2(rand_range(-wander_range_x, wander_range_x), rand_range(-wander_range_y, wander_range_y))
	target_position = start_position + target_vector

func get_time_left() -> float: return timer.time_left

func start_wander_timer(duration:float=1.0) -> void: timer.start(duration)

func _on_Timer_timeout() -> void: update_target_position()
