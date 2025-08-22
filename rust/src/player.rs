use godot::prelude::*;

#[derive(GodotClass)]
#[class(base=CharacterBody3D)]
pub struct Player {
    #[var]
    pub speed: f32,
    #[var]
    pub jump_velocity: f32,
    #[var]
    pub mouse_sensitivity: f32,
    
    base: Base<CharacterBody3D>,
    camera: Option<Gd<Camera3D>>,
    mesh: Option<Gd<MeshInstance3D>>,
}

#[godot_api]
impl ICharacterBody3D for Player {
    fn init(base: Base<CharacterBody3D>) -> Self {
        Self {
            speed: 5.0,
            jump_velocity: 4.5,
            mouse_sensitivity: 0.003,
            base,
            camera: None,
            mesh: None,
        }
    }

    fn ready(&mut self) {
        // Get camera reference
        if let Some(camera_node) = self.base().get_node_as::<Camera3D>("Camera3D") {
            self.camera = Some(camera_node);
        }
        
        // Get mesh reference
        if let Some(mesh_node) = self.base().get_node_as::<MeshInstance3D>("MeshInstance3D") {
            self.mesh = Some(mesh_node);
        }
        
        // Capture mouse
        Input::singleton().set_mouse_mode(input::MouseMode::CAPTURED);
    }

    fn physics_process(&mut self, delta: f64) {
        let input = Input::singleton();
        let mut velocity = self.base().get_velocity();
        
        // Handle gravity
        if !self.base().is_on_floor() {
            velocity.y -= self.base().get_gravity().y * delta as f32;
        }
        
        // Handle jump
        if input.is_action_just_pressed("jump".into()) && self.base().is_on_floor() {
            velocity.y = self.jump_velocity;
        }
        
        // Handle movement
        let mut input_dir = Vector2::ZERO;
        if input.is_action_pressed("move_right".into()) {
            input_dir.x += 1.0;
        }
        if input.is_action_pressed("move_left".into()) {
            input_dir.x -= 1.0;
        }
        if input.is_action_pressed("move_backward".into()) {
            input_dir.y += 1.0;
        }
        if input.is_action_pressed("move_forward".into()) {
            input_dir.y -= 1.0;
        }
        
        let transform = self.base().get_global_transform();
        let forward = -transform.basis.col_c().normalized();
        let right = transform.basis.col_a().normalized();
        
        if input_dir != Vector2::ZERO {
            velocity.x = (right.x * input_dir.x + forward.x * input_dir.y) * self.speed;
            velocity.z = (right.z * input_dir.x + forward.z * input_dir.y) * self.speed;
        } else {
            velocity.x = velocity.x * 0.85; // Simple friction
            velocity.z = velocity.z * 0.85;
        }
        
        self.base_mut().set_velocity(velocity);
        self.base_mut().move_and_slide();
    }

    fn input(&mut self, event: Gd<InputEvent>) {
        if let Ok(mouse_event) = event.try_cast::<InputEventMouseMotion>() {
            let relative = mouse_event.get_relative();
            
            // Rotate the player body horizontally
            self.base_mut().rotate_y(-relative.x * self.mouse_sensitivity);
            
            // Rotate the camera vertically
            if let Some(ref mut camera) = self.camera {
                let current_rotation = camera.get_rotation();
                let new_x = (current_rotation.x - relative.y * self.mouse_sensitivity).clamp(-1.5, 1.5);
                camera.set_rotation(Vector3::new(new_x, current_rotation.y, current_rotation.z));
            }
        }
        
        // Toggle mouse capture with Escape
        if let Ok(key_event) = event.try_cast::<InputEventKey>() {
            if key_event.get_keycode() == Key::ESCAPE && key_event.is_pressed() {
                let current_mode = Input::singleton().get_mouse_mode();
                if current_mode == input::MouseMode::CAPTURED {
                    Input::singleton().set_mouse_mode(input::MouseMode::VISIBLE);
                } else {
                    Input::singleton().set_mouse_mode(input::MouseMode::CAPTURED);
                }
            }
        }
    }
}

#[godot_api]
impl Player {
    #[func]
    pub fn get_camera(&self) -> Option<Gd<Camera3D>> {
        self.camera.clone()
    }
}