use godot::prelude::*;

mod player;
mod weapon;
mod enemy;

struct FpsGameExtension;

#[gdextension]
unsafe impl ExtensionLibrary for FpsGameExtension {}