extends PanelContainer

var import_name:String = "" setget set_import_name
var tmp:String = ""
var import_count:int = 0 setget set_import_count
var import_id:String = ""

func set_import_name(value:String):
	import_name = value
	tmp = import_name.substr(0, 16)
	$hbox/import_name_count.text = "(" + String(import_count) + "):  " + tmp

func set_import_count(value:int):
	import_count = value
	$hbox/import_name_count.text = "(" + String(import_count) + "):  " + tmp

func _on_import_name_count_button_up() -> void:
	if Globals.search_buttons_path != "": get_node(Globals.search_buttons_path).hide()
	Signals.emit_signal("import_button_pressed", import_id)

func _ready() -> void:
	Signals.connect("update_button", self, "test")

func test(count:int, id:String) -> void:
	if import_id == id: set_import_count(count)
	
# this needs to create a confirmation popup() instead of just deleting
func _on_delete_button_button_up() -> void:
	Signals.emit_signal("delete_pressed", import_id)
	self.queue_free()
