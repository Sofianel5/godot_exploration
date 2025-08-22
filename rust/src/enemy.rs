use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=CharacterBody3D)]
pub struct Enemy {
    #[var]
    pub health: i32,
    #[var]
    pub max_health: i32,
    #[var]
    pub speed: f32,
    #[var]
    pub attack_damage: i32,
    #[var]
    pub detection_range: f32,
    #[var]
    pub attack_range: f32,
    
    base: Base<CharacterBody3D>,
    player_ref: Option<Gd<Node3D>>,
    state: EnemyState,
    attack_timer: f32,
    nav_agent: Option<Gd<NavigationAgent3D>>,
}

#[derive(PartialEq)]
enum EnemyState {
    Idle,
    Chasing,
    Attacking,
    Dead,
}

#[godot_api]
impl ICharacterBody3D for Enemy {
    fn init(base: Base<CharacterBody3D>) -> Self {
        Self {
            health: 100,
            max_health: 100,
            speed: 3.0,
            attack_damage: 20,
            detection_range: 15.0,
            attack_range: 2.0,
            base,
            player_ref: None,
            state: EnemyState::Idle,
            attack_timer: 0.0,
            nav_agent: None,
        }
    }

    fn ready(&mut self) {
        // Find player in scene
        if let Some(player_node) = self.base().get_tree().unwrap().get_first_node_in_group("player".into()) {
            self.player_ref = Some(player_node.cast::<Node3D>());
        }
        
        // Get navigation agent
        if let Some(nav_node) = self.base().get_node_as::<NavigationAgent3D>("NavigationAgent3D") {
            self.nav_agent = Some(nav_node);
        }
    }

    fn physics_process(&mut self, delta: f64) {
        if self.state == EnemyState::Dead {
            return;
        }
        
        self.update_ai(delta as f32);
        
        let mut velocity = self.base().get_velocity();
        
        // Apply gravity
        if !self.base().is_on_floor() {
            velocity.y -= self.base().get_gravity().y * delta as f32;
        }
        
        // Move towards target if chasing
        if self.state == EnemyState::Chasing {
            if let Some(target_pos) = self.get_next_path_position() {
                let direction = (target_pos - self.base().get_global_position()).normalized();
                velocity.x = direction.x * self.speed;
                velocity.z = direction.z * self.speed;
                
                // Look at target
                self.base_mut().look_at(target_pos, Vector3::UP);
            }
        } else {
            // Apply friction when not moving
            velocity.x *= 0.8;
            velocity.z *= 0.8;
        }
        
        self.base_mut().set_velocity(velocity);
        self.base_mut().move_and_slide();
    }
}

#[godot_api]
impl Enemy {
    fn update_ai(&mut self, delta: f32) {
        if let Some(ref player) = self.player_ref {
            let distance_to_player = self.base().get_global_position().distance_to(player.get_global_position());
            
            match self.state {
                EnemyState::Idle => {
                    if distance_to_player <= self.detection_range {
                        self.state = EnemyState::Chasing;
                        self.set_target_position(player.get_global_position());
                    }
                }
                EnemyState::Chasing => {
                    if distance_to_player > self.detection_range * 1.2 {
                        self.state = EnemyState::Idle;
                    } else if distance_to_player <= self.attack_range {
                        self.state = EnemyState::Attacking;
                        self.attack_timer = 1.0; // 1 second attack cooldown
                    } else {
                        self.set_target_position(player.get_global_position());
                    }
                }
                EnemyState::Attacking => {
                    self.attack_timer -= delta;
                    if self.attack_timer <= 0.0 {
                        self.perform_attack();
                        if distance_to_player > self.attack_range {
                            self.state = EnemyState::Chasing;
                        } else {
                            self.attack_timer = 1.0; // Reset attack timer
                        }
                    }
                }
                EnemyState::Dead => {}
            }
        }
    }
    
    fn set_target_position(&mut self, target: Vector3) {
        if let Some(ref mut nav_agent) = self.nav_agent {
            nav_agent.set_target_position(target);
        }
    }
    
    fn get_next_path_position(&self) -> Option<Vector3> {
        if let Some(ref nav_agent) = self.nav_agent {
            if !nav_agent.is_navigation_finished() {
                return Some(nav_agent.get_next_path_position());
            }
        }
        None
    }
    
    fn perform_attack(&mut self) {
        if let Some(ref player) = self.player_ref {
            // Simple damage dealing - in a real game you'd check if player has health component
            if player.has_method("take_damage".into()) {
                player.call("take_damage".into(), &[self.attack_damage.to_variant()]);
            }
            
            godot_print!("Enemy attacks for {} damage!", self.attack_damage);
        }
    }
    
    #[func]
    pub fn take_damage(&mut self, damage: i32) {
        if self.state == EnemyState::Dead {
            return;
        }
        
        self.health -= damage;
        godot_print!("Enemy took {} damage! Health: {}/{}", damage, self.health, self.max_health);
        
        if self.health <= 0 {
            self.die();
        } else {
            // If damaged, become aggressive
            self.state = EnemyState::Chasing;
        }
        
        self.base_mut().emit_signal("health_changed".into(), &[self.health.to_variant(), self.max_health.to_variant()]);
    }
    
    #[func]
    pub fn die(&mut self) {
        self.state = EnemyState::Dead;
        self.health = 0;
        
        // Disable collision
        self.base_mut().set_collision_layer(0);
        self.base_mut().set_collision_mask(0);
        
        // Play death animation or effect here
        godot_print!("Enemy died!");
        
        self.base_mut().emit_signal("enemy_died".into(), &[]);
        
        // Remove after delay
        let mut tween = self.base().create_tween();
        if let Some(mut tween) = tween {
            tween.tween_callback(Callable::from_object_method(&self.base(), "queue_free"), &[], 2.0);
        }
    }
    
    #[func]
    pub fn get_health(&self) -> i32 {
        self.health
    }
    
    #[func]
    pub fn get_max_health(&self) -> i32 {
        self.max_health
    }
    
    #[signal]
    fn health_changed(current_health: i32, max_health: i32);
    
    #[signal]
    fn enemy_died();
}