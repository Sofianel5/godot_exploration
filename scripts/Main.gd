extends Node3D

var enemy_scene = preload("res://scenes/Enemy.tscn")

@onready var multiplayer_spawner = $MultiplayerSpawner
@onready var enemy_spawner = $EnemySpawner
@onready var players_node = $Players
@onready var enemies_node = $Enemies

var player_spawn_points = [
	Vector3(0, 1.1, 0),     # Host spawn
	Vector3(5, 1.1, 0),     # Client spawn  
	Vector3(-5, 1.1, 0),    # Additional spawns
	Vector3(0, 1.1, 5)
]

var spawn_points = [
	Vector3(5, 1.0, 5),      # Clear area 
	Vector3(-5, 1.0, -5),    # Clear area  
	Vector3(12, 1.0, -3),    # Open area
	Vector3(-12, 1.0, 3),    # Open area
	Vector3(0, 1.0, 15),     # Open center-south
	Vector3(0, 1.0, -15),    # Open center-north
	Vector3(15, 1.0, 0),     # Open center-east
	Vector3(-15, 1.0, 0),    # Open center-west
	Vector3(6, 1.0, -8),     # Open area
	Vector3(-6, 1.0, 5)      # Clear area near center
]

func _ready():
	print("Urban combat environment loaded")
	
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Remove the existing player from the scene  
	var existing_player = players_node.get_node_or_null("Player")
	if existing_player:
		existing_player.queue_free()
	
	# Make sure there's at least one enemy
	print("Enemies node children count: ", enemies_node.get_children().size())
	for child in enemies_node.get_children():
		print("Found enemy child: ", child.name, " at position: ", child.global_position)
	
	if enemies_node.get_children().size() == 0:
		print("No enemies found, spawning initial enemy")
		call_deferred("spawn_initial_enemy")
	else:
		print("Enemies already exist, not spawning new one")
	
	# Spawn players for all connected peers
	call_deferred("spawn_all_players")
	
	# Debug: Print all nodes in 5 seconds
	var debug_timer = Timer.new()
	add_child(debug_timer)
	debug_timer.wait_time = 5.0
	debug_timer.one_shot = true
	debug_timer.timeout.connect(debug_scene_nodes)
	debug_timer.start()

func _on_peer_connected(id: int):
	print("Player ", id, " connected")
	# Spawn player for new peer
	call_deferred("spawn_player_for_peer", id)

func _on_peer_disconnected(id: int):
	print("Player ", id, " disconnected")
	# Remove disconnected player
	var player_node = players_node.get_node_or_null("Player_" + str(id))
	if player_node:
		player_node.queue_free()

func spawn_all_players():
	# Spawn local player (host)
	spawn_player_for_peer(multiplayer.get_unique_id())
	
	# Spawn players for all connected peers
	for peer_id in multiplayer.get_peers():
		spawn_player_for_peer(peer_id)

func spawn_player_for_peer(peer_id: int):
	var player = preload("res://scenes/Player.tscn").instantiate()
	player.name = "Player_" + str(peer_id)
	player.set_multiplayer_authority(peer_id)
	
	# Set spawn position based on peer ID
	var spawn_index = peer_id % player_spawn_points.size()
	player.global_position = player_spawn_points[spawn_index]
	
	players_node.add_child(player)
	print("Spawned player for peer: ", peer_id, " at position: ", player.global_position)

func on_enemy_died():
	# Only host spawns enemies
	if not multiplayer.is_server():
		return
		
	print("Enemy eliminated! Spawning reinforcement...")
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(spawn_new_enemy)
	timer.timeout.connect(func(): timer.queue_free())
	timer.start()

func spawn_new_enemy():
	if not multiplayer.is_server():
		return
		
	var spawn_pos = spawn_points[randi() % spawn_points.size()]
	var new_enemy = enemy_scene.instantiate()
	new_enemy.global_position = spawn_pos
	new_enemy.velocity = Vector3.ZERO
	enemies_node.add_child(new_enemy)
	
	print("Reinforcement deployed at: ", spawn_pos)

func spawn_initial_enemy():
	print("spawn_initial_enemy called")
	var spawn_pos = Vector3(10, 1.0, 8)  # Default enemy position
	var new_enemy = enemy_scene.instantiate()
	if not new_enemy:
		print("ERROR: Failed to instantiate enemy scene!")
		return
		
	new_enemy.name = "InitialEnemy"
	new_enemy.global_position = spawn_pos
	new_enemy.velocity = Vector3.ZERO
	enemies_node.add_child(new_enemy)
	print("Initial enemy spawned at: ", spawn_pos, " enemy name: ", new_enemy.name)
	print("Enemy added to enemies_node, new child count: ", enemies_node.get_children().size())

func debug_scene_nodes():
	print("\n=== SCENE DEBUG ===")
	print("Players node children: ", players_node.get_children().size())
	for child in players_node.get_children():
		print("  Player: ", child.name, " at ", child.global_position)
	
	print("Enemies node children: ", enemies_node.get_children().size())  
	for child in enemies_node.get_children():
		print("  Enemy: ", child.name, " at ", child.global_position)
	
	print("All enemies in scene:")
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	print("  Enemies group size: ", all_enemies.size())
	for enemy in all_enemies:
		print("  Enemy in group: ", enemy.name, " at ", enemy.global_position, " parent: ", enemy.get_parent().name)
	print("==================\n")