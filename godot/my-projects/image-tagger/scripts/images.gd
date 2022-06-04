extends ItemList

# TODO : rename komihash, komihashes to komi64
# TODO : create a buffer for the last X full images to be loaded
# TODO : add use_filter button, remove choose image button
# TODO : add the hq pixel filter shader
# TODO : replace all instances of komi64 with strings
# TODO : add page buttons and logic to this list (load next/previous/page# lss.images_per_page)
# TODO : remove komi64s from filtered_files and query new ones when changing pages;
	# ie if go to page 2, remove the first 200 and load 200 more into the program
	# need to keep careful track of the index during this
	# need to ensure threads completely stop and any relevant variables are reset before changing page

const icon_broken:StreamTexture = preload("res://assets/icon-broken.png")
const icon_loading:StreamTexture = preload("res://assets/buffer-01.png")

onready var sc:Mutex = Mutex.new() # scene
onready var fi:Mutex = Mutex.new() # file index
onready var pf:Mutex = Mutex.new() # page_files
onready var lt:Mutex = Mutex.new() # loaded_thumbnails

var page_files:Array = []				# an array of komi64s representing the thumbnails on the current page (used as a queue)
var filtered_files:Array = []			# an array of all komi64s in the Database (this will need to be changed to be a subset of the hashes)
var loaded_thumbnails:Dictionary = {}	# a dictionary storing the thumbnails themselves as a komi64:ImageTexture key:value pair
var file_index:int = 0					# an integer storing the index of the current thumbnail
		
var load_threads:Array = []				# an array of threads used for loading thumbnails
var curr_index:int = 0					# the index in filtered_files(), will be changed by next/prev page buttons; will likely change if/when I start retrieving a subset of komi64s from Database
var page_image_count:int = 0			# the number of images that are supposed to be loaded for the current page (cannot use page_files.size() because it is treated as a queue)
var page_count:int = 0					# the total number of pages, based on images_per_page

var prepping:bool = false
var stop_all:bool = false

var lss:Dictionary = {
	"images_per_page" : 200,
	"load_threads" : 5,
	"thumbail_folder" : "user://metadata/thumbnails" 
}

func stop_threads() -> void: 
	stop_all = true
	for t in load_threads: if t.is_alive() or t.is_active(): t.wait_to_finish()

func _ready() -> void: call_deferred("initial_load")
func initial_load() -> void:
	Database.LoadRangeKomi64(0, 1000) # load first 1000 hashes into Dictionary (entirely unsorted/unfiltered for now)
	filtered_files = Database.GetAllKomi64FromDict()
	page_count = ceil(filtered_files.size() as float / lss.images_per_page as float) as int
	page_image_count = int(min(lss.images_per_page, filtered_files.size()))
	for i in page_image_count: self.add_item("") #self.add_item(filtered_files[i])
	
	prep_load_thumbnails()

func prep_load_thumbnails() -> void: 
	if prepping: return
	prepping = true
	stop_all = true
	
	for t in load_threads: if t.is_active() or t.is_alive(): t.wait_to_finish()
	load_threads.clear()
	for i in lss.load_threads: load_threads.append(Thread.new())
	
	fi.lock() ; file_index = 0; fi.unlock()
	lt.lock() ; loaded_thumbnails.clear() ; lt.unlock()
	pf.lock()
	page_files.clear()
	page_files = filtered_files.slice(curr_index, int(min(curr_index+lss.images_per_page-1, filtered_files.size()-1))) 
	pf.unlock()
	
	stop_all = false
	for t in load_threads.size(): if not load_threads[t].is_active(): load_threads[t].start(self, "_thread", t)	
	prepping = false

func _thread(_thread_id:int) -> void:
	while not stop_all:
		pf.lock()
		if page_files.empty():
			pf.unlock()
			break
		else:
			fi.lock()
			var komi64:String = page_files.pop_front()
			var index:int = file_index
			file_index += 1
			fi.unlock()
			pf.unlock()
			load_thumbnail(komi64, index)
		OS.delay_msec(50)

func load_thumbnail(komi64:String, index:int) -> void: 
	lt.lock()
	if loaded_thumbnails.has(komi64):
		lt.unlock()
		if stop_all:return
		threadsafe_set_icon(komi64, index)
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
		threadsafe_set_icon(komi64, index)
		
func threadsafe_set_icon(komi64:String, index:int) -> void:
	lt.lock()
	var it:ImageTexture = loaded_thumbnails[komi64]
	lt.unlock()
	if stop_all: return
	
	sc.lock()
	set_item_icon(index, it)
	# set text
	sc.unlock()

func _on_images_item_selected(index:int) -> void:
	var it:ImageTexture = get_item_icon(index)
	var komi64:String = it.get_meta("komi64")
	var paths:Array = Database.GetKomiPathsFromDict(komi64)
	#for p in paths: print(p)
	Signals.emit_signal("load_image", paths[0])
	
