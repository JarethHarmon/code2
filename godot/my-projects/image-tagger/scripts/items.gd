extends ItemList

# Constants
const icon_broken:StreamTexture = preload("res://assets/icon-broken.png")
const icon_loading:StreamTexture = preload("res://assets/buffer-01.png")

# Exported NodePaths

# Onready Vars
onready var sc:Mutex = Mutex.new() # scene
onready var fi:Mutex = Mutex.new() # file index
onready var pf:Mutex = Mutex.new() # page_files
onready var lt:Mutex = Mutex.new() # loaded_thumbnails

# Variables
var page_files:Array = []				# an array of SHA256s representing the thumbnails on the current page (used as a queue)
var filtered_files:Array = []			# an array of all SHA256s in the Database (this will need to be changed to be a subset of the hashes)
var loaded_thumbnails:Dictionary = {}	# a dictionary storing the thumbnails themselves as a SHA256:ImageTexture key:value pair
var file_index:int = 0					# an integer storing the index of the current thumbnail
		
var load_threads:Array = []				# an array of threads used for loading thumbnails
var curr_index:int = 0

var prepping:bool = false
var stop_all:bool = false

var lss:Dictionary = {
	"files_per_page" : 100,
	"load_threads" : 5,
	"thumbail_folder" : "user://thumbnails"
}

func _notification(what) -> void:
# on program close, waits for threads to stop, closes the database and then closes the program
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST: 
		stop_all = true
		for t in load_threads: if t.is_alive() or t.is_active(): t.wait_to_finish()
		# CLOSE DATABASE
		get_tree().quit()

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	var e:int = Directory.new().make_dir_recursive(lss.thumbail_folder)
	call_deferred("initial_load")

func initial_load() -> void:
	# filtered_files = Database.GetSHAs()
	pass

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
	page_files = filtered_files.slice(curr_index, min(curr_index+lss.files_per_page-1, filtered_files.size()-1)) 
	pf.unlock()
	
	stop_all = false
	for t in load_threads.size(): if not load_threads[t].is_active(): load_threads[t].start(self, "_thread", t)	
	prepping = false

func _thread(thread_id:int) -> void:
	var stop:bool = false
	while not stop and not stop_all:
		pf.lock()
		if not page_files.empty():
			fi.lock() 
			var sha256:String = page_files.pop_front()
			var index:int = file_index 
			file_index += 1 
			fi.unlock() 
			pf.unlock()
			load_thumbnail(sha256, index)
		else:
			pf.unlock()
			stop = true
		OS.delay_msec(50)

func load_thumbnail(sha256:String, index:int) -> void: pass















