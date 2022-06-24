extends PanelContainer

onready var delete_button:TextureButton = $hbox/delete_button
onready var import_button:Button = $hbox/import_button

var import_name:String = "" setget set_import_name
var tmp_name:String = ""
var import_count:int = 0 setget set_import_count
var import_id:String = ""

func set_import_name(value:String) -> void:
	import_name = value
	tmp_name = import_name.substr(0, 16)
	import_button.text = "(" + String(import_count) + "):  " + tmp_name

func set_import_count(value:int) -> void:
	import_count = value
	import_button.text = "(" + String(import_count) + "):  " + tmp_name

func import_button_pressed() -> void:
	Globals.current_load_id = import_id
	Globals.current_type_id = Globals.TypeId.ImportGroup
	Signals.emit_signal("import_button_pressed")

func _ready() -> void:
	var _err:int = Signals.connect("update_button", self, "_set_import_count")
	_err = import_button.connect("button_up", self, "import_button_pressed")
	_err = delete_button.connect("button_up", self, "delete_button_pressed")

func _set_import_count(count:int, id:String) -> void:
	if import_id == id: 
		set_import_count(count)
	
# this needs to create a confirmation popup() instead of just deleting
func delete_button_pressed() -> void:
	Signals.emit_signal("delete_pressed", import_id)
	self.queue_free()
