extends VBoxContainer

onready var filter:CheckButton = $vbox/bg_panel/hb/filter
onready var edge_mix:CheckButton = $vbox/bg_panel/hb/edge_mix
onready var color_grade:CheckButton = $vbox/bg_panel/hb/color_grade
onready var smooth_pixel:CheckButton = $vbox/bg_panel/hb/use_smooth_pixel

onready var vbox:VBoxContainer = $vbox

func _input(_event:InputEvent) -> void: 
	if Input.is_action_just_pressed("hide_ui"):
		_on_visibility_button_up()

func _ready() -> void:
	var _err:int = Signals.connect("settings_loaded", self, "_settings_loaded")
	_err = filter.connect("toggled", self, "filter_toggled")
	_err = edge_mix.connect("toggled", self, "edge_mix_toggled")
	_err = color_grade.connect("toggled", self, "color_grade_toggled")
	_err = smooth_pixel.connect("toggled", self, "smooth_pixel_toggled")

func _settings_loaded() -> void:
	filter.pressed = Globals.settings.use_filter
	edge_mix.pressed = Globals.settings.use_edge_mix
	color_grade.pressed = Globals.settings.use_color_grade
	smooth_pixel.pressed = Globals.settings.use_smooth_pixel

func _on_visibility_button_up() -> void: vbox.visible = !vbox.visible

func filter_toggled(active:bool) -> void: Signals.emit_signal("filter_toggled", active)
func edge_mix_toggled(active:bool) -> void: Signals.emit_signal("edge_mix_toggled", active)
func color_grade_toggled(active:bool) -> void: Signals.emit_signal("color_grade_toggled", active)
func smooth_pixel_toggled(active:bool) -> void: Signals.emit_signal("smooth_pixel_toggled", active)
