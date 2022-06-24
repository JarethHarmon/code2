extends HBoxContainer

onready var include_all:LineEdit = $search_bars/include_all
onready var include_any:LineEdit = $search_bars/include_any
onready var exclude_all:LineEdit = $search_bars/exclude_all
onready var search:Button = $search_button

var tags_all:Array = []
var tags_any:Array = []
var tags_none:Array = []

func _ready() -> void: 
	Globals.search_buttons_path = self.get_path()
	var _err:int = include_all.connect("text_entered", self, "include_all_entered")
	_err = include_any.connect("text_entered", self, "include_any_entered")
	_err = exclude_all.connect("text_entered", self, "exclude_all_entered")
	_err = include_all.connect("text_changed", self, "include_all_changed")
	_err = include_any.connect("text_changed", self, "include_any_changed")
	_err = exclude_all.connect("text_changed", self, "exclude_all_changed")
	_err = search.connect("button_up", self, "search_pressed")
	_err = Signals.connect("page_changed", self, "page_changed")
	
	_err = Signals.connect("all_button_pressed", self, "all_button_pressed")
	_err = Signals.connect("import_button_pressed", self, "import_button_pressed")
	
	_err = Signals.connect("sort_changed", self, "search_pressed")
	_err = Signals.connect("order_changed", self, "search_pressed")
	
func include_all_entered(_new_text:String) -> void: search_pressed()
func include_any_entered(_new_text:String) -> void: search_pressed()
func exclude_all_entered(_new_text:String) -> void: search_pressed()

func include_all_changed(new_text:String) -> void: tags_all = new_text.split(",", false)
func include_any_changed(new_text:String) -> void: tags_any = new_text.split(",", false)
func exclude_all_changed(new_text:String) -> void: tags_none = new_text.split(",", false)

func search_pressed() -> void: Signals.emit_signal("search_pressed", tags_all, tags_any, tags_none, true)
func page_changed() -> void: Signals.emit_signal("search_pressed", tags_all, tags_any, tags_none, false)

func all_button_pressed() -> void: 	self.show()
func import_button_pressed() -> void: self.hide()
