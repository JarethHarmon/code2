extends VBoxContainer

# button logic needs to be moved out of this script (especially image importing) (create a preview_buttons node & script)

const loading_icon:StreamTexture = preload("res://assets/buffer-01.png")
const pixel_smooth = preload("res://shaders/SmoothPixel.tres")
const BASE_MAX_DIMENSIONS=16384

# export (NodePath) var ListItems ; onready var item_list:ItemList = get_node(ListItems)
export (NodePath) var ViewportDisplay ; onready var viewport_display = get_node(ViewportDisplay)
export (NodePath) var FileD ; onready var fd:FileDialog = get_node(FileD)
export (NodePath) var ColorGrade ; onready var color_grade:Control = get_node(ColorGrade)
export (NodePath) var EdgeMix ; onready var edge_mix:Control = get_node(EdgeMix)
export (NodePath) var SmoothPixelButton ; onready var smooth_pixel_button:CheckButton = get_node(SmoothPixelButton)

onready var preview:TextureRect = $hbox_0/image_0

onready var image_mutex:Mutex = Mutex.new()
onready var image_thread:Thread = Thread.new()
var current_image:Texture

func _ready() -> void:
	var _err:int = Signals.connect("load_image", self, "_on_FileDialog_file_selected") # should just work
	_err = Signals.connect("settings_loaded", self, "_settings_loaded")
	_err = Signals.connect("resize_preview_image", self, "resize_current_image")
	_err = Signals.connect("filter_toggled", self, "_on_filter_toggled")
	_err = Signals.connect("edge_mix_toggled", self, "_on_edge_mix_toggled")
	_err = Signals.connect("color_grade_toggled", self, "_on_color_grade_toggled")
	_err = Signals.connect("smooth_pixel_toggled", self, "_on_use_smooth_pixel_toggled")
	
	_err = Signals.connect("all_button_pressed", self, "clear_image_preview")
	_err = Signals.connect("import_button_pressed", self, "clear_image_preview")
	_err = Signals.connect("page_changed", self, "clear_image_preview")
	
	self.call_deferred("prep_threads")

func clear_image_preview() -> void:
	image_mutex.lock()
	preview.set_texture(null)
	current_image = null
	image_mutex.unlock()

func create_current_image(thread_id:int=-1, im:Image=null, path:String="") -> void:
	if im == null:
		var tex:Texture = preview.get_texture()
		if tex == null: return
		im = tex.get_data()
	
	var it:ImageTexture = ImageTexture.new()
	it.create_from_image(im, 4 if Globals.settings.use_filter else 0)
	
	if thread_id >= 0 and path != "": 
		if check_stop_thread(thread_id): 
			return
	current_image = it

func resize_current_image(path:String="") -> void:
	if current_image == null: return
	if path != "" and path != p: return
	
	preview.set_texture(null)
	current_image.set_size_override(calc_size(current_image))
	yield(get_tree(), "idle_frame")
	
	preview.set_texture(current_image)

func _settings_loaded() -> void:
	_on_color_grade_toggled(Globals.settings.use_color_grade)
	_on_edge_mix_toggled(Globals.settings.use_edge_mix)
	_on_use_smooth_pixel_toggled(Globals.settings.use_smooth_pixel)
	_on_filter_toggled(Globals.settings.use_filter)
	_on_use_recursion_toggled(Globals.settings.use_recursion)


var max_threads:int = 3
var thread_queue:Array = []
var thread_active:Array = []

func prep_threads() -> void:
	for t in thread_queue:
		if t == null: continue
		if t.is_active() or t.is_alive(): t.wait_to_finish()
		t = null
	thread_queue.clear()
	for i in max_threads: 
		thread_queue.append(Thread.new())
		thread_active.append(false)

var use_loading_icon:bool = true # add to settings and create a button

func _on_FileDialog_file_selected(path:String) -> void:
	fd.hide()
	#if (image_mutex.try_lock() != OK): return
	#if (image_thread.is_alive()): return
	#image_mutex.lock()
	image_mutex.lock()
	for i in thread_active.size(): thread_active[i] = false
	image_mutex.unlock()
	if use_loading_icon: preview.set_texture(loading_icon)
	___thread(path)

func ___thread(path:String) -> void:
	image_mutex.lock()
	p = path
	image_mutex.unlock()
	if not image_thread.is_active():
		var _err:int = image_thread.start(self, "__thread")

