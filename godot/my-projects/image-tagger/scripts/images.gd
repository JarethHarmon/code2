extends ItemList

const icon_broken:StreamTexture = preload("res://assets/icon-broken.png")
const icon_loading:StreamTexture = preload("res://assets/buffer-01.png")

enum SortBy { FileHash, FilePath, FileSize, FileCreationUtc }

export (NodePath) var PrevPage ; onready var prev_page:Button = get_node(PrevPage)
export (NodePath) var NextPage ; onready var next_page:Button = get_node(NextPage)
export (NodePath) var Refresh ; onready var refresh:Button = get_node(Refresh)

onready var sc:Mutex = Mutex.new() 		# scene
onready var fi:Mutex = Mutex.new() 		# file index
onready var pf:Mutex = Mutex.new() 		# page_files
onready var lt:Mutex = Mutex.new() 		# loaded_thumbnails

var pages_queue:Array = [] 				# fifo queue, stores page_numbers (current_page)
var pages:Dictionary = {} 				# page_number : [komihash]
var page_files:Array = []				# an array of komi64s representing the thumbnails on the current page (used as a queue)
var loaded_thumbnails:Dictionary = {}	# a dictionary storing the thumbnails themselves as a komi64:ImageTexture key:value pair
var item_index:int = 0					# an integer storing the index of the current item
		
var load_threads:Array = []				# an array of threads used for loading thumbnails
var offset:int = 0						# the index in the database (offset=200 means that 201-1200 are in filtered_files)
var total_image_count:int = 0			# the total number of images from the current query (num rows in the database)
var page_image_count:int = 0			# the number of images that are supposed to be loaded for the current page (cannot use page_files.size() because it is treated as a queue)
var total_pages:int = 1					# total number of pages for the current query (total_image_count/images_per_page)
var current_page:int = 1				# the current page of images
var current_import_id:String = ""		# 

var timer_delay:float = 0.3				# delay for allowed presses of prev/next buttons

var loading:bool = false				# 
var prepping:bool = false				# 
var stop_all:bool = false				# indicates to the threads that they should stop running

func stop_threads() -> void: 
	stop_all = true
	for t in load_threads: if t.is_alive() or t.is_active(): t.wait_to_finish()

func _ready() -> void: 
	var _err:int = Signals.connect("image_import_finished", self, "_on_refresh_button_up")
	_err = Signals.connect("import_button_pressed", self, "button_import_clicked")
	#call_deferred("initial_load")

func button_import_clicked(import_id:String):
	current_page = 1
	total_pages = 1
	# need to call threadsafe clear of pages_queue, etc
	# need to replace with queue of images from any import / page
	total_image_count = 0
	current_import_id = import_id
	load_import(import_id)

# probably needs to be split into several functions; currently hardcoded to only use imports (eventually needs to be able to also check all images (with appropriate filters, etc))
#func initial_load() -> void:
func load_import(import_id:String) -> void:
	if loading: return
	if import_id == "": return
	loading = true	
	
	stop_threads() # I realized why there was occasional thread-related errors
	
  # calculate total_pages and total_image_count
	#total_image_count = Database.GetTotalRowCountKomi()
	total_image_count = Database.GetImportSuccessCountFromID(import_id)#Database.GetImportCount(import_id)
	total_pages = ceil(total_image_count as float / Settings.settings.images_per_page as float) as int
	
  # calculate offset (used for LoadRangeKomi64())
	offset = (current_page-1) * Settings.settings.images_per_page
	
  # determine which page the array will replace
	if pages.size() >= Settings.settings.pages_to_store:
		var page_to_remove:int = pages_queue.pop_front()
		# should be entirely unnecessary with current implementation
		#Database.RemoveKomi64sFromDict(pages[page_to_remove])
		var _had:bool = pages.erase(page_to_remove)
		
  # load the hashes from the database into a temp List
	#var count:int
	#var tmp:int = Database.GetCurrentImportListCount(import_id)
	#if tmp < 0: count = Settings.settings.images_per_page # this is probably not a good thing to do, not sure how to error out of this function right now though
	#else: count = int(min(tmp, Settings.settings.images_per_page))
	#var arr:Array = Database.GetImportListSubsetFromDatabase(import_id, offset, count)
	var arr:Array = Database.GetImportGroupRange(import_id, offset, Settings.settings.images_per_page, SortBy.FileHash, false)
	#Database.LoadRangeKomi64(offset, lss.images_per_page)
	
  # retrieve the hashes from the temp list and clear the list
	#var arr:Array = Database.GetTempKomi64List()
	
  # store the array in pages
	if not pages_queue.has(current_page): pages_queue.append(current_page)
	pages[current_page] = arr
		
  #	calculate page_image_count (used for item generation)
	if (pages.empty()): page_image_count = Settings.settings.images_per_page 
	else: page_image_count = pages[current_page].size()
	
  # call next function
	self.call_deferred("_threadsafe_clear")

