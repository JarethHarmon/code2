extends Camera2D

onready var top_left:Position2D = $Limits/TopLeft
onready var bottom_right:Position2D = $Limits/BottomRight

func _ready() -> void:
	limit_top = top_left.position.y as int
	limit_left = top_left.position.x as int
	limit_bottom = bottom_right.position.y as int
	limit_right = bottom_right.position.x as int
