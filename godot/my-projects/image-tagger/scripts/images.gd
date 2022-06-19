extends ItemList

const icon_broken:StreamTexture = preload("res://assets/icon-broken.png")
const icon_loading:StreamTexture = preload("res://assets/buffer-01.png")

var current_sort:int = Globals.SortBy.FileHash
var ascending:bool = true

export (NodePath) var IncludeAllBar ; onready var include_all_bar:LineEdit = get_node(IncludeAllBar)
export (NodePath) var IncludeOneBar ; onready var include_one_bar:LineEdit = get_node(IncludeOneBar)
export (NodePath) var ExcludeAllBar ; onready var exclude_all_bar:LineEdit = get_node(ExcludeAllBar)
export (NodePath) var SearchButton ; onready var search_button:Button = get_node(SearchButton)

onready var sc:Mutex = Mutex.new() 		# scene mutex
onready var fi:Mutex = Mutex.new() 		# file index mutex
onready var pf:Mutex = Mutex.new() 		# page_files mutex
onready var lt:Mutex = Mutex.new() 		# loaded_thumbnails mutex

var page_history:Array = []				# fifo queue, stores page numbers
var pages:Dictionary = {}				# [page_number, import_id] : [komihash]
var current_page_images:Array = []		# [komihash], queue for loading current page
var loaded_thumbnails:Dictionary = {}	# komi64 : ImageTexture, stores the actual thumbnails
var loading_threads:Array = []			# array of threads used for loading thumbnails

var item_index:int = 0					# index in the item_list 
var offset:int = 0						# offset for querying the database
var current_page_number:int = 1			# the current page
var total_page_count:int = 1			# the total number of pages
var total_image_count:int = 0			# the total number of images
var queried_image_count:int = 0			# the total number of images found by the most recent query
var page_image_count:int = 0			# the number of images for the current page
var current_import_id:String = ""		# the import_id for the current group

var loading:bool = false				# whether the threads are currently loading
var stop_all:bool = false				# whether the threads should stop

func stop_threads() -> void:
	stop_all = true
	for t in loading_threads:
		if t.is_alive() or t.is_active():
			t.wait_to_finish()

func _ready() -> void:
	var _err:int = Signals.connect("image_import_finished", self, "_on_refresh_button_up")
	_err = Signals.connect("import_button_pressed", self, "import_group_button_pressed")
	_err = Signals.connect("delete_pressed", self, "import_group_button_delete")
	_err = Signals.connect("load_all_images", self, "all_button_pressed")

func import_group_button_delete(import_id:String) -> void:
	if current_import_id == import_id:
		stop_threads()
		self.clear()
	Database.DeleteImportInfoByID(import_id)
	Database.DropImportTableByID(import_id)

func import_group_button_pressed(import_id:String) -> void:
	current_page_number = 1				# consider keeping page_number in history as well
	total_page_count = 1
	total_image_count = 0
	current_import_id = import_id
	load_import_group(import_id)		# not sure if I will use "" to represent all, or just create another function for that

func all_button_pressed() -> void:
	current_page_number = 1
	total_page_count = 1
	total_image_count = 0
	current_import_id = "all"
	
	var text_in_all:String = include_all_bar.text
	var text_in_one:String = include_one_bar.text
	var text_ex_all:String = exclude_all_bar.text
	
	var tags_in_all:Array = text_in_all.split(",", false) # false prevents [""] from happening when splitting an empty string
	var tags_in_one:Array = text_in_one.split(",", false) 
	var tags_ex_all:Array = text_ex_all.split(",", false) 
	
	load_import_group("all", tags_in_all, tags_in_one, tags_ex_all)



