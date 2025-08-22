use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=Node3D)]
pub struct Weapon {
    #[var]
    pub damage: i32,
    #[var]
    pub fire_rate: f32,
    #[var]
    pub ammo: i32,
    #[var]
    pub max_ammo: i32,
    
    base: Base<Node3D>,
    fire_timer: f32,
    muzzle_flash: Option<Gd<MeshInstance3D>>,
    camera: Option<Gd<Camera3D>>,
}

#[godot_api]
impl INode3D for Weapon {
    fn init(base: Base<Node3D>) -> Self {
        Self {
            damage: 25,
            fire_rate: 0.1, // Time between shots
            ammo: 30,
            max_ammo: 30,
            base,
            fire_timer: 0.0,
            muzzle_flash: None,
            camera: None,
        }
    }

    fn ready(&mut self) {
        // Get muzzle flash reference
        if let Some(muzzle_node) = self.base().get_node_as::<MeshInstance3D>("MuzzleFlash") {
            self.muzzle_flash = Some(muzzle_node);
            // Hide muzzle flash initially
            if let Some(ref mut flash) = self.muzzle_flash {
                flash.set_visible(false);
            }
        }
        
        // Get camera reference from parent player
        if let Some(parent) = self.base().get_parent() {
            if let Some(camera_node) = parent.get_node_as::<Camera3D>("Camera3D") {
                self.camera = Some(camera_node);
            }
        }
    }

    fn process(&mut self, delta: f64) {
        if self.fire_timer > 0.0 {
            self.fire_timer -= delta as f32;
        }
        
        let input = Input::singleton();
        if input.is_action_pressed("shoot".into()) && self.can_fire() {
            self.fire();
        }
    }
}

#[godot_api]
impl Weapon {
    #[func]
    pub fn can_fire(&self) -> bool {
        self.fire_timer <= 0.0 && self.ammo > 0
    }
    
    #[func]
    pub fn fire(&mut self) {
        if !self.can_fire() {
            return;
        }
        
        self.ammo -= 1;
        self.fire_timer = self.fire_rate;
        
        // Show muzzle flash
        self.show_muzzle_flash();
        
        // Perform raycast
        self.raycast_shot();
        
        // Emit signal for UI updates
        self.base_mut().emit_signal("weapon_fired".into(), &[self.ammo.to_variant()]);
    }
    
    #[func]
    pub fn reload(&mut self) {
        self.ammo = self.max_ammo;
        self.base_mut().emit_signal("weapon_reloaded".into(), &[self.ammo.to_variant()]);
    }
    
    fn show_muzzle_flash(&mut self) {
        if let Some(ref mut flash) = self.muzzle_flash {
            flash.set_visible(true);
            
            // Hide after a short time (we'll use a timer in the scene)
            let mut tween = self.base().create_tween();
            if let Some(mut tween) = tween {
                tween.tween_callback(Callable::from_object_method(&flash.clone(), "set_visible"), &[false.to_variant()], 0.05);
            }
        }
    }
    
    fn raycast_shot(&mut self) {
        if let Some(ref camera) = self.camera {
            let space_state = camera.get_world_3d().unwrap().get_direct_space_state().unwrap();
            
            // Cast ray from camera center
            let from = camera.get_global_position();
            let to = from + camera.get_global_transform().basis.col_c() * -1000.0;
            
            let mut query = PhysicsRayQueryParameters3D::create(from, to).unwrap();
            query.set_collision_mask(0b1110); // Hit everything except player
            
            let result = space_state.intersect_ray(query);
            
            if !result.is_empty() {
                let hit_point = result.get("position").unwrap().to::<Vector3>();
                let collider = result.get("collider").unwrap();
                
                // Check if we hit an enemy
                if let Ok(enemy_node) = collider.try_to::<Gd<Node>>() {
                    if enemy_node.has_method("take_damage".into()) {
                        enemy_node.call("take_damage".into(), &[self.damage.to_variant()]);
                    }
                }
                
                // Create hit effect at hit point
                self.create_hit_effect(hit_point);
            }
        }
    }
    
    fn create_hit_effect(&self, position: Vector3) {
        // Simple hit effect - in a real game you'd spawn particles or decals
        godot_print!("Hit at position: {}", position);
    }
    
    #[signal]
    fn weapon_fired(ammo_left: i32);
    
    #[signal]
    fn weapon_reloaded(ammo: i32);
}