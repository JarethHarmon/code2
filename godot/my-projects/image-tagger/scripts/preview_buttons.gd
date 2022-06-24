extends VBoxContainer

onready var filter:CheckButton = $vbox/bg_panel/hb/filter
onready var edge_mix:CheckButton = $vbox/bg_panel/hb/edge_mix
onready var color_grade:CheckButton = $vbox/bg_panel/hb/color_grade
onready var smooth_pixel:CheckBox = $vbox/bg_panel2/hb2/use_smooth_pixel
onready var recursion:CheckBox = $vbox/bg_panel2/hb2/use_recursion

onready var vbox:VBoxContainer = $vbox

func _input(event:InputEvent) -> void: 
	if Input.is_action_just_pressed("hide_ui"):
		_on_visibility_button_up()

func _ready() -> void:
	var _err:int = Signals.connect("settings_loaded", self, "_settings_loaded")

func _settings_loaded() -> void:
	filter.pressed = Globals.settings.use_filter
	edge_mix.pressed = Globals.settings.use_edge_mix
	color_grade.pressed = Globals.settings.use_color_grade
	smooth_pixel.pressed = Globals.settings.use_smooth_pixel
	recursion.pressed = Globals.settings.use_recursion

func _on_visibility_button_up() -> void: vbox.visible = !vbox.visible