func load_import_group(import_id:String, tag_in_all:Array=[], tag_in_one:Array=[], tag_ex_all:Array=[]) -> void:
	if loading: return
	if import_id == "": return
	loading = true
	stop_threads()
	
	if import_id == "all":
		total_image_count = Database.GetTotalRowCountKomi()
	else:
		total_image_count = Database.GetImportSuccessCountFromID(import_id)
	Signals.emit_signal("update_button", total_image_count, import_id)
	total_page_count = ceil(total_image_count as float / Settings.settings.images_per_page as float) as int
	
	offset = (current_page_number-1) * Settings.settings.images_per_page
	
	if pages.size() >= Settings.settings.pages_to_store:
		var page_to_remove:Array = page_history.pop_front()
		
		var komi_to_remove:Array = pages[page_to_remove]
		lt.lock()
		for komi in komi_to_remove: var _had:bool = loaded_thumbnails.erase(komi)
		lt.unlock()
		var _had:bool = pages.erase(page_to_remove)
		# delete from C# here if needed (for now it is fast enough not to need to save a history on c#)

	var komi_arr:Array = []
	if import_id == "all":
		var tmp = Database.LoadRangeKomi64FromTags(offset, Settings.settings.images_per_page, tag_in_all, tag_in_one, tag_ex_all, current_sort, ascending)
		var t = OS.get_ticks_msec()
		var count:int = Database.GetQueryCountFromTags(tag_in_all, tag_in_one, tag_ex_all)
		#get_node("/root/main/Label2").text = String(OS.get_ticks_msec()-t) + " ms"
		print(count)
		if tmp != null: komi_arr = tmp
	else:
		komi_arr = Database.GetImportGroupRange(import_id, offset, Settings.settings.images_per_page, current_sort, ascending)
	
	if not page_history.has([current_page_number, import_id]):
		page_history.push_back([current_page_number, import_id])
	pages[[current_page_number, import_id]] = komi_arr
	
	if pages.empty(): page_image_count = 0
	else: page_image_count = pages[[current_page_number, import_id]].size()
	
	# print("LIG : ", current_page_number, ":", pages.has([current_page_number, import_id]))

	self.call_deferred("_threadsafe_clear", import_id, current_page_number)

func _threadsafe_clear(import_id:String, page_number:int) -> void:
	sc.lock()
	if self.get_item_count() > 0:
		yield(get_tree(), "idle_frame")
		self.clear()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	for i in page_image_count:
		self.add_item("") #self.add_item(pages[[page_number, import_id]][i]) #
		self.set_item_icon(i, icon_loading)
	# should get a proper node reference instead here
	get_parent().get_node("page_buttons/Label").text = String(page_number) + "/" + String(total_page_count)
	sc.unlock()
	prep_load_thumbnails(import_id, page_number)

func prep_load_thumbnails(import_id:String, page_number:int) -> void: 
	loading_threads.clear()
	for i in Settings.settings.load_threads: loading_threads.append(Thread.new())
	
	fi.lock() ; item_index = 0; fi.unlock()	
	current_page_images.clear()
	# print("PLT : ", page_number, ":", pages.has([page_number, import_id]))
	current_page_images = pages[[page_number, import_id]].duplicate() # clears the original if not duplicated here (no idea why though, it should not do this)
	
	# if stop_all: return
	
	stop_all = false
	for t in loading_threads.size(): if not loading_threads[t].is_active(): loading_threads[t].start(self, "_thread", t)	
	loading = false

func _thread(_thread_id:int) -> void:
	while not stop_all:
		pf.lock()
		if current_page_images.empty():
			pf.unlock()
			break
		else:
			fi.lock()
			var komi64:String = current_page_images.pop_front()
			Database.LoadOneKomi64(komi64) # probably a better place to put this ; need to unload it as well
			var index:int = item_index
			item_index += 1
			fi.unlock()
			pf.unlock()
			load_thumbnail(komi64, index)
		OS.delay_msec(50)

func load_thumbnail(komi64:String, index:int) -> void: 
	lt.lock()
	if loaded_thumbnails.has(komi64):
		lt.unlock()
		if stop_all:return
		_threadsafe_set_icon(komi64, index)
	else:
		lt.unlock()
		var i:Image = Image.new()
		var e:int = i.load(Settings.settings.thumbnail_path.plus_file(komi64) + ".jpg")
		if e != OK: e = i.load(Settings.settings.thumbnail_path.plus_file(komi64) + ".png")
		if e != OK:
			var p:String = Settings.settings.thumbnail_path.plus_file(komi64) + ".jpg"
			if ImageOp.IsImageCorrupt(p):
				#print("corrupt ::: ", p) 
				_threadsafe_set_icon(komi64, index, true)
				return
			else: i = ImageOp.LoadUnknownFormatAlt(p)
		if stop_all: return
		
		var it:ImageTexture = ImageTexture.new()
		it.create_from_image(i, 4) #0# flags
		it.set_meta("komi64", komi64)
		
		lt.lock()
		loaded_thumbnails[komi64] = it
		lt.unlock()
		
		if stop_all: return
		_threadsafe_set_icon(komi64, index)

