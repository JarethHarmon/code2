extends VBoxContainer

const BASE_MAX_DIMENSIONS=16384
const icon = preload("res://misc/icon.png")

# export (NodePath) var ListItems ; onready var item_list:ItemList = get_node(ListItems)
export (NodePath) var ViewportDisplay ; onready var viewport_display = get_node(ViewportDisplay)

func _ready() -> void:
	$hbox_0/image_0.texture = icon

func calc_size(it:ImageTexture) -> Vector2:
	var size_1:Vector2 = viewport_display.rect_size
	var size_2:Vector2 = $hbox_0/image_0.rect_size
	var size_i:Vector2 = Vector2(it.get_width(), it.get_height())
	var size:Vector2 = Vector2.ZERO
	
	var ratio_h:float = size_1.y / size_i.y
	var ratio_w:float = size_1.x / size_i.x
	var ratio_s:Vector2 = size_2 / size_1
	
	if ratio_h < ratio_w: # portrait
		size.y = size_1.y
		size.x = (size_1.y / size_i.y) * size_i.x
		if ratio_s.y < ratio_s.x: # portrait-shaped section
			size *= ratio_s.y
		else: size *= ratio_s.x
	else: # landscape or square
		size.x = size_1.x
		size.y = (size_1.x / size_i.x) * size_i.y
		if ratio_s.y < ratio_s.x: size *= ratio_s.y
		else: size *= ratio_s.x
	return size
