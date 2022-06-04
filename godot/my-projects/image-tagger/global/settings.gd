extends Node

var settings_path:String = "user://settings.tres"
var settings:Dictionary = {
	"last_used_directory" : "",
	"metadata_path" : "",
	"thumbnail_path" : "",
}

func save_settings() -> void:
	var f:File = File.new()
	var e:int = f.open(settings_path, File.WRITE)
	if e == OK: f.store_string(var2str(settings))
	f.close()

func load_settings() -> void: 
	var f:File = File.new()
	var e:int = f.open(settings_path, File.READ)
	if e == OK: settings = str2var(f.get_as_text())
	f.close()
	
