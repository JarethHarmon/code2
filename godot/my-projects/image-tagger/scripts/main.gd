extends Control

export (NodePath) var Images ; onready var images:ItemList = get_node(Images)

func _notification(what) -> void:
 # if user tried to close the program, or the program crashed (though not sure if latter actually works)
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST or what == MainLoop.NOTIFICATION_CRASH or what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		Database.UpdateAllImportInfo()
		Database.CheckpointKomi64()
		Database.CheckpointImport()
		Database.CheckpointTag()
		Database.Destroy() 
		#print_stray_nodes() # checks for orphan nodes, currently there are none
		images.stop_threads()
		Settings.save_settings()
		print("exiting program")
		get_tree().quit()

# add F8 as exit button (also overrides built-in stop button so that metadata actually gets saved)
func _input(event:InputEvent) -> void:
	if event is InputEventKey:
		if event.scancode == KEY_F8:
			_notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)

func _ready() -> void:
 # closing the program instead calls _notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)
	get_tree().set_auto_accept_quit(false)
 # ensure other scripts have time to connect to any signals (they should even without this)
	call_deferred("_begin")

func _begin() -> void:
 # make and set default metadata folder
	var dir:Directory = Directory.new()
	if Settings.settings.use_default_metadata_path:
		var err:int = dir.make_dir_recursive(Settings.settings.default_metadata_path)
		if err == OK: Database.SetMetadataPath(Settings.settings.default_metadata_path)
	
 # make and set default thumbnail folder
	if Settings.settings.use_default_thumbnail_path:
		var err:int = dir.make_dir_recursive(Settings.settings.default_thumbnail_path)
		if err == OK: ImageOp.SetThumbnailPath(Settings.settings.default_thumbnail_path)
	
 # create database and print its folder
	if (Database.Create() == OK): print("successfully opened databases")
	if (Database.LoadImportInfoFromDatabase() == OK): print("successfully loaded imports")
	Database.LoadTagsFromDatabase()
	Signals.emit_signal("import_info_load_finished")



