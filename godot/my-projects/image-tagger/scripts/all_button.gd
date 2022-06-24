extends PanelContainer

onready var load_all_button:Button = $hbox/load_all

var image_count:int = 0 setget set_image_count
var load_id:String = "all"

func _ready() -> void:
	var _err:int = Signals.connect("update_button", self, "_set_image_count")
	_err = load_all_button.connect("button_up", self, "all_button_pressed")

func _set_image_count(count:int, id:String) -> void: 
	if load_id == id: 
		set_image_count(count)
func set_image_count(value:int):
	image_count = value
	$hbox/load_all.text = "(" + String(image_count) + "):  ALL"

func all_button_pressed() -> void: 
	Globals.current_load_id = load_id
	Globals.current_type_id = Globals.TypeId.All
	Signals.emit_signal("all_button_pressed") 
