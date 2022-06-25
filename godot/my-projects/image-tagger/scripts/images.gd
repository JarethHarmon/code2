extends ItemList

const icon_broken:StreamTexture = preload("res://assets/icon-broken.png")
const icon_loading:StreamTexture = preload("res://assets/buffer-01.png")

const KB:int = 1024
const MB:int = KB*KB
const GB:int = KB*MB

export (NodePath) onready var page_label = get_node(page_label)

onready var sc:Mutex = Mutex.new() 		# scene mutex
onready var ii:Mutex = Mutex.new() 		# item index mutex
onready var ci:Mutex = Mutex.new() 		# current_page_images mutex
onready var lt:Mutex = Mutex.new() 		# loaded_thumbnails mutex

var image_history:Dictionary = {}		# komi64:ImageTexture :: stores last X full images
var page_history:Array = []				# fifo queue :: stores page numbers
var pages:Dictionary = {}				# [page_number, load_id]:[komihash] :: 
var current_page_images:Array = []		# fifo queue :: stores komi64 hashes of thumbnails waiting to be loaded
var loaded_thumbnails:Dictionary = {}	# komi64:ImageTexture :: stores last X loaded thumbnails
var loading_threads:Array = []			# an array of threads used for loading thumbnails

var item_index:int = 0					# current index in the item list
var current_page_number:int = 1			# page the user is on in the current query
var total_page_count:int = 0			# the total number of pages for the current query
var total_image_count:int = 0			# the total number of images for the current group (import_group/image_group/all)
var queried_image_count:int = 0			# the total number of images for the current query 
var current_page_image_count:int = 0	# the number of images on the current page
var offset:int = 0						# the offset in the database for the current query

var starting_load_process:bool = false	# whether a page is currently starting to load
var stopping_load_process:bool = false	# whether the current page is trying to stop loading

var thumbnail_path:String = ""			# the path to the thumbnails folder

func _ready() -> void: 
	var _err:int = Signals.connect("search_pressed", self, "prepare_query")
	_err = Signals.connect("all_button_pressed", self, "prepare_query")
	_err = Signals.connect("import_button_pressed", self, "prepare_query")
	_err = Signals.connect("prev_page_pressed", self, "prev_page_button_pressed")
	_err = Signals.connect("next_page_pressed", self, "next_page_button_pressed")
	#_err = self.connect("item_selected", self, "image_selected")
	_err = self.connect("multi_selected", self, "image_selected")
	_err = Signals.connect("delete_pressed", self, "import_group_deleted")
	
func prepare_query(tags_all:Array=[], tags_any:Array=[], tags_none:Array=[], new_query:bool=true) -> void:
	if new_query:
		current_page_number = 1
		total_page_count = 1
		total_image_count = 0
	start_query(Globals.current_type_id, Globals.current_load_id, tags_all, tags_any, tags_none)

