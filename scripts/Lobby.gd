extends Control

@onready var host_button = $VBoxContainer/HostButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var address_input = $VBoxContainer/LineEdit
@onready var status_label = $VBoxContainer/StatusLabel

const PORT = 8910
const MAX_CLIENTS = 4

func _ready():
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		status_label.text = "Failed to host: " + str(error)
		return
	
	multiplayer.multiplayer_peer = peer
	status_label.text = "Hosting on port " + str(PORT)
	
	# Host automatically starts the game
	call_deferred("start_game")

func _on_join_pressed():
	var address = address_input.text
	if address.is_empty():
		status_label.text = "Please enter an IP address"
		return
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		status_label.text = "Failed to connect: " + str(error)
		return
	
	multiplayer.multiplayer_peer = peer
	status_label.text = "Connecting to " + address + "..."

func _on_peer_connected(id: int):
	status_label.text = "Player " + str(id) + " connected"

func _on_peer_disconnected(id: int):
	status_label.text = "Player " + str(id) + " disconnected"

func _on_connected_to_server():
	status_label.text = "Connected to server! Starting game..."
	call_deferred("start_game")

func _on_connection_failed():
	status_label.text = "Failed to connect to server"

func start_game():
	# Switch to the main game scene
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
