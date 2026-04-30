# ship_damage_states.gd
# ─────────────────────────────────────────────────────────────────────────────
# Prototype: visual ship damage states keyed off shield percentage.
#
# Three escalating tiers (Bible-aligned, see brainstorm in
# Asteroid_Farmer_Conversation_Handoff.md):
#   • shield >= 50%        → invisible, draws nothing.
#   • shield  < 50%        → 3 jagged crack lines drawn over the ship triangle.
#   • shield  < 25%        → 6 cracks + per-frame ±2px vertex jitter on the
#                            crack endpoints (hull "vibrating apart" feel).
#   • shield <= 10%        → cracks + jitter + flickering 1px outline that
#                            blinks white→transparent at ~8 Hz.
#
# How it hooks in (no core code edits required):
#   1. PrototypeFlags.mount_all() instantiates this prototype as a child of
#      `main` because SHIP_DAMAGE_STATES is on.
#   2. _setup_prototype() connects to GameState.shield_changed(current, max)
#      and searches for the player Node2D.
#   3. Once the player is found, a small Node2D "drawer" is parented under
#      the player so it inherits the ship's position + rotation. The drawer
#      runs its own _draw() to overlay damage marks on top of the existing
#      white triangle. The player's red-flash modulation is untouched.
#
# Read-only on GameState. Removable by deleting this folder + the matching
# mount entry in PrototypeFlags. Nothing else in the codebase knows it exists.
#
# Bible-derived assumptions to verify against the real Player.gd:
#   • Player node's name is "Player" or it's in the "player" group.
#   • The triangle is drawn roughly within a (-12, -14)..(12, 14) bounding
#     box in local space, with apex pointing forward. If the real ship is
#     bigger / smaller / oriented differently, tweak the @export vertices
#     in the editor — no code changes needed.
# ─────────────────────────────────────────────────────────────────────────────

extends "res://Scripts/prototypes/prototype_base.gd"

# ─── Tunables (override per-instance in editor if shape differs) ────────────

# Triangle vertex coords in the player's local space. Defaults assume an
# apex-up ship roughly 24×28 px. Adjust if the real Player draws differently.
@export var apex: Vector2        = Vector2(0, -14)
@export var base_left: Vector2   = Vector2(-12, 14)
@export var base_right: Vector2  = Vector2(12, 14)

# Crack counts at each tier.
@export var crack_count_damaged: int  = 3
@export var crack_count_critical: int = 6

# Jitter amplitude at < 25% shield, in pixels.
@export var jitter_amplitude: float = 2.0

# Flicker timing at <= 10% shield (full on/off cycles per second).
@export var flicker_hz: float = 8.0

# Threshold gates — keep in sync with the bands above.
@export var damaged_threshold: float  = 0.50
@export var critical_threshold: float = 0.25
@export var flicker_threshold: float  = 0.10

# How often to retry finding the Player node when the prototype mounts before
# the player has spawned. 30 retries × 0.1s = 3s ceiling, then we idle.
const _PLAYER_LOOKUP_INTERVAL := 0.1
const _PLAYER_LOOKUP_MAX_RETRIES := 30


# ─── State ──────────────────────────────────────────────────────────────────

var _player: Node2D
var _drawer: Node2D
var _shield_pct: float = 1.0
var _retry_timer: Timer
var _retries: int = 0


# ─── PrototypeBase contract ─────────────────────────────────────────────────

func _flag_name() -> String:
	return "SHIP_DAMAGE_STATES"


func _setup_prototype() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		push_warning("[ShipDamageStates] GameState autoload not found — idling")
	else:
		_connect_signal(gs, "shield_changed",
			Callable(self, "_on_shield_changed"))

	_attempt_attach()


# ─── Player lookup with retry ───────────────────────────────────────────────

func _attempt_attach() -> void:
	_player = _find_player()
	if _player != null:
		_spawn_drawer()
		return
	# Player not in tree yet — schedule a retry.
	if _retry_timer == null:
		_retry_timer = Timer.new()
		_retry_timer.wait_time = _PLAYER_LOOKUP_INTERVAL
		_retry_timer.one_shot = false
		_retry_timer.timeout.connect(_on_retry_timeout)
		add_child(_retry_timer)
		_retry_timer.start()


func _on_retry_timeout() -> void:
	_retries += 1
	_player = _find_player()
	if _player != null:
		_stop_retrying()
		_spawn_drawer()
	elif _retries >= _PLAYER_LOOKUP_MAX_RETRIES:
		push_warning("[ShipDamageStates] could not find Player node after %.1fs — idling"
			% (_PLAYER_LOOKUP_INTERVAL * _PLAYER_LOOKUP_MAX_RETRIES))
		_stop_retrying()


func _stop_retrying() -> void:
	if _retry_timer != null and is_instance_valid(_retry_timer):
		_retry_timer.stop()
		_retry_timer.queue_free()
	_retry_timer = null


func _find_player() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	# Preferred: player advertises itself via the "player" group.
	var by_group := tree.get_first_node_in_group("player")
	if by_group is Node2D:
		return by_group
	# Fallback: find by node name in the current scene.
	var scene := tree.current_scene
	if scene == null:
		return null
	var by_name := scene.find_child("Player", true, false)
	if by_name is Node2D:
		return by_name
	return null


# ─── Drawer spawn / teardown ────────────────────────────────────────────────

