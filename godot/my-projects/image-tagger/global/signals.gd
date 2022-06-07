extends Node

const import_button = preload("res://scenes/import_button.tscn")

signal load_image(image_path)
signal image_import_finished
signal import_info_load_finished
signal import_button_pressed(import_id)
signal import_list_location(node_path)

var import_list:NodePath

func _ready() -> void: var _err:int = self.connect("import_list_location", self, "set_import_list_location")

func set_import_list_location(path:NodePath) -> void: import_list = path

# temporary location so it has global access
# needs global access to be easier to call from C# (when initially creating the buttons) (probably should find a better way)
func create_import_button(id:String) -> void: 
	var ibutton = import_button.instance()
	if Database.ImportDictHasID(id):
		var _name:String = Database.GetImportNameFromDict(id)
		if _name == "": _name = Database.GetImportBaseFolder(id).get_file()
		ibutton.set_import_name(_name)
		ibutton.set_import_count(Database.GetImportCount(id))
	ibutton.import_id = id
	get_node(import_list).add_child(ibutton)
