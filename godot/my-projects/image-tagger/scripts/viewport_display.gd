extends TextureRect

const MAX_BYTES_TO_CHECK_APNG = 256

export (NodePath) var Cam ; onready var camera:Camera2D = get_node(Cam)
export (NodePath) var ColorGrade ; onready var color_grade:Control = get_node(ColorGrade)
export (NodePath) var EdgeDefaultMotionMix ; onready var edge_default_motion_mix:Control = get_node(EdgeDefaultMotionMix)

onready var default_camera_position:Vector2 = camera.position 
onready var default_camera_zoom:Vector2 = camera.zoom
onready var default_camera_offset:Vector2 = camera.offset

# Zoom
var zoom_to_point:bool = true
var zoom_in_max:float = 0.025
var zoom_out_max:float = 4.0
var zoom_step:float = 0.05

# Scroll
var scroll_step:float = 15.0
var scroll_speed:float = 4.0
var scroll_weight:float = 0.3

# Drag
var dragging:bool = false
var drag_speed:float = 1.1
var drag_step:float = 0.4

# Shaders - Colorgrade
var use_colorgrade:bool = false
var colorgrade_falloff:float = 0.0
var colorgrade_high:Color = Color.black
var color_grade_low:Color = Color.white

# Shaders - Edge Default Motion Mix
var use_edge_default_motion_mix:bool = false
var edmm_line_size:float = 0.0
var edmm_threshold:float = 0.0
var edmm_line_weight:float = 0.0
var edmm_graduation_size:float = 2.5
var edmm_weight:float = 0.5

func zoom_point(amount:float, position:Vector2) -> void:
	var prev_zoom:Vector2 = camera.zoom
	camera.zoom += camera.zoom * amount
	camera.offset += (((self.rect_position + self.rect_size) * 0.5) - position) * (camera.zoom - prev_zoom)

func _on_viewport_display_gui_input(event) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP:
			if Input.is_action_pressed("ctrl"): # scroll up
				camera.offset.y = lerp(camera.offset.y, camera.offset.y - scroll_step * scroll_speed * camera.zoom.y, scroll_weight)
				#camera.offset.y -= 15
			else: # zoom in
				if camera.zoom > Vector2(zoom_in_max, zoom_in_max):
					if zoom_to_point: zoom_point(-zoom_step, event.position)
					else: camera.zoom -= Vector2(zoom_step, zoom_step)
		elif event.button_index == BUTTON_WHEEL_DOWN:
			if Input.is_action_pressed("ctrl"): # scroll down
				camera.offset.y = lerp(camera.offset.y, camera.offset.y + scroll_step * scroll_speed * camera.zoom.y, scroll_weight)
				#camera.offset.y += 15
			else: # zoom out
				if camera.zoom < Vector2(zoom_out_max, zoom_out_max):
					if zoom_to_point: zoom_point(zoom_step, event.position)
					else: camera.zoom += Vector2(zoom_step, zoom_step) # make lerp ?
		elif event.button_index == BUTTON_RIGHT: # reset
			camera.position = default_camera_position
			camera.zoom = default_camera_zoom
			camera.offset = default_camera_offset
			camera.rotation_degrees = 0 
			Signals.emit_signal("resize_preview_image")
		else: # dragging
			if event.is_pressed(): dragging = true
			else: dragging = false
			
	elif event is InputEventMouseMotion and dragging: # dragging
		var rot = deg2rad(camera.rotation_degrees)
		var sin_rot = sin(rot) ; var cos_rot = cos(rot)
		# ensures that dragging works correctly when the camera is rotated
		var rot_mult:Vector2 = Vector2((cos_rot * event.relative.x) - (sin_rot * event.relative.y), (sin_rot * event.relative.x) + (cos_rot * event.relative.y))
		camera.position -= rot_mult * camera.zoom * drag_speed
		camera.position = lerp(camera.position, camera.position - (rot_mult * camera.zoom * drag_speed), drag_step)