func _test() -> void:
	image_thread.wait_to_finish()
	image_thread = Thread.new()

var p:String = ""

func __thread() -> void:	
	var all_threads_busy:bool = true
	while all_threads_busy:
		for thread_id in thread_queue.size():
			image_mutex.lock()
			var thread:Thread = thread_queue[thread_id]
			image_mutex.unlock()
			if not thread.is_active():
				all_threads_busy = false
				thread_active[thread_id] = true
				var _err:int = thread.start(self, "_thread", [thread_id, p])
				break
		OS.delay_msec(50)
	self.call_deferred("_test")
	
func _thread(args:Array) -> void:
	var thread_id:int = args[0]
	var path:String = args[1]
	if check_stop_thread(thread_id): 
		call_deferred("_done", thread_id, path)
		return
	
	var actual_format:String = ImageOp.GetActualFormat(path)
	var saved_format:String = path.get_extension().to_upper().replace("JPEG", "JPG")
	var im:Image ; var e:int = 0
	if check_stop_thread(thread_id):
		call_deferred("_done", thread_id, path) 
		return
	
	if (actual_format != saved_format): 
		print("\n", path, "\n\tactual format: ", actual_format, "\n\tsaved format: ", saved_format)
		im = ImageOp.LoadUnknownFormat(path)
	else:
		im = Image.new() 
		e = im.load(path)
		if e != OK: im = ImageOp.LoadUnknownFormatAlt(path)
	if check_stop_thread(thread_id): 
		call_deferred("_done", thread_id, path)
		return
	
	create_current_image(thread_id, im, path)
	call_deferred("_done", thread_id, path)
	
func check_stop_thread(thread_id:int) -> bool:
	var stop_thread:bool = true
	image_mutex.lock()
	stop_thread = not thread_active[thread_id]
	image_mutex.unlock()
	return stop_thread

func _done(thread_id:int, path:String) -> void:
	image_mutex.lock()
	if thread_queue[thread_id].is_alive() or thread_queue[thread_id].is_active(): 
		thread_queue[thread_id].wait_to_finish()
	thread_queue[thread_id] = Thread.new()
	thread_active[thread_id] = false
	image_mutex.unlock()
	resize_current_image(path)

func calc_size(it:ImageTexture) -> Vector2:
	var size_1:Vector2 = viewport_display.rect_size
	var size_2:Vector2 = $hbox_0/image_0.rect_size
	var size_i:Vector2 = Vector2(it.get_width(), it.get_height())
	var size:Vector2 = Vector2.ZERO
	
	if size_i == Vector2.ZERO: return size_i # prevent /0 (still need to handle images that are too large somewhere else)
	
	var ratio_h:float = size_1.y / size_i.y # causes /0 crash when image is too large (fails to load and gives size of 0)
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
	
func _on_choose_image_pressed() -> void:
	if fd.visible: return
	fd.mode = 0		# choose file
	fd.access = 2	# file system
	fd.window_title = "Choose an image"
	fd.popup()
	
func _on_color_grade_toggled(button_pressed:bool) -> void: 
	Globals.settings.use_color_grade = button_pressed
	color_grade.visible = button_pressed
	
func _on_edge_mix_toggled(button_pressed:bool): 
	Globals.settings.use_edge_mix = button_pressed
	edge_mix.visible = button_pressed
	
func _on_use_recursion_toggled(button_pressed:bool) -> void: Globals.settings.use_recursion = button_pressed
func _on_filter_toggled(button_pressed:bool) -> void:	
	Globals.settings.use_filter = button_pressed
	if button_pressed:
		smooth_pixel_button.disabled = false
		if Globals.settings.use_smooth_pixel: 
			_on_use_smooth_pixel_toggled(true)
	else:
		smooth_pixel_button.disabled = true
		if Globals.settings.use_smooth_pixel:
			_on_use_smooth_pixel_toggled(false)
			Globals.settings.use_smooth_pixel = true
		else: _on_use_smooth_pixel_toggled(false)
	
	create_current_image()
	resize_current_image()

# need to ensure it loads and applies the value from the settings file
func _on_use_smooth_pixel_toggled(button_pressed:bool) -> void:
	Globals.settings.use_smooth_pixel = button_pressed
	if button_pressed: 
		$hbox_0/image_0.set_material(pixel_smooth)
	else: $hbox_0/image_0.set_material(null)

