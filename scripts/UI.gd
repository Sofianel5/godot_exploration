extends Control

@onready var health_bar = $HealthBar
@onready var health_label = $HealthBar/HealthLabel
@onready var ammo_label = $AmmoLabel
@onready var crosshair = $Crosshair

var player: Node3D

func _ready():
	# Find the local player (the one with authority)
	call_deferred("find_local_player")

func find_local_player():
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.is_multiplayer_authority():
			player = p
			print("UI found local player: ", p.name)
			break
	
	if not player:
		# Fallback to first player if no authority found
		if players.size() > 0:
			player = players[0]
			print("UI using fallback player: ", player.name)

func _process(_delta):
	if not player or not is_instance_valid(player):
		find_local_player()
		return
		
	if player:
		update_health_display()
		update_ammo_display()

func update_health_display():
	if not player.has_method("get_health"):
		return
		
	var current_health = player.get_health()
	var max_health = player.get_max_health()
	
	health_label.text = str(current_health) + "/" + str(max_health)
	
	if max_health > 0:
		health_bar.value = (float(current_health) / float(max_health)) * 100

func update_ammo_display():
	if not player.has_method("get_ammo"):
		return
		
	var current_ammo = player.get_ammo()
	
	# Check if reloading
	if player.has_method("get_is_reloading") and player.get_is_reloading():
		var progress = 0.0
		if player.has_method("get_reload_progress"):
			progress = player.get_reload_progress()
		
		var percent = int(progress * 100)
		ammo_label.text = "Reloading... " + str(percent) + "%"
		ammo_label.modulate = Color.YELLOW
	else:
		ammo_label.text = "Ammo: " + str(current_ammo)
		ammo_label.modulate = Color.WHITE