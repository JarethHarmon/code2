extends VBoxContainer

onready var filter:CheckButton = $bg_panel/hb/filter
onready var edge_mix:CheckButton = $bg_panel/hb/edge_mix
onready var color_grade:CheckButton = $bg_panel/hb/color_grade
onready var smooth_pixel:CheckBox = $bg_panel2/hb2/use_smooth_pixel
onready var recursion:CheckBox = $bg_panel2/hb2/use_recursion

func _ready() -> void:
	var _err:int = Signals.connect("settings_loaded", self, "_settings_loaded")

func _settings_loaded() -> void:
	filter.pressed = Settings.settings.use_filter
	edge_mix.pressed = Settings.settings.use_edge_mix
	color_grade.pressed = Settings.settings.use_color_grade
	smooth_pixel.pressed = Settings.settings.use_smooth_pixel
	recursion.pressed = Settings.settings.use_recursion
