extends Control

export (NodePath) var Images ; onready var images:ItemList = get_node(Images)

#onready var default_metadata_path:String = OS.get_data_dir()
onready var default_metadata_path:String = ProjectSettings.globalize_path("user://metadata/")
onready var default_thumbnail_path:String = ProjectSettings.globalize_path("user://metadata/thumbnails/") 

var use_default_thumbnail_path:bool = true
var use_default_metadata_path:bool = true

func _notification(what) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		Database.CheckpointKomi64()
		Database.Destroy() 
		#print_stray_nodes()
		images.stop_threads()
		Settings.save_settings()
		get_tree().quit()

func _ready() -> void:
	# closing the program instead calls _notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)
	get_tree().set_auto_accept_quit(false)
	
	# make and set default metadata folder
	var dir:Directory = Directory.new()
	if use_default_metadata_path:
		var err:int = dir.make_dir_recursive(default_metadata_path)
		if err == OK: Database.SetMetadataPath(default_metadata_path)
	
	# make and set default thumbnail folder
	if use_default_thumbnail_path:
		var err:int = dir.make_dir_recursive(default_thumbnail_path)
		if err == OK: ImageOp.SetThumbnailPath(default_thumbnail_path)
	
	# create database and print its folder
	if (Database.Create() == OK): print("successfully opened databases")
	if (Database.LoadAllImportInfoFromDatabase() == OK): print("successfully loaded imports")
	
	Settings.load_settings()
	
	if Settings.settings.thumbnail_path == "": Settings.settings.thumbnail_path = default_thumbnail_path
	if Settings.settings.metadata_path == "": Settings.settings.metadata_path = default_metadata_path
	


