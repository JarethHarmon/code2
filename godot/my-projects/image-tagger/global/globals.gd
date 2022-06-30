extends Node

enum SortBy { FileHash, FilePath, FileSize, FileCreationUtc, TagCount }
enum OrderBy { Ascending, Descending, Random }
enum TypeId { All, ImportGroup, ImageGroup }

var search_buttons_path:NodePath = ""

var current_load_id:String = "all"
var current_type_id:int = TypeId.All

var settings_hash:int
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

  # SORTING
	"current_sort" : SortBy.FileHash,
	"current_order" : OrderBy.Ascending,

  # IMPORTER	
	"use_recursion" : false,

  # THUMBNAIL LOADER
	"images_per_page" : 10,
	"load_threads" : 2,
	"pages_to_store" : 5,
	
  # IMAGE PREVIEWER
	"use_filter" : true,
	"use_smooth_pixel" : false,
  
  # COLOR GRADE
	"use_color_grade" : false,
	
  # Edge Mix
	"use_edge_mix" : false,

  # UI
	"hsplit_offset" : -175,
	"left_offset" : -160,
	"right_offset" : 240,
}

func _ready() -> void:
	settings.default_metadata_path = ProjectSettings.globalize_path("user://metadata/")
	settings.default_thumbnail_path = ProjectSettings.globalize_path("user://metadata/thumbnails/") 
	load_settings()
	if settings.thumbnail_path == "": settings.thumbnail_path = settings.default_thumbnail_path
	if settings.metadata_path == "": settings.metadata_path = settings.default_metadata_path

func save_settings() -> void:
	# don't waste time saving if nothing has changed
	if (settings.hash() == settings_hash): return
	
	var f:File = File.new()
	var e:int = f.open(settings_path, File.WRITE)
	if e == OK: f.store_string(var2str(settings))
	f.close()

func load_settings() -> void: 
	var f:File = File.new()
	var e:int = f.open(settings_path, File.READ)
	if e == OK: 
		settings = str2var(f.get_as_text())
		settings_hash = settings.hash()
	f.close()
	Signals.call_deferred("emit_signal", "settings_loaded") # needs to be deferred or it does not get sent out on time

