extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.003

@onready var camera = $Camera3D

# Multiplayer sync variables
var sync_position: Vector3
var sync_rotation: Vector3

var health = 100
var max_health = 100
var ammo = 30
var max_ammo = 30
var fire_rate = 0.1
var fire_timer = 0.0
var damage = 25
var reload_time = 2.0
var reload_timer = 0.0
var is_reloading = false

# Respawn system
var respawn_height = -20.0
var respawn_position = Vector3(0, 1.1, 0)

# Multiplayer RPC functions
@rpc("any_peer", "call_remote", "unreliable_ordered")
func sync_player_state(pos: Vector3, rot: Vector3):
	if not is_multiplayer_authority():
		sync_position = pos
		sync_rotation = rot

@rpc("any_peer", "call_remote", "reliable")
func sync_shoot(hit_pos: Vector3):
	if not is_multiplayer_authority():
		if is_inside_tree():
			create_impact_effect(hit_pos)
			show_muzzle_flash()

@rpc("any_peer", "call_remote", "reliable")
func sync_take_damage(damage_amount: int):
	if is_multiplayer_authority():
		take_damage(damage_amount)

func _ready():
	# Only capture mouse for the local player
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	velocity = Vector3.ZERO
	
	# Ensure proper collision settings
	floor_max_angle = 0.785398
	floor_snap_length = 2.0
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true
	safe_margin = 0.1
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	platform_floor_layers = 2

func _physics_process(delta):
	# Only process input for the local player
	if not is_multiplayer_authority():
		# For remote players, interpolate to sync position
		global_position = global_position.lerp(sync_position, delta * 10)
		rotation = rotation.lerp(sync_rotation, delta * 10)
		return
	
	# Handle reload timer
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			complete_reload()
	
	# Handle fire timer
	if fire_timer > 0.0:
		fire_timer -= delta
	
	# Handle reload input
	if Input.is_action_just_pressed("reload") and can_reload():
		start_reload()
	
	# Handle shooting
	if Input.is_action_pressed("shoot") and can_fire():
		fire()
	
	# Always apply gravity first
	velocity.y += get_gravity().y * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Cap falling speed
	velocity.y = clamp(velocity.y, -50.0, 50.0)

	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	# Sync position to other players
	sync_player_state.rpc(global_position, rotation)
	
	check_respawn_conditions()

func _input(event):
	if not is_multiplayer_authority():
		return
		
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func can_fire() -> bool:
	return fire_timer <= 0.0 and ammo > 0 and not is_reloading

func fire():
	if not can_fire():
		return
	
	ammo -= 1
	fire_timer = fire_rate
	
	show_muzzle_flash()
	add_screen_shake()
	
	var space_state = camera.get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + camera.global_transform.basis.z * -1000.0
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b1110  # Hit layers 2,3,4 (Environment, Enemies, Projectiles)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_position = result.position
		var collider = result.collider
		
		print("Shot hit at: ", hit_position, " collider: ", collider.name if collider else "none")
		
		create_impact_effect(hit_position)
		sync_shoot.rpc(hit_position)  # Sync to other players
		
		if collider and collider.has_method("take_damage"):
			collider.take_damage(damage)
			print("Damage dealt to: ", collider.name)
	else:
		print("Shot missed - no collision detected")

func take_damage(damage_amount: int):
	health -= damage_amount
	health = max(0, health)
	print("Player took ", damage_amount, " damage! Health: ", health, "/", max_health)
	
	if health <= 0:
		die()

func die():
	print("Player died!")
	get_tree().reload_current_scene()

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func get_ammo() -> int:
	return ammo

func check_respawn_conditions():
	if global_position.y < respawn_height:
		respawn_player()

func respawn_player():
	print("Player fell through map! Respawning at safe location...")
	global_position = respawn_position
	velocity = Vector3.ZERO
	take_damage(20)
	show_respawn_effect()

func show_respawn_effect():
	var mesh_instance = $MeshInstance3D
	var original_material = mesh_instance.material_override
	
	var flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color.WHITE
	flash_material.emission_enabled = true
	flash_material.emission = Color.WHITE
	mesh_instance.material_override = flash_material
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.2
	timer.one_shot = true
	timer.timeout.connect(func():
		mesh_instance.material_override = original_material
		timer.queue_free()
	)
	timer.start()

func can_reload() -> bool:
	return not is_reloading and ammo < max_ammo

func start_reload():
	if not can_reload():
		return
	
	is_reloading = true
	reload_timer = reload_time
	print("Reloading... (", reload_time, " seconds)")
	
	var weapon_model = camera.get_node_or_null("WeaponModel")
	if weapon_model:
		weapon_model.visible = false

func complete_reload():
	is_reloading = false
	ammo = max_ammo
	print("Reload complete! Ammo: ", ammo)
	
	var weapon_model = camera.get_node_or_null("WeaponModel")
	if weapon_model:
		weapon_model.visible = true

func get_is_reloading() -> bool:
	return is_reloading

func get_reload_progress() -> float:
	if not is_reloading:
		return 0.0
	return 1.0 - (reload_timer / reload_time)

func show_muzzle_flash():
	var muzzle_flash = camera.get_node_or_null("MuzzleFlash")
	if not muzzle_flash:
		return
		
	muzzle_flash.visible = true
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.05
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
		if is_instance_valid(timer):
			timer.queue_free()
	)
	timer.start()

func add_screen_shake():
	var shake_amount = 0.02
	var original_pos = camera.position
	
	camera.position = original_pos + Vector3(
		randf_range(-shake_amount, shake_amount),
		randf_range(-shake_amount, shake_amount),
		0
	)
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.timeout.connect(func():
		camera.position = original_pos
		timer.queue_free()
	)
	timer.start()

func create_impact_effect(position: Vector3):
	if not is_inside_tree():
		return
		
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
		
	var impact_node = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2  # Made bigger
	sphere_mesh.height = 0.4
	
	var impact_material = StandardMaterial3D.new()
	impact_material.albedo_color = Color.YELLOW
	impact_material.emission_enabled = true
	impact_material.emission = Color.YELLOW
	impact_material.emission_energy = 3.0  # Brighter emission
	
	impact_node.mesh = sphere_mesh
	impact_node.material_override = impact_material
	impact_node.global_position = position
	
	tree.current_scene.add_child(impact_node)
	
	var timer = Timer.new()
	tree.current_scene.add_child(timer)
	timer.wait_time = 1.0  # Made longer lasting
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(impact_node):
			impact_node.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	)
	timer.start()
