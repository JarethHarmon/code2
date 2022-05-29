extends CanvasLayer

onready var heart_empty:TextureRect = $HeartEmpty
onready var heart_full:TextureRect = $HeartFull

export (int) var sprite_width:int = 16
export (int) var sprite_height:int = 16

var full_hearts:int = 1 setget set_full_hearts
var current_hearts:int = 1 setget set_current_hearts

func set_full_hearts(value:int) -> void: 
	full_hearts = max(value, 1) as int
	heart_empty.rect_size.x = full_hearts * sprite_width
	self.current_hearts = min(current_hearts, full_hearts) as int
	
func set_current_hearts(value:int) -> void: 
	current_hearts = clamp(value, 0, full_hearts) as int
	heart_full.rect_size.x = current_hearts * sprite_width

