extends CharacterBody3D

@export var health = 100
@export var max_health = 100
@export var speed = 3.0
@export var attack_damage = 20
@export var detection_range = 25.0
@export var attack_range = 2.0

@onready var nav_agent = $NavigationAgent3D

var player_ref: Node3D
var attack_timer = 0.0

enum EnemyState {
	IDLE,
	CHASING,
	ATTACKING,
	DEAD
}

var current_state = EnemyState.IDLE

func _ready():
	call_deferred("find_target_player")
	
	# Also periodically refresh player target in case players join/leave
	var refresh_timer = Timer.new()
	add_child(refresh_timer)
	refresh_timer.wait_time = 2.0
	refresh_timer.timeout.connect(find_target_player)
	refresh_timer.start()

func find_target_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		# Find the closest player as target
		var closest_player = null
		var closest_distance = INF
		
		for player in players:
			if not is_instance_valid(player):
				continue
			var distance = global_position.distance_to(player.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_player = player
		
		if closest_player != player_ref:
			player_ref = closest_player
			print("Enemy ", name, " now targeting player: ", player_ref.name if player_ref else "none")
	
	add_to_group("enemies")
	velocity = Vector3.ZERO
	
	# Ensure proper collision settings for enemies
	floor_max_angle = 0.785398  # 45 degrees
	floor_snap_length = 1.0
	floor_stop_on_slope = true
	floor_constant_speed = false
	floor_block_on_wall = true
	safe_margin = 0.08

func _physics_process(delta):
	if current_state == EnemyState.DEAD or not is_inside_tree():
		return
	
	update_ai(delta)
	
	# Apply gravity (get_gravity().y is already negative)
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		# When on floor, ensure we stay grounded
		velocity.y = max(velocity.y, 0)
	
	# Move towards target if chasing
	if current_state == EnemyState.CHASING:
		if player_ref and is_instance_valid(player_ref):
			var direction = (player_ref.global_position - global_position).normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
			# Look at target (rotate 180 degrees to face player)
			look_at(player_ref.global_position, Vector3.UP)
			rotation.y += PI  # Add 180 degree rotation to face the player
	else:
		# Apply friction when not moving
		velocity.x *= 0.8
		velocity.z *= 0.8
	
	# Cap falling speed to prevent physics issues
	velocity.y = clamp(velocity.y, -30.0, 10.0)
	
	# Store position before movement for safety check
	var pre_move_position = global_position
	
	move_and_slide()
	
	# Safety check for enemies falling through floor
	var vertical_movement = abs(global_position.y - pre_move_position.y)
	if vertical_movement > 2.0 and not is_on_floor():
		print("WARNING: Enemy fell too far, correcting position")
		global_position = pre_move_position
		velocity.y = 0
	
	# Simple ground check - if enemy is above ground level, let gravity work
	# If enemy falls below ground, reset to ground level
	if global_position.y < -0.5:
		global_position.y = 1.0
		velocity.y = 0

func update_ai(delta):
	if not player_ref or not is_instance_valid(player_ref):
		find_target_player()  # Try to find a player
		return
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	var old_state = current_state
	
	match current_state:
		EnemyState.IDLE:
			if distance_to_player <= detection_range:
				current_state = EnemyState.CHASING
				print("Enemy ", name, " detected player at distance: ", distance_to_player, " - starting chase!")
		
		EnemyState.CHASING:
			if distance_to_player > detection_range * 1.2:
				current_state = EnemyState.IDLE
				print("Enemy ", name, " lost player - going idle")
			elif distance_to_player <= attack_range:
				current_state = EnemyState.ATTACKING
				attack_timer = 1.0
				print("Enemy ", name, " in attack range!")
		
		EnemyState.ATTACKING:
			attack_timer -= delta
			if attack_timer <= 0.0:
				perform_attack()
				if distance_to_player > attack_range:
					current_state = EnemyState.CHASING
				else:
					attack_timer = 1.0
	
	# Debug: Print state changes and distance info
	if old_state != current_state or randi() % 120 == 0:  # Every ~2 seconds at 60fps
		print("Enemy ", name, " state: ", ["IDLE", "CHASING", "ATTACKING", "DEAD"][current_state], " distance: ", snapped(distance_to_player, 0.1))

func perform_attack():
	if player_ref and is_instance_valid(player_ref) and player_ref.has_method("take_damage"):
		player_ref.take_damage(attack_damage)
		print("Enemy attacks for ", attack_damage, " damage!")

func take_damage(damage: int):
	if current_state == EnemyState.DEAD:
		return
	
	health -= damage
	print("Enemy took ", damage, " damage! Health: ", health, "/", max_health)
	
	# Hit animation - flash white briefly
	play_hit_animation()
	
	if health <= 0:
		die()
	else:
		current_state = EnemyState.CHASING

func play_hit_animation():
	var chomper_model = $ChomperModel
	if not chomper_model:
		return
	
	# Find all MeshInstance3D nodes in the chomper model and flash them
	var mesh_nodes = find_mesh_nodes(chomper_model)
	var original_materials = []
	
	# Store original materials and apply white flash
	for mesh_node in mesh_nodes:
		original_materials.append(mesh_node.material_override)
		var white_material = StandardMaterial3D.new()
		white_material.albedo_color = Color.WHITE
		mesh_node.material_override = white_material
	
	# Return to original materials after 0.1 seconds
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): 
		for i in range(mesh_nodes.size()):
			if is_instance_valid(mesh_nodes[i]):
				mesh_nodes[i].material_override = original_materials[i]
		if is_instance_valid(timer):
			timer.queue_free()
	)
	timer.start()

func find_mesh_nodes(node: Node) -> Array[MeshInstance3D]:
	var mesh_nodes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		mesh_nodes.append(node)
	for child in node.get_children():
		mesh_nodes.append_array(find_mesh_nodes(child))
	return mesh_nodes

func die():
	current_state = EnemyState.DEAD
	health = 0
	
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	
	print("Enemy died!")
	
	# Emit signal before dying
	if is_inside_tree():
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("on_enemy_died"):
			main_scene.on_enemy_died()
	
	# Start death animation
	start_death_animation()

func start_death_animation():
	var chomper_model = $ChomperModel
	if not chomper_model:
		queue_free()  # If no model, just remove
		return
	
	# Create fall-over animation using tween
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations at once
	
	# Fall backwards by rotating -90 degrees on X axis over 1 second
	tween.tween_method(
		func(rotation): chomper_model.rotation.x = rotation,
		0.0, -PI/2, 1.0  # Fall backwards 90 degrees
	)
	
	# Find all mesh nodes and apply death material
	var mesh_nodes = find_mesh_nodes(chomper_model)
	var death_materials = []
	
	for mesh_node in mesh_nodes:
		var death_material = StandardMaterial3D.new()
		death_material.albedo_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray
		death_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_node.material_override = death_material
		death_materials.append(death_material)
	
	# Fade out all materials after falling over
	for death_material in death_materials:
		tween.tween_method(
			func(alpha): death_material.albedo_color.a = alpha,
			1.0, 0.0, 1.5
		).set_delay(0.5)  # Start fading after half the fall animation
	
	# Remove after animation completes using finished signal
	tween.finished.connect(queue_free)

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health