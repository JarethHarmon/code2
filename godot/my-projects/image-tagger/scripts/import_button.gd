extends PanelContainer

var import_name:String = "" setget set_import_name
var import_count:int = 0 setget set_import_count
var import_id:String = ""

func set_import_name(value:String):
	import_name = value
	$hbox/import_name_count.text = "(" + String(import_count) + "):  " + import_name

func set_import_count(value:int):
	import_count = value
	$hbox/import_name_count.text = "(" + String(import_count) + "):  " + import_name

func _on_import_name_count_button_up() -> void:
	Signals.emit_signal("import_button_pressed", import_id)

