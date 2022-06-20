extends PanelContainer

var import_name:String = "ALL" setget set_import_name
var tmp:String = ""
var import_count:int = 0 setget set_import_count
var import_id:String = "all"

func set_import_name(_value:String):
	$hbox/load_all.text = "(" + String(import_count) + "):  ALL" 

func set_import_count(value:int):
	import_count = value
	$hbox/load_all.text = "(" + String(import_count) + "):  ALL"

func _ready() -> void:
	var _err:int = Signals.connect("update_button", self, "test")

func test(count:int, id:String) -> void:
	if import_id == id: set_import_count(count)
	
func _on_load_all_button_up():
	if Globals.search_buttons_path != "": get_node(Globals.search_buttons_path).show()
	#Signals.emit_signal("import_button_pressed", import_id) # maybe not needed (something else called on import_list
