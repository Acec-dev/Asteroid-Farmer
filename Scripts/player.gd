extends CharacterBody2D

# --- Movement (left stick / WASD) ---
@export var max_speed: float = 600.0
@export var acceleration: float = 2400.0
@export var friction: float = 1800.0

# --- Mineral Deposit System ---
@export var minerals_per_drop: int = 5  # How many minerals to drop per button press
@export var drop_spread: float = 30.0  # Horizontal spread of dropped minerals
var _nearby_deposit_box: Node2D = null  # Reference to deposit box we're near

# --- Components ---
var weapon_manager: WeaponManager = null
var shield_component: ShieldComponent = null
var radar_component: RadarComponent = null
var main_camera: Camera2D = null  # Reference to main camera for bounds
var graphs_panel: Node = null  # Reference to graphs panel for dynamic bounds

# --- Utility ---
var FloatingText2D := preload("res://Scenes/floating_text_2d.tscn")
var _vel: Vector2 = Vector2.ZERO
var _mouse_delta := Vector2.ZERO
var _railgun_key_was_pressed: bool = false  # Edge detection for railgun firing

# --- Bubble Shield ---
@export var bubble_shield_radius: float = 80.0
var bubble_shield_active: bool = false
const _MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

@export var mouse_move_threshold := 0.5  # pixels per frame

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative

