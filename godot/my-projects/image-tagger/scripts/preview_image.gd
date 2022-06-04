extends VBoxContainer

const BASE_MAX_DIMENSIONS=16384

# button logic needs to be moved out of this script (especially image importing)

# export (NodePath) var ListItems ; onready var item_list:ItemList = get_node(ListItems)
export (NodePath) var ViewportDisplay ; onready var viewport_display = get_node(ViewportDisplay)
export (NodePath) var FileD ; onready var fd:FileDialog = get_node(FileD)
export (NodePath) var ColorGrade ; onready var color_grade:Control = get_node(ColorGrade)
export (NodePath) var EdgeMix ; onready var edge_mix:Control = get_node(EdgeMix)

enum selection { THUMBNAIL, IMPORT }
var select:int = selection.IMPORT
var use_recursion:bool = true

func _ready() -> void:
	var _err:int = Signals.connect("load_image", self, "_on_FileDialog_file_selected") # should just work

func _on_FileDialog_dir_selected(dir:String) -> void: 
	match select:
		selection.IMPORT: 
			if ImageOp.thumbnail_path == "": return
			Import.queue_append(dir, use_recursion)
			
#		selection.THUMBNAIL: 
#			ImageOp.thumbnail_path = dir + "/"
#			thumb_path_label.text = dir
#			var _err:int = Directory.new().make_dir_recursive(dir)

onready var image_mutex:Mutex = Mutex.new()
onready var image_thread:Thread = Thread.new()
func _on_FileDialog_file_selected(path:String) -> void:
	fd.hide()
	if (image_mutex.try_lock() != OK): return
	if (image_thread.is_alive()): return
	image_mutex.lock()
	image_thread.start(self, "_thread", path)

func _thread(path:String) -> void:
	var i:Image = Image.new()
	var e:int = i.load(path)
	if e != OK: return
	
	var it:ImageTexture = ImageTexture.new()
	it.create_from_image(i, 0)
	it.set_size_override(calc_size(it))
	$hbox_0/image_0.texture = it
	call_deferred("_done")

func _done() -> void:
	if image_thread.is_alive() or image_thread.is_active(): image_thread.wait_to_finish()
	image_mutex.unlock()
	#print("DONE\n")

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

func _on_import_images_pressed() -> void:
	if fd.visible: return
	select = selection.IMPORT
	fd.mode = 2 	# choose folder
	fd.access = 2	# file system
	fd.window_title = "Choose a folder to import from"
	fd.popup()

func _on_choose_image_pressed() -> void:
	if fd.visible: return
	fd.mode = 0		# choose file
	fd.access = 2	# file system
	fd.window_title = "Choose an image"
	fd.popup()
	
func _on_color_grade_toggled(button_pressed:bool) -> void: color_grade.visible = button_pressed
func _on_edge_mix_toggled(button_pressed:bool): edge_mix.visible = button_pressed
func _on_use_recursion_toggled(button_pressed:bool) -> void: use_recursion = button_pressed
