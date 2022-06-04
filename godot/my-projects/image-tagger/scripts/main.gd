extends Control

#onready var default_metadata_path:String = OS.get_data_dir()
onready var default_metadata_path:String = ProjectSettings.globalize_path("user://metadata/")
onready var default_thumbnail_path:String = ProjectSettings.globalize_path("user://metadata/thumbnails/")

var use_default_thumbnail_path:bool = true
var use_default_metadata_path:bool = true

func _ready() -> void:
	var dir:Directory = Directory.new()
	if use_default_metadata_path:
		var err:int = dir.make_dir_recursive(default_metadata_path)
		if err == OK: Database.SetMetadataPath(default_metadata_path)
	
	if use_default_thumbnail_path:
		var err:int = dir.make_dir_recursive(default_thumbnail_path)
		if err == OK: ImageOp.SetThumbnailPath(default_thumbnail_path)
	