func _draw() -> void:
	var points = PackedVector2Array([
		Vector2(60, 0),
		Vector2(-20, -16),
		Vector2(-20, 16),
		Vector2(60, 0)
	])
	draw_polyline(points, Color.WHITE)

	if bubble_shield_active:
		# Bubble is in world space; counter-rotate so it stays a perfect circle
		# regardless of ship rotation.
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		draw_arc(Vector2.ZERO, bubble_shield_radius, 0.0, TAU, 64, Color.WHITE, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _ready() -> void:
	add_to_group("player")

	# Get reference to main camera for bounds checking
	main_camera = get_viewport().get_camera_2d()

	# Initialize component systems
	_setup_weapon_system()
	_setup_shield_system()
	_setup_radar_system()

	# Connect to graphs panel bounds change signal
	_connect_to_graphs_panel()

func _physics_process(delta: float) -> void:
	_handle_move(delta)
	_handle_aim()
	_handle_mineral_deposit()
	_handle_weapon_input()
	_handle_bubble_shield_collisions()
	_mouse_delta = Vector2.ZERO  # Reset after processing

## Setup weapon management system
func _setup_weapon_system() -> void:
	# Create weapon manager
	weapon_manager = WeaponManager.new()
	weapon_manager.name = "WeaponManager"
	weapon_manager.owner_node = self
	add_child(weapon_manager)

	# Add all weapons
	var primary = PrimaryCannon.new()
	weapon_manager.add_weapon(primary, "primary")

	var laser = LaserBeam.new()
	weapon_manager.add_weapon(laser, "secondary")

	var rockets = RocketLauncher.new()
	weapon_manager.add_weapon(rockets, "secondary")

	var mines = MineLayer.new()
	weapon_manager.add_weapon(mines, "secondary")

	var railgun = Railgun.new()
	weapon_manager.add_weapon(railgun, "secondary")

	# Bind input to weapons (mines auto-place, no input needed)
	weapon_manager.bind_input("fire_laser", "Laser Beam")
	weapon_manager.bind_input("fire_railgun", "Railgun")

	# Sync with GameState upgrades
	weapon_manager.sync_upgrades()

	print("Player: Weapon system initialized with ", weapon_manager.weapons.size(), " weapons")

## Setup shield component
func _setup_shield_system() -> void:
	shield_component = ShieldComponent.new()
	shield_component.name = "ShieldComponent"
	shield_component.set_owner_node(self)
	add_child(shield_component)

	print("Player: Shield component initialized")

## Setup radar component
func _setup_radar_system() -> void:
	radar_component = RadarComponent.new()
	radar_component.name = "RadarComponent"
	add_child(radar_component)

	print("Player: Radar component initialized")

## Connect to graphs panel for bounds updates
func _connect_to_graphs_panel() -> void:
	# Find the graphs panel in the scene tree
	var graphs_panels = get_tree().get_nodes_in_group("graphs_panel")
	if graphs_panels.size() > 0:
		graphs_panel = graphs_panels[0]
		if graphs_panel.has_signal("camera_bounds_changed"):
			graphs_panel.camera_bounds_changed.connect(_on_camera_bounds_changed)
			print("Player: Connected to graphs panel bounds signal")
	else:
		# Try alternative path if not in a group
		var canvas_layer = get_tree().get_first_node_in_group("ui_layer")
		if not canvas_layer:
			# Try to find by path (GraphsPanel is under CanvasLayer)
			var scene_root = get_tree().current_scene
			if scene_root:
				graphs_panel = scene_root.find_child("GraphsPanel", true, false)
				if graphs_panel and graphs_panel.has_signal("camera_bounds_changed"):
					graphs_panel.camera_bounds_changed.connect(_on_camera_bounds_changed)
					print("Player: Connected to graphs panel bounds signal")

## Called when camera bounds change (e.g., when graphs panel slides in/out)
func _on_camera_bounds_changed() -> void:
	# Immediately clamp when bounds change
	_clamp_to_camera_bounds()

## Immediately clamp player position to camera bounds
func _clamp_to_camera_bounds() -> void:
	if not main_camera:
		return

	# Clamp to camera limits
	global_position.x = clampf(global_position.x, main_camera.limit_left, main_camera.limit_right)
	global_position.y = clampf(global_position.y, main_camera.limit_top, main_camera.limit_bottom)

## Handle weapon input
func _handle_weapon_input() -> void:
	# While the bubble shield is up, the player cannot fire and auto-fire is
	# suppressed by WeaponManager.weapons_blocked.
	if bubble_shield_active:
		return

	# Primary weapon auto-fires (already handled by weapon manager)

	# Laser - right mouse button
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		weapon_manager.activate_weapon("Laser Beam")
	else:
		weapon_manager.deactivate_weapon("Laser Beam")

	# Mines auto-place at intervals (no manual input needed)

	# Railgun - R key (manual fire with edge detection)
	var r_pressed = Input.is_physical_key_pressed(KEY_R)
	if r_pressed and not _railgun_key_was_pressed:
		weapon_manager.activate_weapon("Railgun")
		# Deactivate immediately (it's a one-shot weapon)
		await get_tree().process_frame
		weapon_manager.deactivate_weapon("Railgun")
	_railgun_key_was_pressed = r_pressed

func _handle_move(delta: float) -> void:
	# Bubble shield freezes the player. To cancel it, the player must
	# *intentionally* press a movement key (just-pressed edge), so a movement
	# key already held from before activation will not cancel.
	if bubble_shield_active:
		_vel = Vector2.ZERO
		for action in _MOVE_ACTIONS:
			if Input.is_action_just_pressed(action):
				_deactivate_bubble_shield()
				break
		_clamp_to_camera_bounds()
		if bubble_shield_active:
			return
		# Fall through to normal movement this frame using the just-pressed input.

	# WASD movement - completely independent of aiming
	var speed_mult := GameState.get_speed_multiplier()
	var effective_max_speed := max_speed * speed_mult
	var effective_accel := acceleration * speed_mult
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input != Vector2.ZERO:
		_vel = _vel.move_toward(move_input.normalized() * effective_max_speed, effective_accel * delta)
	else:
		_vel = _vel.move_toward(Vector2.ZERO, friction * delta)
	# Clamp velocity if encumbrance reduced max speed below current velocity
	if _vel.length() > effective_max_speed:
		_vel = _vel.normalized() * effective_max_speed
	global_position += _vel * delta

	# Clamp player position to camera bounds
	_clamp_to_camera_bounds()

func _handle_aim() -> void:
	# Ship only rotates when you MOVE the mouse, not constantly
	if _mouse_delta.length() > 0.1:  # Only if mouse actually moved
		var mouse_pos := get_global_mouse_position()
		var direction := (mouse_pos - global_position).normalized()
		rotation = direction.angle()

func popup_mineral(mineral_name: String) -> void:
	var ft := FloatingText2D.instantiate()
	# Add to owner's scene root (works with SubViewport)
	var scene_root = owner if owner else get_tree().current_scene
	scene_root.add_child(ft)
	var start := global_position
	ft.show_text(mineral_name, start)

func popup_cargo_full() -> void:
	var ft := FloatingText2D.instantiate()
	var scene_root = owner if owner else get_tree().current_scene
	scene_root.add_child(ft)
	var start := global_position
	if GameState.is_over_encumbered():
		ft.show_custom_text("OVER-ENCUMBERED", start)
	else:
		ft.show_custom_text("CARGO FULL", start)

# === Mineral Deposit System ===

func _handle_mineral_deposit() -> void:
	"""Check for nearby deposit boxes and handle mineral dropping"""
	# Find nearby deposit box
	_nearby_deposit_box = null
	var boxes = get_tree().get_nodes_in_group("mineral_deposit_box")
	for box in boxes:
		if box.has_method("is_player_in_range") and box.is_player_in_range():
			_nearby_deposit_box = box
			break

	# Handle deposit input (E key or Space)
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
		if _nearby_deposit_box:
			_drop_minerals()

func _drop_minerals() -> void:
	"""Drop minerals from the player ship into the deposit box below"""
	# Check if player has any minerals to drop
	var has_minerals = false
	for count in GameState.minerals.values():
		if count > 0:
			has_minerals = true
			break

	if not has_minerals:
		print("No minerals to deposit!")
		return

	# Drop up to minerals_per_drop minerals
	var dropped_count = 0
	for mineral_type in GameState.minerals.keys():
		var available = GameState.minerals[mineral_type]
		if available <= 0:
			continue

		# Calculate how many of this type to drop
		var to_drop = min(available, minerals_per_drop - dropped_count)
		if to_drop <= 0:
			break

		# Spawn falling minerals
		for i in range(to_drop):
			_spawn_falling_mineral(mineral_type)
			dropped_count += 1

		# Remove from GameState inventory
		GameState.minerals[mineral_type] -= to_drop
		GameState.emit_signal("inventory_changed")

		if dropped_count >= minerals_per_drop:
			break

	if dropped_count > 0:
		print("Dropped ", dropped_count, " minerals!")

func _spawn_falling_mineral(mineral_type: GameState.MineralType) -> void:
	"""Spawn a single falling mineral that drops from the ship"""
	var falling_mineral_script = load("res://falling_mineral.gd")
	var mineral = Node2D.new()
	mineral.set_script(falling_mineral_script)
	mineral.set("kind", mineral_type)

	# Spawn slightly below the ship with random horizontal offset
	var offset_x = randf_range(-drop_spread, drop_spread)
	mineral.global_position = global_position + Vector2(offset_x, 20)

	# Give it a small initial velocity (downward + some horizontal)
	var initial_vel = Vector2(randf_range(-20, 20), 50)
	if mineral.has_method("set_initial_velocity"):
		mineral.set_initial_velocity(initial_vel)

	# Add to owner's scene root (works with SubViewport)
	var scene_root = owner if owner else get_tree().current_scene
	scene_root.add_child(mineral)

## Damage forwarding to shield component
func take_damage(amount: float) -> void:
	if bubble_shield_active:
		return
	if shield_component:
		shield_component.take_damage(amount)

# === Bubble Shield ===

func is_bubble_shield_active() -> bool:
	return bubble_shield_active

func toggle_bubble_shield() -> void:
	if bubble_shield_active:
		_deactivate_bubble_shield()
	else:
		_activate_bubble_shield()

func _activate_bubble_shield() -> void:
	bubble_shield_active = true
	# Stop the ship so the shield doesn't drift, and so the player can hold the
	# bubble even if they were moving when they triggered it.
	_vel = Vector2.ZERO
	if weapon_manager:
		# weapons_blocked suppresses firing without touching each weapon's
		# _is_active flag, so auto-firing weapons resume on their own when the
		# shield drops.
		weapon_manager.weapons_blocked = true
	queue_redraw()

func _deactivate_bubble_shield() -> void:
	bubble_shield_active = false
	if weapon_manager:
		weapon_manager.weapons_blocked = false
	queue_redraw()

func _handle_bubble_shield_collisions() -> void:
	if not bubble_shield_active:
		return
	var asteroids = get_tree().get_nodes_in_group("asteroids")
	for ast in asteroids:
		if not is_instance_valid(ast):
			continue
		var ast_radius: float = ast.radius if "radius" in ast else 0.0
		var combined := bubble_shield_radius + ast_radius
		if global_position.distance_squared_to(ast.global_position) <= combined * combined:
			if ast.has_method("break_no_minerals"):
				ast.break_no_minerals()

# === LEGACY FUNCTIONS FOR BACKWARD COMPATIBILITY ===
# These are kept for any existing code that might call them

func enable_laser():
	"""Legacy function - now handled by upgrade system"""
	GameState.unlock_weapon("Laser Beam")

func enable_rockets():
	"""Legacy function - now handled by upgrade system"""
	GameState.unlock_weapon("Rocket Launcher")

func enable_mines():
	"""Legacy function - now handled by upgrade system"""
	GameState.unlock_weapon("Mine Layer")
