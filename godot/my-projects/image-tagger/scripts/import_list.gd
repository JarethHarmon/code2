extends Control

onready var all_button:PanelContainer = $margin/vbox/all_button
onready var buttons:VBoxContainer = $margin/vbox/scroll/buttons

func _ready() -> void:
	var _err:int = Signals.connect("import_info_load_finished", self, "_import_info_load_finished")
	Signals.emit_signal("import_list_location", $margin/vbox/scroll/buttons.get_path())
	_err = Signals.connect("all_button_pressed", self, "set_button_color")
	_err = Signals.connect("import_button_pressed", self, "set_button_color")

func _import_info_load_finished() -> void:
	var import_ids:Array = Database.GetImportIDsFromDict(Globals.SortBy.FilePath)
	for id in import_ids: Signals.create_import_button(id)

func set_button_color() -> void: 
	var load_id:String = Globals.current_load_id
	if load_id == "all":
		all_button.self_modulate = Color(1,1,1)
		for child in buttons.get_children():
			child.self_modulate = Color(0,0,0)
	else:
		all_button.self_modulate = Color(0,0,0)
		for child in buttons.get_children():
			if child.import_id == load_id:
				child.self_modulate = Color(1,1,1)
			else:
				child.self_modulate = Color(0,0,0)

