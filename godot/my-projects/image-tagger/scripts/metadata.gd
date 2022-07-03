extends Control

onready var paths_list:VBoxContainer = $margin/vbox/scroll/paths_vbox

func _ready() -> void:
	var _err:int = Signals.connect("set_paths", self, "create_path_buttons")
	_err = Signals.connect("all_button_pressed", self, "clear_paths_list")
	_err = Signals.connect("import_button_pressed", self, "clear_paths_list")
	_err = Signals.connect("clear_pressed", self, "clear_paths_list")

func clear_paths_list() -> void: for child in paths_list.get_children(): child.queue_free()

func create_path_buttons(_komi64:String, paths:Array) -> void:
	clear_paths_list()
	
	for path in paths:
		var b:Button = Button.new()
		b.text = path
		b.align = b.ALIGN_LEFT
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		var _err:int = b.connect("pressed", self, "set_clipboard", [path])
		paths_list.add_child(b)

func set_clipboard(path:String) -> void: OS.set_clipboard(path)