func _threadsafe_clear() -> void:
	sc.lock()
	if self.get_item_count() > 0:
		#for i in page_image_count: self.set_item_icon(i, null)
		yield(get_tree(), "idle_frame")
		self.clear()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	for i in page_image_count:
		self.add_item(pages[current_page][i]) #self.add_item("") #self.add_item("") #
		self.set_item_icon(i, icon_loading)
	get_parent().get_node("page_buttons/Label").text = String(current_page) + "/" + String(total_pages)
	sc.unlock()
	prep_load_thumbnails()

func prep_load_thumbnails() -> void: 
	if prepping: return
	prepping = true
	stop_threads()
	load_threads.clear()
	for i in Settings.settings.load_threads: load_threads.append(Thread.new())
	
	fi.lock() ; item_index = 0; fi.unlock()
	lt.lock() ; loaded_thumbnails.clear() ; lt.unlock()
	
	pf.lock()
	page_files.clear()
	page_files = pages[current_page]
	pf.unlock()
	
	stop_all = false
	for t in load_threads.size(): if not load_threads[t].is_active(): load_threads[t].start(self, "_thread", t)	
	prepping = false
	loading = false

func _thread(_thread_id:int) -> void:
	while not stop_all:
		pf.lock()
		if page_files.empty():
			pf.unlock()
			break
		else:
			fi.lock()
			var komi64:String = page_files.pop_front()
			#var now = OS.get_ticks_msec()
			Database.LoadOneKomi64(komi64) # probably a better place to put this ; need to unload it as well
			#print(String(_thread_id), " :: get komi64 from komi64 database: ", OS.get_ticks_msec()-now)
			var index:int = item_index
			item_index += 1
			fi.unlock()
			pf.unlock()
			#now = OS.get_ticks_msec()
			load_thumbnail(komi64, index)
			#print(String(_thread_id), " :: load thumbnail: ", OS.get_ticks_msec()-now)
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
		if e != OK: 
			var p:String = ProjectSettings.globalize_path(Settings.settings.thumbnail_path).plus_file(komi64) + ".jpg"
			if ImageOp.IsImageCorrupt(p):
				print("corrupt ::: ", p) 
				_threadsafe_set_icon(komi64, index, true)
				return
			else: i = ImageOp.LoadUnknownFormatAlt(p)
		if stop_all: return
		
		var it:ImageTexture = ImageTexture.new()
		it.create_from_image(i, 4) # flags
		it.set_meta("komi64", komi64)
		
		lt.lock()
		loaded_thumbnails[komi64] = it
		lt.unlock()
		
		if stop_all: return
		_threadsafe_set_icon(komi64, index)
		
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
	sc.unlock()

func _on_images_item_selected(index:int) -> void:
	if index < 0: return
	var im_tex:Texture = get_item_icon(index)
	if im_tex == null: return
	if im_tex is StreamTexture: return
	
	var komi64:String = im_tex.get_meta("komi64")
	var paths:Array = Database.GetKomiPathsFromDict(komi64)
	Signals.emit_signal("load_image", paths[0])

func _on_Timer_timeout() -> void: pass
#	refresh.disabled = false
#	prev_page.disabled = false
#	next_page.disabled = false

func _on_prev_page_button_up() -> void:	
	if loading: return
	if current_page == 1: return
	
#	refresh.disabled = true
#	prev_page.disabled = true
#	next_page.disabled = true
#	$Timer.start(timer_delay)
	
	current_page -= 1
	#initial_load()
	load_import(current_import_id)

func _on_next_page_button_up() -> void:
	if loading: return
	if current_page == total_pages: return
	
#	refresh.disabled = true
#	prev_page.disabled = true
#	next_page.disabled = true
#	$Timer.start(timer_delay)
	
	current_page += 1
	#initial_load()
	load_import(current_import_id)

# move refresh button to image_list.tscn
func _on_refresh_button_up() -> void:
	if loading: return
	
#	refresh.disabled = true
#	prev_page.disabled = true
#	next_page.disabled = true
#	$Timer.start(timer_delay)
	
	#initial_load()
	load_import(current_import_id)
