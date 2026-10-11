extends Node2D

const WALK_SPEED = 300.0

var speed = 300
var direction = Vector2(1,0)
var screen_size = Vector2()
var window_size = Vector2(200,200)

@onready var animated_sprite = $AnimatedSprite2D
@onready var area = $Area2D
@onready var typing_timer = $TypingTimer
@onready var typing_audio = $TypingAudio

var is_dragging = false
var drag_offset = Vector2()
var idle_timer = 0.0
var is_idling = false
var is_typing = false
var typing_keys: Array[Key] = []


func _on_area_input(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			var mouse_pos = Vector2(DisplayServer.mouse_get_position())
			var win_pos = Vector2(DisplayServer.window_get_position())
			# Calculate where the mouse is relative to the top-left of the window
			drag_offset = mouse_pos - win_pos
		else:
			is_dragging = false

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

			
func _on_typing_stopped() -> void:
	is_typing = false
	
	typing_audio.stop()
	
	if not is_idling:
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
		
		target_win_pos.x = clamp(target_win_pos.x, 0, screen_size.x - window_size.x)
		target_win_pos.y = clamp(target_win_pos.y, 0, screen_size.y - window_size.y)
		
		DisplayServer.window_set_position(Vector2i(target_win_pos))
		return
		
	if is_typing:
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
		
	if window_position.x <= 0:
		window_position.x = 0
		direction.x = abs(direction.x)
		animated_sprite.flip_h = false
		maybe_idle()
	elif window_position.x >= max_x:
		window_position.x = max_x
		direction.x = -abs(direction.x)
		animated_sprite.flip_h = true
		maybe_idle()
	
	if window_position.y <=0:
		window_position.y = 0
		direction.y = abs(direction.y)
		animated_sprite.flip_h = false
		maybe_idle()
	elif window_position.y >= max_y:
		window_position.y = max_y
		direction.y = -abs(direction.y)
		animated_sprite.flip_h = true
		maybe_idle()
		
	DisplayServer.window_set_position(Vector2i(window_position))
	
		

				
					
