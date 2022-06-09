extends Node

# all settings need to be moved here

var settings_path:String = "user://settings.tres"
var settings:Dictionary = {
  # GLOBAL
	"use_default_metadata_path" : true,
	"use_default_thumbnail_path" : true,
	"default_metadata_path" : "",
	"default_thumbnail_path" : "",
	"metadata_path" : "",
	"thumbnail_path" : "",
	"last_used_directory" : "",
	
  # IMPORTER	
	"use_recursion" : false,

  # THUMBNAIL LOADER
	"images_per_page" : 100,
	"load_threads" : 5,
	"pages_to_store" : 5,
	
  # IMAGE PREVIEWER
	"use_filter" : true,
	"use_smooth_pixel" : false,
}

func _ready() -> void:
	settings.default_metadata_path = ProjectSettings.globalize_path("user://metadata/")
	settings.default_thumbnail_path = ProjectSettings.globalize_path("user://metadata/thumbnails/") 
	load_settings()
	if settings.thumbnail_path == "": settings.thumbnail_path = settings.default_thumbnail_path
	if settings.metadata_path == "": settings.metadata_path = settings.default_metadata_path

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
	
