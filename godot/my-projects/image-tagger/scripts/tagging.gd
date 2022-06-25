extends Control

# currently tag colors are random; I may change them to be based on hierarchy/type/user-defined

# need to display in tagging window somewhere a list of selected images

onready var tag_entry:LineEdit = $margin/vbox/hbox/tag_entry
#onready var column_L:VBoxContainer = $margin/vbox/scroll/hsplit/vbox1
#onready var column_R:VBoxContainer = $margin/vbox/scroll/hsplit/vbox2

#onready var grid:GridContainer = $margin/vbox/scroll/grid
onready var list:ItemList = $margin/vbox/margin/list

var curr_column:bool = true # true=L false=R
var curr_hash:String = ""
var curr_tags:Dictionary = {}

var index:int = 0

var selected_items:Dictionary = {}

func _ready() -> void: var _err:int = Signals.connect("load_tags", self, "_load_tags")

func _load_tags(komi64:String, items:Dictionary) -> void:
	curr_hash = komi64
	curr_tags.clear()
	
	var tags:Array = Database.GetKomiTagsFromDict(komi64)
	for tag in tags: curr_tags[tag] = null
	
	list.clear()
	index = 0
	selected_items = items
	
	while not tags.empty():
		list.add_item(tags.pop_front())
		var color:Color = Color(randf(), randf(), randf(), 1.0)
		list.set_item_custom_fg_color(index, color * 1.5)
		list.set_item_custom_bg_color(index, color * 0.25)
		index += 1

func _on_tag_entry_text_entered(new_text:String) -> void: _on_new_tag_button_up(new_text)
func _on_new_tag_button_up(text:String="") -> void:
	var text_n:String = text if text != "" else tag_entry.text
	tag_entry.text = ""
	
	if text_n == "": return
	if curr_hash == "": return
	if !curr_tags.has(text_n): 
		curr_tags[text_n] = null
	
		list.add_item(text_n)
		var color:Color = Color(randf(), randf(), randf(), 1.0)
		list.set_item_custom_fg_color(index, color * 1.5)
		list.set_item_custom_bg_color(index, color * 0.25)
		index += 1

	for idx in selected_items:
		# need to have these functions check if the tag is present and not add it if it is
		# above code should only be checking tags for the most recently selected image
		# whereas these need to check tags for all selected images
		# (I assumed it would print a bunch of errors if images already had the tag, but it seems to just work so IDK anymore)
		Database.AddTagToKomi(selected_items[idx], text_n)
		Database.AddHashToTag(text_n, selected_items[idx])

func _on_tag_entry_focus_entered() -> void:
	if tag_entry.text == "Type a tag..": tag_entry.text = ""

func _on_list_nothing_selected() -> void: list.unselect_all()
