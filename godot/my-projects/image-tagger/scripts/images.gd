extends ItemList

# TODO:
	# only remove from loaded_thumbnails when its page is removed from pages_queue
	# ensure that the C# Dictionary also clears its old pages
	# 

const icon_broken:StreamTexture = preload("res://assets/icon-broken.png")
const icon_loading:StreamTexture = preload("res://assets/buffer-01.png")

export (NodePath) var PrevPage ; onready var prev_page:Button = get_node(PrevPage)
export (NodePath) var NextPage ; onready var next_page:Button = get_node(NextPage)

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
var total_pages:int = 0					# total number of pages for the current query (total_image_count/images_per_page)
var current_page:int = 1				# the current page of images

var timer_delay:float = 0.3				# delay for allowed presses of prev/next buttons

var loading:bool = false				# 
var prepping:bool = false				# 
var stop_all:bool = false				# indicates to the threads that they should stop running

var lss:Dictionary = {					# stores user-defined settings for this script
	"images_per_page" : 100,
	"load_threads" : 5,
	"pages_to_store" : 5,
	"thumbail_folder" : "user://metadata/thumbnails" 
}

func stop_threads() -> void: 
	stop_all = true
	for t in load_threads: if t.is_alive() or t.is_active(): t.wait_to_finish()

func _ready() -> void: call_deferred("initial_load")
func initial_load() -> void:
	if loading: return
	loading = true
	
  # calculate total_pages and total_image_count
	total_image_count = Database.GetTotalRowCountKomi()
	total_pages = ceil(total_image_count as float / lss.images_per_page as float) as int
	
  # calculate offset (used for LoadRangeKomi64())
	offset = (current_page-1) * lss.images_per_page
	
  # determine which page the array will replace
	if pages.size() >= lss.pages_to_store:
		var page_to_remove:int = pages_queue.pop_front()
		var _had:bool = pages.erase(page_to_remove)
		
  # load the hashes from the database into a temp List
	Database.LoadRangeKomi64(offset, lss.images_per_page)
	
  # retrieve the hashes from the temp list and clear the list
	var arr:Array = Database.GetTempKomi64List()
	
  # store the array in pages
	pages_queue.append(current_page)
	pages[current_page] = arr
		
  #	calculate page_image_count (used for item generation)
	if (pages.empty()): page_image_count = lss.images_per_page 
	else: page_image_count = pages[current_page].size()
	
  # call next function
	self.call_deferred("_threadsafe_clear")

func _threadsafe_clear() -> void:
	sc.lock()
	if self.get_item_count() > 0:
		for i in page_image_count: self.set_item_icon(i, null)
		yield(get_tree(), "idle_frame")
		self.clear()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	for i in page_image_count:
		self.add_item(pages[current_page][i]) #self.add_item("") #
		self.set_item_icon(i, icon_loading)
	get_parent().get_node("page_buttons/Label").text = String(current_page) + "/" + String(total_pages)
	sc.unlock()
	prep_load_thumbnails()

func prep_load_thumbnails() -> void: 
	if prepping: return
	prepping = true
	stop_threads()
	load_threads.clear()
	for i in lss.load_threads: load_threads.append(Thread.new())
	
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
		var e:int = i.load(lss.thumbail_folder.plus_file(komi64) + ".jpg")
		if e != OK: return
		if stop_all: return
		
		var it:ImageTexture = ImageTexture.new()
		it.create_from_image(i, 4) # flags
		it.set_meta("komi64", komi64)
		
		lt.lock()
		loaded_thumbnails[komi64] = it
		lt.unlock()
		
		if stop_all: return
		_threadsafe_set_icon(komi64, index)
		
func _threadsafe_set_icon(komi64:String, index:int) -> void:
	lt.lock()
	var it:ImageTexture = loaded_thumbnails[komi64]
	lt.unlock()
	if stop_all: return
	
	sc.lock()
	set_item_icon(index, it)
	sc.unlock()

func _on_images_item_selected(index:int) -> void:
	var it:Texture = get_item_icon(index)
  # return if the user clicked a buffering image
	if it is StreamTexture: return
	var komi64:String = it.get_meta("komi64")
	var paths:Array = Database.GetKomiPathsFromDict(komi64)
	Signals.emit_signal("load_image", paths[0])

func _on_Timer_timeout() -> void:
	prev_page.disabled = false
	next_page.disabled = false

func _on_prev_page_button_up() -> void:	
	if loading: return
	if current_page == 1: return
	
	prev_page.disabled = true
	next_page.disabled = true
	$Timer.start(timer_delay)
	
	current_page -= 1
	initial_load()

func _on_next_page_button_up() -> void:
	if loading: return
	if current_page == total_pages: return

	prev_page.disabled = true
	next_page.disabled = true
	$Timer.start(timer_delay)
	
	current_page += 1
	initial_load()