func start_query(type_id:int, load_id:String, tags_all:Array=[], tags_any:Array=[], tags_none:Array=[]) -> void: 
	if starting_load_process: return
	if load_id == "" or type_id < 0: return
	starting_load_process = true
	stop_threads()

  # temporary variables
	var komi_arr:Array = []
	var images_per_page:int = Globals.settings.images_per_page
	var num_threads:int = Globals.settings.load_threads
	
	var current_sort:int = Globals.settings.current_sort
	var current_order:int = Globals.settings.current_order
	var current_page:Array = [current_page_number, load_id]
	
	thumbnail_path = Globals.settings.thumbnail_path

  # calculate offset
	offset = (current_page_number-1) * images_per_page

  # query database
	# these functions need fixing/replacing/cleaning
	var time:int = OS.get_ticks_usec()
	if type_id == Globals.TypeId.All:
		total_image_count = Database.GetTotalRowCountKomi() # very slow
		komi_arr = Database.LoadRangeKomi64FromTags(offset, images_per_page, tags_all, tags_any, tags_none, current_sort, current_order)
		queried_image_count = Database.GetTestQueryCount()
	elif type_id == Globals.TypeId.ImportGroup:
		total_image_count = Database.GetImportSuccessCountFromID(load_id) # very slow
		komi_arr = Database.GetImportGroupRange(load_id, offset, images_per_page, current_sort, current_order)
		queried_image_count = total_image_count
	else: pass # image_group
	
	Signals.emit_signal("update_button", total_image_count, load_id)
	total_page_count = ceil(float(queried_image_count)/float(images_per_page)) as int
	var s:String = String(queried_image_count) + " : %1.3f ms" % [float(OS.get_ticks_usec()-time)/1000.0]
	get_node("/root/main/Label2").text = s

  # remove from page history if needed
	if pages.size() >= Globals.settings.pages_to_store:
		var page_to_remove:Array = page_history.pop_front()
		var komi_to_remove:Array = pages[page_to_remove]
		lt.lock()
		for komi in komi_to_remove:
			var _had:bool = loaded_thumbnails.erase(komi)
		lt.unlock()
		var _had:bool = pages.erase(page_to_remove)
		# delete from C# here if relevant
		
  # add to page history if needed
	if not page_history.has(current_page):
		page_history.push_back(current_page)
	pages[current_page] = komi_arr

  # set page image count
	current_page_image_count = komi_arr.size()

	#starting_load_process = false # moved to _threadsafe_clear() to fix threading issue
	self.call_deferred("_threadsafe_clear", load_id, current_page_number, current_page_image_count, total_page_count, num_threads)

func stop_threads() -> void: 
	stopping_load_process = true
	for t in loading_threads.size():
		stop_thread(t)

func stop_thread(thread_id:int) -> void: 
	if loading_threads[thread_id].is_active() or loading_threads[thread_id].is_alive():	
		loading_threads[thread_id].wait_to_finish()

func _threadsafe_clear(load_id:String, page_number:int, image_count:int, page_count:int, num_threads:int) -> void: 
	starting_load_process = false
	sc.lock()
	if self.get_item_count() > 0:
		yield(get_tree(), "idle_frame")
		self.clear()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	for i in image_count:
		self.add_item("") # self.add_item(pages[[page_number, load_id]][i]) # 
		self.set_item_icon(i, icon_loading)
	page_label.text = String(page_number) + "/" + String(page_count)
	sc.unlock()
	prepare_thumbnail_loading(load_id, page_number, num_threads)

func prepare_thumbnail_loading(load_id:String, page_number:int, num_threads:int) -> void: 
	loading_threads.clear()
	for i in num_threads:
		loading_threads.append(Thread.new())

	ii.lock() ; item_index = 0 ; ii.unlock()
	ci.lock() 
	current_page_images.clear()
	current_page_images = pages[[page_number, load_id]].duplicate()
	ci.unlock()
	
	stopping_load_process = false
	for t in loading_threads.size():
		if not loading_threads[t].is_active():
			loading_threads[t].start(self, "_thread", t)
	starting_load_process = false

func _thread(thread_id:int) -> void:
	while not stopping_load_process:
		ci.lock()
		if current_page_images.empty():
			ci.unlock()
			break
		else:
			var komi64:String = current_page_images.pop_front()			
			Database.LoadOneKomi64(komi64) # loads metadata for this komi hash # not as threadsafe as the dev claims unfortunately
			ii.lock()
			var index:int = item_index
			item_index += 1
			ii.unlock()
			ci.unlock()
			load_thumbnail(komi64, index)
		OS.delay_msec(50)
	call_deferred("stop_thread", thread_id)

