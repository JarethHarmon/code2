extends Node

# calls function that starts scanning for images, calculating hash, creating thumbnail, storing metadata in database
# currently does this all on a single additional thread (still fairly fast)

# returns unsigned komi hash as String
func get_komi_hash(path:String) -> String: 
	var gob:Gob = Gob.new()
	var komi:String = gob.get_komi_hash(path)
	gob.queue_free()
	return komi

# var import_thread:Thread = null
onready var import_thread:Thread = Thread.new()
onready var import_mutex:Mutex = Mutex.new()

var queue:Array = []
var importer_active:bool = false

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
		var time:int = OS.get_ticks_msec()
		var import:Array = queue.pop_front()
		ImageOp.ImportImages(import[0], import[1])
		print("DONE  (R=" + ("t" if import[1] else "f") + "):   ", import[0], "\t; took %1.3f" % [float(OS.get_ticks_msec()-time)/1000.0], " seconds") 
		OS.delay_msec(50)
	call_deferred("_done")
	
func _done() -> void:
	if import_thread.is_alive() or import_thread.is_active(): import_thread.wait_to_finish()
	importer_active = false
	import_mutex.unlock()
	print("DONE IMPORTING")
	Signals.emit_signal("image_import_finished")
	
