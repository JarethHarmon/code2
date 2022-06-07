extends Node

# calls function that starts scanning for images, calculating hash, creating thumbnail, storing metadata in database
# currently does this all on a single additional thread (still fairly fast)

func get_signed_komi_hash(path:String) -> int: 
	var gob:Gob = Gob.new()
	var komi:int = gob.get_signed_komi_hash(path)
	gob.queue_free()
	return komi
func get_unsigned_komi_hash(path:String) -> String: 
	var gob:Gob = Gob.new()
	var komi:String = gob.get_unsigned_komi_hash(path)
	gob.queue_free()
	return komi

# var import_thread:Thread = null
onready var import_thread:Thread = Thread.new()
onready var import_mutex:Mutex = Mutex.new()

var queue:Array = []
var importer_active:bool = false

var time:int

func start_importer() -> void:
	if (importer_active): return
	if (import_mutex.try_lock() != OK): return
	if (import_thread.is_alive()): return
	import_mutex.lock()
	var _err:int = import_thread.start(self, "_thread")
	importer_active = true

func queue_append(import_folder:String, recursive:bool=true) -> void:
	print("QUEUE (R=" + ("t" if recursive else "f") + "):   ", import_folder) 
	queue.append([import_folder, recursive])
	if (!importer_active): start_importer()

func _thread() -> void:
	while not queue.empty():
		time = OS.get_ticks_msec()
		var import:Array = queue.pop_front()
		ImageOp.ImportImages(import[0], import[1])
		OS.delay_msec(50)
	call_deferred("_done")
	
func _done() -> void:
	if import_thread.is_alive() or import_thread.is_active(): import_thread.wait_to_finish()
	importer_active = false
	import_mutex.unlock()
	print("DONE, took %d ms \n" % [OS.get_ticks_msec() - time - 50])
	Signals.emit_signal("image_import_finished")
	
