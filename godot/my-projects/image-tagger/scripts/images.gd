extends ItemList

const icon_broken:StreamTexture = preload("res://assets/icon-broken.png")
const icon_loading:StreamTexture = preload("res://assets/buffer-01.png")

export (NodePath) var PrevPage ; onready var prev_page:Button = get_node(PrevPage)
export (NodePath) var NextPage ; onready var next_page:Button = get_node(NextPage)

onready var sc:Mutex = Mutex.new() # scene
onready var fi:Mutex = Mutex.new() # file index
onready var pf:Mutex = Mutex.new() # page_files
onready var lt:Mutex = Mutex.new() # loaded_thumbnails

# program freezes when spamming the next button
# I think I am limited by how quickly you can start/wait_to_finish threads
# Solution 1: start a timer after pressing the button, disable the button until it times out
# Solution 2: rewrite the threads to run in a busy loop and wait for thumbnails to process

var page_files:Array = []				# an array of komi64s representing the thumbnails on the current page (used as a queue)
var filtered_files:Array = []			# a subset of the komi64s stored in the database (current 1000 at a time)
var loaded_thumbnails:Dictionary = {}	# a dictionary storing the thumbnails themselves as a komi64:ImageTexture key:value pair
var file_index:int = 0					# an integer storing the index of the current thumbnail
		
var load_threads:Array = []				# an array of threads used for loading thumbnails
var ff_index:int = 0					# the index in filtered_files()
var offset:int = 0						# the index in the database (offset=200 means that 201-1200 are in filtered_files)
var total_image_count:int = 0
var page_image_count:int = 0			# the number of images that are supposed to be loaded for the current page (cannot use page_files.size() because it is treated as a queue)
# var page_count:int = 0				# the total number of pages, based on images_per_page
var total_pages:int = 0
var current_page:int = 1
var last_page_image_count:int = 0 		# stores the number of images present on the last page of filtered_files (ie 200 if 200/page and 1000 images)
										# important for situations where for example: 200/page and 467 loaded (last_page_image_count = 67)

# need to get a count from the database
# for now, just going to work with the already loaded komi64s and ignore the database

var loading:bool = false
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

func _ready() -> void: call_deferred("initial_load", 1000, true)
func initial_load(num_hashes:int, forward:bool) -> void:
	if loading: return
	loading = true
	
	total_image_count = Database.GetTotalRowCountKomi()
	total_pages = ceil(total_image_count as float / lss.images_per_page as float) as int
	Database.LoadRangeKomi64(offset, num_hashes) 
	
	if forward: offset += num_hashes
	else: offset -= num_hashes

	if forward and current_page < total_pages:
		if (filtered_files.size() > 0): 
			filtered_files = filtered_files.slice(lss.images_per_page, filtered_files.size()-1)
		filtered_files.append_array(Database.GetTempKomi64List()) 
		
	elif !forward and current_page > 1:
		if (filtered_files.size() > 0): filtered_files = filtered_files.slice(0, filtered_files.size()-last_page_image_count-1);
		var tmp:Array = Database.GetTempKomi64List()
		tmp.append_array(filtered_files)
		filtered_files = tmp
	
	page_image_count = int(min(lss.images_per_page, filtered_files.size()))
	self.call_deferred("test")

func test() -> void:
	sc.lock()
	if self.get_item_count() > 0:
		for i in page_image_count: self.set_item_icon(i, null)
		yield(get_tree(), "idle_frame")
		self.clear()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	for i in page_image_count:
		self.add_item(filtered_files[i]) #self.add_item("") #
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
	
	fi.lock() ; file_index = 0; fi.unlock()
	lt.lock() ; loaded_thumbnails.clear() ; lt.unlock()
	pf.lock()
	page_files.clear()
	page_files = filtered_files.slice(ff_index, int(min(ff_index+lss.images_per_page-1, filtered_files.size()-1))) 
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
	var it:Texture = get_item_icon(index)
	if it is StreamTexture: return
	var komi64:String = it.get_meta("komi64")
	var paths:Array = Database.GetKomiPathsFromDict(komi64)
	#for p in paths: print(p)
	Signals.emit_signal("load_image", paths[0])

func _on_Timer_timeout() -> void:
	prev_page.disabled = false
	next_page.disabled = false

func _on_prev_page_button_up() -> void:	
#func _on_prev_page_pressed() -> void:
	# if page == 1: return
	# stop the thumbnail loading thread(s)
	prev_page.disabled = true
	next_page.disabled = true
	$Timer.start(0.5)


func _on_next_page_button_up() -> void:
#func _on_next_page_pressed() -> void:
	if loading: return
	if current_page == total_pages: return

	prev_page.disabled = true
	next_page.disabled = true
	$Timer.start(0.5)
	
	current_page += 1
	initial_load(lss.images_per_page, true)

