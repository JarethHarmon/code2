extends HSplitContainer

onready var left:VSplitContainer = $left
onready var right:VSplitContainer = $right

func _ready() -> void:
	var _err:int = Signals.connect("settings_loaded", self, "set_offsets")
	_err = self.connect("dragged", self, "_on_hsplit_dragged")
	_err = left.connect("dragged", self, "_on_left_dragged")
	_err = right.connect("dragged", self, "_on_right_dragged")

func set_offsets() -> void:
	self.split_offset = Globals.settings.hsplit_offset
	$left.split_offset = Globals.settings.left_offset
	$right.split_offset = Globals.settings.right_offset

func _on_hsplit_dragged(offset:int) -> void: Globals.settings.hsplit_offset = offset
func _on_left_dragged(offset:int) -> void: Globals.settings.left_offset = offset
func _on_right_dragged(offset:int) -> void: Globals.settings.right_offset = offset
