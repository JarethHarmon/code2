extends VBoxContainer

const BASE_MAX_DIMENSIONS=16384

# export (NodePath) var ListItems ; onready var item_list:ItemList = get_node(ListItems)
export (NodePath) var ViewportDisplay ; onready var viewport_display = get_node(ViewportDisplay)
export (NodePath) var FileD ; onready var fd:FileDialog = get_node(FileD)

func _input(event) -> void:
	if fd.visible: return
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT: 
			fd.mode = 0
			fd.access = 2
			fd.window_title = "Choose an image"
			fd.popup()
			
func _on_FileDialog_file_selected(path) -> void:
	var i:Image = Image.new()
	var e:int = i.load(path)
	if e != OK: return
	
	var it:ImageTexture = ImageTexture.new()
	it.create_from_image(i, 0)
	it.set_size_override(calc_size(it))
	$hbox_0/image_0.texture = it
	fd.hide()

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


