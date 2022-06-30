extends HBoxContainer

onready var sortby_options:OptionButton = $sort_by
onready var orderby_options:OptionButton = $order_by
onready var clear_button:Button = $clear
onready var select_all_button:Button = $select_all

func _ready() -> void: 
	var _err:int = sortby_options.connect("item_selected", self, "sort_option_selected")
	_err = orderby_options.connect("item_selected", self, "order_option_selected")
	_err = clear_button.connect("button_up", self, "clear_pressed")
	_err = select_all_button.connect("button_up", self, "select_all_pressed")
	
	self.call_deferred("apply_settings")

func apply_settings() -> void:
	sortby_options.selected = Globals.settings.current_sort
	orderby_options.selected = Globals.settings.current_order

func sort_option_selected(index:int) -> void: 
	Globals.settings.current_sort = index
	Signals.emit_signal("sort_changed")
func order_option_selected(index:int) -> void: 
	Globals.settings.current_order = index
	Signals.emit_signal("order_changed")
func clear_pressed() -> void: Signals.emit_signal("clear_pressed")
func select_all_pressed() -> void: Signals.emit_signal("select_all_pressed")
