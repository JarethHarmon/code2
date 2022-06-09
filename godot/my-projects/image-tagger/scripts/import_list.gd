extends Control

func _ready() -> void:
	var _err:int = Signals.connect("import_info_load_finished", self, "_import_info_load_finished")
	Signals.emit_signal("import_list_location", $margin/vbox.get_path())

func _import_info_load_finished() -> void:
	var import_ids:Array = Database.GetImportIDsFromDict()
	for id in import_ids: Signals.create_import_button(id)