func _spawn_drawer() -> void:
	if _drawer != null and is_instance_valid(_drawer):
		return
	_drawer = _DamageDrawer.new()
	_drawer.name = "ShipDamageDrawer"
	_drawer.host = self
	# z_index 1 puts the cracks just above the ship's own polyline, which
	# defaults to z_index 0. The shield bar lives on its own Node2D and is
	# unaffected.
	_drawer.z_index = 1
	_player.add_child(_drawer)


func _exit_tree() -> void:
	# Free the drawer first; super disconnects signals.
	if is_instance_valid(_drawer):
		_drawer.queue_free()
	_drawer = null
	_stop_retrying()
	super._exit_tree()


# ─── Signal handler ─────────────────────────────────────────────────────────

func _on_shield_changed(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		_shield_pct = 1.0
	else:
		_shield_pct = clamp(current / maximum, 0.0, 1.0)
	if is_instance_valid(_drawer):
		_drawer.notify_state_changed()


# ─── Inner drawer class ─────────────────────────────────────────────────────
# A Node2D parented under the player so its _draw() runs in the ship's
# local transform. Caches generated crack endpoints so the same cracks
# persist across frames; jitter and flicker animate on top of that cache.

class _DamageDrawer extends Node2D:
	var host: Object  # back-reference to the prototype Node

	var _t: float = 0.0
	var _cracks: Array = []         # Array of [Vector2, Vector2] pairs
	var _last_state: int = -1       # 0 = none, 1 = damaged, 2 = critical
	var _rng_seed: int = 0


	func _ready() -> void:
		_rng_seed = randi()


	func _process(delta: float) -> void:
		if host == null:
			return
		var pct: float = host._shield_pct
		var state: int = _state_for(pct)
		if state != _last_state:
			_regenerate_cracks(state)
			_last_state = state
			queue_redraw()
		if state >= 1:
			_t += delta
			# Animate every frame for jitter (state 2) or flicker (sub-tier).
			if state >= 2 or pct <= host.flicker_threshold:
				queue_redraw()


	# Public hook used by the prototype when shield_changed fires off-frame.
	func notify_state_changed() -> void:
		var pct: float = host._shield_pct
		var state: int = _state_for(pct)
		if state != _last_state:
			_regenerate_cracks(state)
			_last_state = state
		queue_redraw()


	func _state_for(pct: float) -> int:
		if pct >= host.damaged_threshold:
			return 0
		if pct >= host.critical_threshold:
			return 1
		return 2


	# Build a fresh set of crack segments for the current tier and cache them.
	# Endpoints live in the ship's local space.
	func _regenerate_cracks(state: int) -> void:
		_cracks.clear()
		if state <= 0:
			return
		var n: int = host.crack_count_damaged if state == 1 else host.crack_count_critical
		var rng := RandomNumberGenerator.new()
		rng.seed = _rng_seed + state * 1009
		for i in n:
			var edge := _random_edge_point(rng)
			var inner := _random_interior_point(rng)
			_cracks.append([edge, inner])


	func _random_edge_point(rng: RandomNumberGenerator) -> Vector2:
		# Uniform-ish across the three edges.
		var which: int = rng.randi() % 3
		var t: float = rng.randf()
		match which:
			0: return host.apex.lerp(host.base_left, t)
			1: return host.base_left.lerp(host.base_right, t)
			_: return host.base_right.lerp(host.apex, t)


	func _random_interior_point(rng: RandomNumberGenerator) -> Vector2:
		# Random barycentric coords clipped to the simplex.
		var u: float = rng.randf()
		var v: float = rng.randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var ab: Vector2 = host.base_left  - host.apex
		var ac: Vector2 = host.base_right - host.apex
		return host.apex + ab * u + ac * v


	# Stable per-frame jitter: derived from _t so endpoints wiggle smoothly.
	func _jitter(amount: float, salt: int) -> Vector2:
		if amount <= 0.0:
			return Vector2.ZERO
		var phase_x: float = sin((_t + float(salt) * 0.137) * 47.3)
		var phase_y: float = sin((_t + float(salt) * 0.211) * 39.1)
		return Vector2(phase_x, phase_y) * amount


	func _draw() -> void:
		if host == null:
			return
		if _cracks.is_empty():
			return
		var pct: float = host._shield_pct
		var jitter_amt: float = host.jitter_amplitude if pct < host.critical_threshold else 0.0

		# Cracks
		var color := Color(1, 1, 1, 1)
		for i in _cracks.size():
			var pair: Array = _cracks[i]
			var a: Vector2 = pair[0] + _jitter(jitter_amt, i * 2)
			var b: Vector2 = pair[1] + _jitter(jitter_amt, i * 2 + 1)
			draw_line(a, b, color, 1.0, false)

		# Critical-tier flickering outline
		if pct <= host.flicker_threshold:
			var period: float = 1.0 / max(host.flicker_hz, 0.001)
			var phase: float = fmod(_t, period) / period
			# Visible for first half of the cycle, off for the second half.
			if phase < 0.5:
				var pts := PackedVector2Array([
					host.apex        + _jitter(jitter_amt, 100),
					host.base_left   + _jitter(jitter_amt, 101),
					host.base_right  + _jitter(jitter_amt, 102),
					host.apex        + _jitter(jitter_amt, 100),
				])
				draw_polyline(pts, color, 1.0, false)
