extends CharacterBody2D

const MAX_SPEED := 500
const ACCELERATION := 500
const ZOOM_DELTA := Vector2(0.05, 0.05)

var player_camera = null
var default_camera_zoom = Vector2(1.0, 1.0)

@export var resolution_rectangle_enabled := false

func _ready() -> void:
	setup_camera()

func _physics_process(delta):
	process_movement_input(delta)
	process_camera_input()

func process_movement_input(delta:float) -> void:
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * MAX_SPEED, delta * ACCELERATION)
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func process_camera_input() -> void:
	if player_camera == null:
		return
	
	var input_strength := Input.get_action_strength("zoom_in") - Input.get_action_strength("zoom_out")
	var minimum_zoom := 0.1
	
	if Input.is_action_just_pressed("zoom_reset"):
		player_camera.zoom = Vector2(1.0, 1.0)
		return
	
	if input_strength > 0.0:
		player_camera.zoom += (ZOOM_DELTA * input_strength)
	elif (input_strength < 0.0 and player_camera.zoom.x > minimum_zoom and player_camera.zoom.y > minimum_zoom):
		player_camera.zoom += (ZOOM_DELTA * input_strength)

func setup_camera() -> void:
	var camera_node := Camera2D.new()
	player_camera = camera_node
	player_camera.zoom = default_camera_zoom
	add_child(camera_node)

func _draw():
	if resolution_rectangle_enabled:
		var rect_position := Vector2(-320, -180)
		var rect_size := Vector2(640, 360)
		var rectangle := Rect2(rect_position, rect_size)
		
		draw_rect(rectangle, Color(Color.ORANGE, 0.5), false, 4.0)

