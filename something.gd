extends Node2D

const WALK_SPEED = 300.0
const AFK_SLEEP_TIME: float = 60.0

var speed = 300
var direction = Vector2(1,0)
var screen_size = Vector2()
var window_size = Vector2(200,200)

@onready var animated_sprite = $AnimatedSprite2D
@onready var area = $Area2D
@onready var typing_timer = $TypingTimer
@onready var typing_audio = $TypingAudio

var is_sleeping: bool = false
var time_since_last_input = 0.0
var last_mouse_x: float = 0.0
var is_dragging = false
var drag_offset = Vector2()
var idle_timer = 0.0
var is_idling = false
var is_typing = false
var typing_keys: Array[Key] = []


func start_sleeping() -> void:
	if is_dragging or is_idling or is_typing:
		return
	
	is_sleeping = true
	is_idling = false
	speed = 0
	if animated_sprite.sprite_frames.has_animation("Sleeping"):
		animated_sprite.play("Sleeping")
		animated_sprite.scale = Vector2(2, 2) 
	elif animated_sprite.sprite_frames.has_animation("Sleep"):
		animated_sprite.play("Sleep")
	else:
		print("ERROR: Neither 'Sleeping' nor 'Sleep' exists in SpriteFrames! Available animations: ", animated_sprite.sprite_frames.get_animation_names())
	
	
	
	
func wake_up() ->void:
	if not is_sleeping:
		return
	is_sleeping = false
	time_since_last_input =0.0
	speed = WALK_SPEED
	animated_sprite.scale = Vector2(3.5, 3.5) 
	


func _on_area_input(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			time_since_last_input = 0.0
			if is_sleeping:
				wake_up()
			is_dragging = true
			is_typing = false
			typing_timer.stop()
			typing_audio.stop()
			animated_sprite.play("Falling")
			animated_sprite.scale = Vector2(2, 2) 
			 # Restore original size
			
			var mouse_pos = Vector2(DisplayServer.mouse_get_position())
			var win_pos = Vector2(DisplayServer.window_get_position())
			drag_offset = mouse_pos - win_pos
		else:
			is_dragging = false
			animated_sprite.scale = Vector2(3.5, 3.5)
			animated_sprite.rotation_degrees = 0.0
			if not is_typing and not is_idling and not is_sleeping:
				animated_sprite.play("Walk")

func maybe_idle() -> void:
	if is_idling or is_typing:
			return
			
	if randf() < 0.03:
		is_idling = true
		idle_timer = randf_range(1.0, 3.0)
		animated_sprite.play("Idle")
		speed = 0
		

func _ready():
	DisplayServer.window_move_to_foreground()
	screen_size = Vector2(DisplayServer.screen_get_size())
	animated_sprite.play("Walk")
	area.input_event.connect(_on_area_input)
	typing_timer.timeout.connect(_on_typing_stopped)
	
	if OS.has_feature("windows") and ClassDB.class_exists("GlobalInput"):
		for k in range(KEY_A, KEY_Z + 1):
			typing_keys.append(k as Key)
		for k in range(KEY_0, KEY_9 + 1):
			typing_keys.append(k as Key)
		typing_keys.append(KEY_SPACE)
		typing_keys.append(KEY_BACKSPACE)
		typing_keys.append(KEY_ENTER)
	

	
	
func _check_global_typing() -> void:
	for key in typing_keys:
		if GlobalInput.is_global_key_just_pressed(key):
			time_since_last_input = 0.0
			
			if is_sleeping:
				wake_up()
				
			is_typing = true
			if animated_sprite.animation != "Typing":
				animated_sprite.play("Typing")
				
			if not typing_audio.playing:
				typing_audio.play()
			typing_timer.start()
			break
			


func _process(_delta: float) -> void:
	
	if OS.has_feature("windows") and ClassDB.class_exists("GlobalInput"):
		_check_global_typing()
		
		
	if not is_sleeping and not is_dragging and not is_typing:
		time_since_last_input += _delta
		if time_since_last_input >= AFK_SLEEP_TIME:
			start_sleeping()


			
func _on_typing_stopped() -> void:
	is_typing = false
	
	typing_audio.stop()
	
	if not is_idling and not is_dragging:
		speed = WALK_SPEED
		animated_sprite.play("Walk")
	

			
					
				
func _physics_process(delta: float) -> void:
	
	
	var current_screen = DisplayServer.window_get_current_screen()
	var screen_rect = DisplayServer.screen_get_usable_rect(current_screen)
	
	var min_x = screen_rect.position.x
	var min_y = screen_rect.position.y
	var max_x = screen_rect.position.x + screen_rect.size.x - window_size.x
	var max_y = screen_rect.position.y + screen_rect.size.y - window_size.y
	
	if is_dragging:
		var mouse_pos = Vector2(DisplayServer.mouse_get_position())
		var target_win_pos = mouse_pos - drag_offset
		
		target_win_pos.x = clamp(target_win_pos.x, min_x, max_x)
		target_win_pos.y = clamp(target_win_pos.y, min_y, max_y)
		
		var mouse_velocity_x = (mouse_pos.x - last_mouse_x)/delta
		last_mouse_x = mouse_pos.x
		
		var target_rotation = clamp(mouse_velocity_x * 0.02, -20.0, 20.0)
		animated_sprite.rotation_degrees = lerp(animated_sprite.rotation_degrees, target_rotation, 10.0 * delta)
		
		DisplayServer.window_set_position(Vector2i(target_win_pos))
		return
		
	if is_typing or is_sleeping:
		return
		
	if is_idling:
		idle_timer -= delta
		if idle_timer <= 0:
			is_idling = false
			speed = WALK_SPEED
			animated_sprite.play("Walk")
		return
		
	var window_position = Vector2(DisplayServer.window_get_position())
	window_position += direction * speed * delta
		
	if window_position.x <= min_x:
		window_position.x = min_x
		direction.x = abs(direction.x)
		animated_sprite.flip_h = false
		maybe_idle()
	elif window_position.x >= max_x:
		window_position.x = max_x
		direction.x = -abs(direction.x)
		animated_sprite.flip_h = true
		maybe_idle()
	
	if window_position.y <=min_y:
		window_position.y = min_y
		direction.y = abs(direction.y)
		animated_sprite.flip_h = false
		maybe_idle()
	elif window_position.y >= max_y:
		window_position.y = max_y
		direction.y = -abs(direction.y)
		animated_sprite.flip_h = true
		maybe_idle()
		
	DisplayServer.window_set_position(Vector2i(window_position))
	
		

				
					
