extends Button

onready var fd:FileDialog = get_node("/root/main/FileDialog")
onready var recursive:CheckButton = get_node("../recursive")

func _ready() -> void:
	var _err:int = fd.connect("dir_selected", self, "fd_dir_selected")
	_err = self.connect("button_up", self, "_on_import_images_pressed")
	_err = Signals.connect("settings_loaded", self, "_settings_loaded")

func _settings_loaded() -> void:
	recursive.pressed = Globals.settings.use_recursion

func fd_dir_selected(dir:String) -> void: 
	if ImageOp.thumbnail_path == "": return
	Import.queue_append(dir, Globals.settings.use_recursion)
	Globals.settings.last_used_directory = dir.get_base_dir()

func _on_import_images_pressed() -> void:
	if fd.visible: return
	fd.mode = 2 	# choose folder
	fd.access = 2	# file system
	fd.window_title = "Choose a folder to import from"
	if Globals.settings.last_used_directory != "": fd.current_dir = Globals.settings.last_used_directory
	fd.popup()

func _on_recursive_toggled(button_pressed:bool) -> void: Globals.settings.use_recursion = button_pressed
