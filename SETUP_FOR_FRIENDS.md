# Setup Guide for Friends

## How to play the FPS game from GitHub

### Prerequisites
**Option A: With Godot Editor (Recommended)**
1. Install Godot 4.4+ from https://godotengine.org/
2. Clone or download this repository

**Option B: Command Line Only**
1. Install Godot 4.4+ headless version: `godot --headless --version` to verify
2. Clone or download this repository

### First Time Setup (IMPORTANT!)

**With Godot Editor:**
1. Open Godot Editor
2. Click "Import" and select the `project.godot` file from this folder
3. **WAIT** for Godot to complete importing all assets (you'll see progress in the bottom panel)
4. This process imports all 3D models, textures, and other assets
5. Once import is complete, you can run the game

**Command Line Only:**
1. Navigate to the project folder
2. Run: `godot --headless --import` 
3. **WAIT** for import to complete (this may take 30-60 seconds)
4. Run the game: `godot --main-pack . scenes/Lobby.tscn`

### Playing Multiplayer
1. Host creates a server using their local IP address (not 127.0.0.1)
2. Find your IP with `ifconfig` on Mac/Linux or `ipconfig` on Windows
3. Clients connect to the host's IP address on port 8910
4. Make sure all players are on the same WiFi network

### Controls
- WASD: Move
- Space: Jump  
- Mouse: Look around
- Left Click: Shoot
- R: Reload

## Troubleshooting

### Can't see 3D models/enemies/gun?
- Make sure you opened the project in Godot Editor first and let it import assets
- Don't just run an exported .exe - the assets need to be imported by Godot

### Can't connect to multiplayer?
- Use the host's actual IP address (like 192.168.1.100), not 127.0.0.1
- Make sure firewall allows connections on port 8910
- All players must be on the same network