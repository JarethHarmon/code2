extends Node

func get_signed_komi_hash(path:String) -> int: return Gob.new().get_signed_komi_hash(path)
func get_unsigned_komi_hash(path:String) -> String: return Gob.new().get_unsigned_komi_hash(path)

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
	print("added to queue (recursive = ", recursive, ") : \n\t", import_folder, "\n") 
	queue.append([import_folder, recursive])
	if (!importer_active): start_importer()

func _thread() -> void:
	while not queue.empty():
		var import:Array = queue.pop_front()
		ImageOp.ImportImages(import[0], import[1])
		OS.delay_msec(50)
	call_deferred("_done")
	
func _done() -> void:
	if import_thread.is_alive() or import_thread.is_active(): import_thread.wait_to_finish()
	importer_active = false
	import_mutex.unlock()
	print("DONE\n")
	
