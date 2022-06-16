extends Control

onready var tag_entry:LineEdit = $margin/vbox/hbox/tag_entry
onready var column_L:VBoxContainer = $margin/vbox/scroll/hsplit/vbox1
onready var column_R:VBoxContainer = $margin/vbox/scroll/hsplit/vbox2
var curr_column:bool = true # true=L false=R
var curr_hash:String = ""
var curr_tags:Dictionary = {}

func _ready() -> void: var _err:int = Signals.connect("load_tags", self, "_load_tags")

func _load_tags(komi64:String) -> void:
	curr_hash = komi64
	curr_tags.clear()
	
	var tags:Array = Database.GetKomiTagsFromDict(komi64)
	for tag in tags: curr_tags[tag] = null
	
	for c in column_L.get_children(): c.queue_free()
	for c in column_R.get_children(): c.queue_free()
	curr_column = true
	
	while not tags.empty():
		var b:Button = Button.new()
		b.text = tags.pop_front()
		if curr_column: 
			column_L.add_child(b)
			curr_column = false
		else:
			column_R.add_child(b)
			curr_column = true	

# pop-up tag entry
func _on_tag_entry_text_entered(new_text:String) -> void: _on_new_tag_button_up(new_text)
func _on_new_tag_button_up(text:String="") -> void:
	var text_n:String = text if text != "" else tag_entry.text
	tag_entry.text = ""
	
	if text_n == "Type a tag..": return
	if text_n == "": return
	if curr_hash == "": return
	if curr_tags.has(text_n): return
	
	var b:Button = Button.new()
	b.text = text_n
	
	if curr_column: 
		column_L.add_child(b)
		curr_column = false
	else:
		column_R.add_child(b)
		curr_column = true
	
	Database.AddTagToKomi(curr_hash, text_n)
	Database.AddHashToTag(text_n, curr_hash)

func _on_tag_entry_focus_entered() -> void:
	if tag_entry.text == "Type a tag..": tag_entry.text = ""

