# FPS Game - Godot with Rust

A basic first-person shooter game built with Godot 4.3 and Rust integration.

## Features

- **First-person player controller** with mouse look and WASD movement
- **Weapon system** with shooting mechanics and raycasting
- **Basic enemy AI** with pathfinding and attack behavior
- **UI system** with crosshair, health bar, and ammo counter
- **3D environment** with walls and ground for gameplay

## Controls

- **WASD** - Move
- **Mouse** - Look around
- **Space** - Jump
- **Left Mouse** - Shoot
- **Enter** - Reload (placeholder)
- **Escape** - Toggle mouse capture

## Project Structure

```
godot_fps/
├── scenes/           # Godot scene files
│   ├── Main.tscn    # Main game scene
│   ├── Player.tscn  # Player controller
│   ├── Enemy.tscn   # Enemy AI
│   ├── Weapon.tscn  # Weapon system
│   └── UI.tscn      # User interface
├── rust/            # Rust source code
│   ├── src/
│   │   ├── lib.rs   # Main library file
│   │   ├── player.rs # Player controller (Rust version)
│   │   ├── weapon.rs # Weapon system (Rust version)
│   │   └── enemy.rs  # Enemy AI (Rust version)
│   └── Cargo.toml   # Rust dependencies
└── project.godot    # Godot project configuration
```

## How to Run

1. Open the project in Godot 4.3+
2. The game uses GDScript for immediate compatibility
3. For Rust integration, you would need to:
   - Install Rust and cargo
   - Build the Rust library: `cd rust && cargo build`
   - Configure GDExtension in Godot

## Game Mechanics

- **Player**: Move around the 3D environment, aim with mouse, shoot enemies
- **Enemies**: AI-controlled characters that detect, chase, and attack the player
- **Weapons**: Raycast-based shooting system with ammo management
- **Health**: Both player and enemies have health systems
- **Physics**: Gravity, collision detection, and movement physics

## Notes

This is a basic FPS framework. You can extend it by adding:
- More weapon types
- Better enemy AI
- Particle effects
- Sound system
- Level progression
- Multiplayer support