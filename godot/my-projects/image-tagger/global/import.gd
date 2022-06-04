extends Node

func get_signed_komi_hash(path:String) -> int: return Gob.new().get_signed_komi_hash(path)
func get_unsigned_komi_hash(path:String) -> String: return Gob.new().get_unsigned_komi_hash(path)

# var import_thread:Thread = null
onready var import_thread:Thread = Thread.new()
onready var import_mutex:Mutex = Mutex.new()

func start_importing(import_folder:String, recursive:bool=true) -> void: 
	if (import_mutex.try_lock() != OK): return
	if (import_thread.is_alive()): return
	# if (import_thread == null): import_thread = Thread.new()
	import_mutex.lock()
	var _err:int = import_thread.start(self, "_thread", [import_folder, recursive])
	
func _thread(args:Array) -> void: 
	ImageOp.ImportImages(args[0], args[1])
	call_deferred("_done")
	
func _done() -> void:
	print("DONE")
	if import_thread.is_alive() or import_thread.is_active(): import_thread.wait_to_finish()
	import_mutex.unlock()
