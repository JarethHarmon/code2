extends Node

signal zero_health

export (int) var max_health:int = 10 # does not change, but const not exportable
export (int) var full_health:int = 1 setget set_full_health, get_full_health

onready var current_health:int = full_health setget set_current_health, get_current_health

func set_full_health(value:int) -> void:
	full_health = max(value, 1) as int
	if (current_health != null): set_current_health(min(current_health, full_health) as int)
	else: set_current_health(full_health)
func get_full_health() -> int: return full_health

func set_current_health(value:int) -> void:	current_health = min(value, full_health) as int
func get_current_health() -> int: return current_health

func take_damage(amount:int) -> void:
	set_current_health(current_health - amount)
	if (current_health <= 0): emit_signal("zero_health")