func load_thumbnail(komi64:String, index:int) -> void:
	lt.lock()
	if loaded_thumbnails.has(komi64):
		lt.unlock()
		if stopping_load_process: return
		_threadsafe_set_icon(komi64, index)
	else:
		lt.unlock()
		var f:File = File.new()
		var i:Image = Image.new()
		var p:String = thumbnail_path.plus_file(komi64)
		if f.file_exists(p + ".jpg"):
			var e:int = i.load(p + ".jpg")
			if e != OK:
				if ImageOp.IsImageCorrupt(p + ".jpg"):
					_threadsafe_set_icon(komi64, index, true)
					return
				else: i = ImageOp.LoadUnknownFormat(p)
		elif f.file_exists(p + ".png"):
			var e:int = i.load(p + ".png")
			if e != OK:
				if ImageOp.IsImageCorrupt(p + ".png"):
					_threadsafe_set_icon(komi64, index, true)
					return
				else: i = ImageOp.LoadUnknownFormatAlt(p + ".png")
		else: _threadsafe_set_icon(komi64, index, true)
		
		if stopping_load_process: return
		var it:ImageTexture = ImageTexture.new()
		it.create_from_image(i, 4) # FLAGS
		it.set_meta("komi64", komi64)
		
		lt.lock()
		loaded_thumbnails[komi64] = it
		lt.unlock()
		
		if stopping_load_process: return
		_threadsafe_set_icon(komi64, index)

# need to replace names and logic for this function (especially hardcoded all/import
func get_file_size(komi64:String, all:bool=false) -> String:
	# float is 64bit
	var size:float = 0.0
	if all: size = float(Database.GetFileSizeFromKomi(komi64))
	else: size = float(Database.GetFileSizeFromHash(komi64))
	
	if size < KB: return String(size) + " Bytes"
	elif size < MB: return "%1.2f KB" % [size/float(KB)]
	elif size < GB: return "%1.2f MB" % [size/float(MB)]
	else: return "%1.2f GB" % [size/float(GB)]

# should pass type_id all the way down the chain and use that for the second if check instead
func _threadsafe_set_icon(komi64:String, index:int, failed:bool=false) -> void: 
	var im_tex:Texture
	if failed: im_tex = icon_broken
	else:
		lt.lock()
		im_tex = loaded_thumbnails[komi64]
		lt.unlock()
	
	if stopping_load_process: return
	sc.lock()
	self.set_item_icon(index, im_tex)
	# need to merge these
	if (Globals.current_load_id != "all"): set_item_tooltip(index, "hash: " + komi64 + "\nsize: " + get_file_size(komi64))
	else: set_item_tooltip(index, "hash: " + komi64 + "\nsize: " + get_file_size(komi64, true))
	sc.unlock()


func prev_page_button_pressed() -> void: 
	if current_page_number == 1: return
	current_page_number -= 1
	Signals.emit_signal("page_changed")
	
func next_page_button_pressed() -> void:
	if current_page_number == total_page_count: return
	current_page_number += 1
	Signals.emit_signal("page_changed")

# this will store a dict of item_index:komi64 for selected items (can be used for batch tagging)
var selected_items:Dictionary = {}
#func image_selected(index:int) -> void:
func image_selected(index:int, selected:bool) -> void:
	selected_items.clear()
	var arr_index:Array = self.get_selected_items()
	
	for idx in arr_index: 
		var komi64:String = prepare_image(idx)
		if komi64 == "": continue
		selected_items[idx] = komi64
	
	var komi64:String = selected_items[index]
	var paths:Array = Database.GetKomiPathsFromDict(komi64)
	if !paths.empty(): 
		var f:File = File.new()
		for path in paths:
			if f.file_exists(path):
				# these 
				# the functions connected to these signals probably need to be threaded (with thread queue)
				Signals.emit_signal("load_image", path)
				Signals.emit_signal("load_tags", komi64, selected_items)
				break
	
func prepare_image(index:int) -> String:
	if index < 0: return ""
	if index >= self.get_item_count(): return ""	

	var im_tex:Texture = self.get_item_icon(index)
	if im_tex == null: return ""
	if im_tex is StreamTexture: return ""			# return if broken icon or loading icon
	
	var komi64:String = im_tex.get_meta("komi64")
	return komi64

func import_group_deleted(load_id:String) -> void:
	Database.DeleteImportInfoByID(load_id)
	Database.DropImportTableByID(load_id)
	
	
