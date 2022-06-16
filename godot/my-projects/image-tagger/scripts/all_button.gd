extends PanelContainer

var import_name:String = "ALL" setget set_import_name
var tmp:String = ""
var import_count:int = 0 setget set_import_count
var import_id:String = "all"

func set_import_name(value:String):
	$hbox/load_all.text = "(" + String(import_count) + "):  ALL" 

func set_import_count(value:int):
	import_count = value
	$hbox/load_all.text = "(" + String(import_count) + "):  ALL"

func _on_import_name_count_button_up() -> void:
	Signals.emit_signal("import_button_pressed", import_id)

func _ready() -> void:
	Signals.connect("update_button", self, "test")

func test(count:int, id:String) -> void:
	if import_id == id: set_import_count(count)
	
# this needs to create a confirmation popup() instead of just deleting
func _on_delete_button_button_up() -> void:
	Signals.emit_signal("delete_pressed", import_id)
	self.queue_free()