const kb:int = 1024
func get_file_size(komi64:String, all:bool=false) -> String:
	# float is 64bit and I would not expect image file sizes to be approaching the limits of that (and I see no reason to attack a local-only image application)
	var size:float = 0.0
	if all: size = float(Database.GetFileSizeFromKomi(komi64))
	else: size = float(Database.GetFileSizeFromHash(komi64))
	if size < kb: return String(size) + " Bytes"
	elif size < kb*kb: return "%1.2f KB" % [size/float(kb)]
	elif size < kb*kb*kb: return "%1.2f MB" % [size/float(kb*kb)]
	else: return "%1.2f GB" % [size/float(kb*kb*kb)]
	
func _threadsafe_set_icon(komi64:String, index:int, failed:bool=false) -> void:
	var im_tex:Texture
	if failed: im_tex = icon_broken
	else:
		lt.lock()
		im_tex = loaded_thumbnails[komi64]
		lt.unlock()
		
	if stop_all: return
	sc.lock()
	set_item_icon(index, im_tex)
	# should try to make these 1 function (additional argument if needed)
	if (current_import_id != "all"): set_item_tooltip(index, "hash: " + komi64 + "\nsize: " + get_file_size(komi64))
	else: set_item_tooltip(index, "hash: " + komi64 + "\nsize: " + get_file_size(komi64, true))
	sc.unlock()

func _on_images_item_selected(index:int) -> void:
	if index < 0: return
	var im_tex:Texture = get_item_icon(index)
	if im_tex == null: return
	if im_tex is StreamTexture: return
	
	var komi64:String = im_tex.get_meta("komi64")
	var paths:Array = Database.GetKomiPathsFromDict(komi64)
	if !paths.empty(): Signals.emit_signal("load_image", paths[0]) # fix crash if paths empty
	Signals.emit_signal("load_tags", komi64)

func _on_Timer_timeout() -> void: pass

func _on_prev_page_button_up() -> void:	
	if current_page_number == 1: return
	current_page_number -= 1
	load_import_group(current_import_id)

func _on_next_page_button_up() -> void:
	if current_page_number == total_page_count: return
	current_page_number += 1
	load_import_group(current_import_id)

# move refresh button to image_list.tscn
func _on_refresh_button_up() -> void: load_import_group(current_import_id)

func _on_sort_by_item_selected(index:int) -> void:
	current_sort = index
	if current_import_id == "all": all_button_pressed()
	else: import_group_button_pressed(current_import_id)

func _on_ascend_descend_item_selected(index) -> void:
	if (index == 1): ascending = false
	else: ascending = true
	if current_import_id == "all": all_button_pressed()
	else: import_group_button_pressed(current_import_id)


func _on_search_button_button_up() -> void:
	var text_in_all:String = include_all_bar.text
	var text_in_one:String = include_one_bar.text
	var text_ex_all:String = exclude_all_bar.text
	
	var tags_in_all:Array = text_in_all.split(",", false) # false prevents [""] from happening when splitting an empty string
	var tags_in_one:Array = text_in_one.split(",", false) 
	var tags_ex_all:Array = text_ex_all.split(",", false) 
	
	load_import_group(current_import_id, tags_in_all, tags_in_one, tags_ex_all)
	
	#Database.LoadRangeKomi64FromTags(0, 100, tags_in_all, tags_in_one, tags_ex_all, Globals.SortBy.FileHash, ascending)

	# I need to check whether current_import_id == ""
	# if not, then I need to query within the confines of the current import (?) (db_import does not include tags though, so not certain how to do this)
	# if it does, I need to query all images (what it is doing currently)
	# then I need to call a load function to get started; if current_import_id != "" then it will just filter the current import
	# otherwise it will call a separate function that loads from all images
	
