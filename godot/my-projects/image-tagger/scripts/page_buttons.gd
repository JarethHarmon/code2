extends HBoxContainer

onready var prev_page:Button = $prev_page
onready var next_page:Button = $next_page

func _ready() -> void: 
	var _err:int = prev_page.connect("button_up", self, "prev_page_button_pressed")
	_err = next_page.connect("button_up", self, "next_page_button_pressed")

func prev_page_button_pressed() -> void: Signals.emit_signal("prev_page_pressed")
func next_page_button_pressed() -> void: Signals.emit_signal("next_page_pressed")

