extends HSplitContainer

onready var left:VSplitContainer = $left
onready var right:VSplitContainer = $right

# not perfect, but better than the default behavior at least (for 3+ columns)
# this and commented code below are for supporting 3-4 columns in split containers (currently only 2 with vsplitcontainers instead)
# var lock_LR_offsets:bool = true

func _ready() -> void:	
	var _err:int = Signals.connect("settings_loaded", self, "set_offsets")
	_err = self.connect("dragged", self, "_on_hsplit_dragged")
	_err = left.connect("dragged", self, "_on_left_dragged")
	_err = right.connect("dragged", self, "_on_right_dragged")

func set_offsets() -> void:
	self.split_offset = Globals.settings.hsplit_offset
	$left.split_offset = Globals.settings.left_offset
	$right.split_offset = Globals.settings.right_offset

func _on_hsplit_dragged(offset:int) -> void:
#	if lock_LR_offsets:
#		left.split_offset += (Globals.settings.hsplit_offset-offset) * 0.5
#		right.split_offset += (Globals.settings.hsplit_offset-offset) * 0.5
#		Globals.settings.left_offset = left.split_offset
#		Globals.settings.right_offset = right.split_offset
	Globals.settings.hsplit_offset = offset
	
func _on_left_dragged(offset:int) -> void: Globals.settings.left_offset = offset
func _on_right_dragged(offset:int) -> void: Globals.settings.right_offset = offset
