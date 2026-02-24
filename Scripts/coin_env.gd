extends Node3D

@export var coin_scene: PackedScene
@export var spawn_height: float = 5.0
@export var drop_interval: float = 0.15

const NUM_STACKS := 13       # positions -6 through 6
const MAX_STACK_HEIGHT := 20
const MAX_COINS := NUM_STACKS * MAX_STACK_HEIGHT  # 260

# Precomputed sequence of stack indices (0-12) for each coin drop
var _drop_sequence: Array[int] = []
# References to spawned coin nodes in drop order
var _spawned_coins: Array[Node] = []
# How many coins should currently be visible
var _target_coin_count: int = 0
var _drop_timer: float = 0.0

func _ready():
	_build_drop_sequence()
	_build_placeholder_panels()
	GameState.bank_balance_changed.connect(_on_bank_balance_changed)
	_update_target()

func _build_drop_sequence():
	_drop_sequence.clear()
	var heights: Array[int] = []
	heights.resize(NUM_STACKS)
	heights.fill(0)

	# Phase 1: Expanding pattern from center (lengths 1, 3, 5, 7, 9, 11, 13)
	for half_width in range(7):  # 0..6
		var center := 6  # stack index for position 0
		for i in range(center - half_width, center + half_width + 1):
			_drop_sequence.append(i)
			heights[i] += 1

	# Phase 2+3: Left to right, skipping stacks at max height
	var done := false
	while not done:
		done = true
		for i in range(NUM_STACKS):
			if heights[i] < MAX_STACK_HEIGHT:
				_drop_sequence.append(i)
				heights[i] += 1
				done = false

func _stack_x(stack_index: int) -> float:
	return float(stack_index - 6)

func _on_bank_balance_changed(_balance: int):
	_update_target()

func _update_target():
	var capacity := maxi(GameState.get_bank_capacity(), 1)
	var balance := GameState.bank_balance
	_target_coin_count = clampi(
		int(float(balance) / float(capacity) * MAX_COINS), 0, MAX_COINS
	)

func _process(delta: float):
	# Drop coins toward target
	if _spawned_coins.size() < _target_coin_count:
		_drop_timer += delta
		while _drop_timer >= drop_interval and _spawned_coins.size() < _target_coin_count:
			_drop_timer -= drop_interval
			_drop_next_coin()
	# Remove coins if target decreased (withdrawal)
	elif _spawned_coins.size() > _target_coin_count:
		_drop_timer += delta
		while _drop_timer >= drop_interval and _spawned_coins.size() > _target_coin_count:
			_drop_timer -= drop_interval
			_remove_last_coin()
	else:
		_drop_timer = 0.0

func _drop_next_coin():
	var index := _spawned_coins.size()
	if index >= _drop_sequence.size():
		return
	var stack_idx := _drop_sequence[index]
	var x := _stack_x(stack_idx)
	var coin = coin_scene.instantiate()
	add_child(coin)
	coin.global_position = Vector3(x, spawn_height, 0)
	_spawned_coins.append(coin)

func _remove_last_coin():
	if _spawned_coins.size() > 0:
		var coin = _spawned_coins.pop_back()
		if is_instance_valid(coin):
			coin.queue_free()

# === PLACEHOLDER PANELS ===
# Rough outlines matching the bank scene panel positions.
# Bank uses Camera2D at origin, so bank_pos + viewport/2 = screen_pos.

func _build_placeholder_panels():
	var viewport_size := Vector2(1920, 1080)
	var half := viewport_size * 0.5

	var canvas := CanvasLayer.new()
	canvas.name = "PlaceholderPanels"
	add_child(canvas)

	# Panel definitions: [title, bank_position, width, est_height, border_color]
	var panels := [
		["VAULT", Vector2(-80, -100), 160.0, 200.0, Color(0.3, 0.7, 0.3)],
		["GALACTIC BANK", Vector2(200, -340), 240.0, 290.0, Color(0.3, 0.7, 0.3)],
		["BANK UPGRADES", Vector2(200, -30), 240.0, 300.0, Color(0.6, 0.6, 0.3)],
		["TRANSACTIONS", Vector2(-500, -340), 260.0, 280.0, Color(0.5, 0.5, 0.5)],
		["BONDS", Vector2(-500, 20), 260.0, 320.0, Color(0.3, 0.5, 0.8)],
		["FUEL FUTURES", Vector2(480, -340), 260.0, 380.0, Color(0.9, 0.5, 0.2)],
		["GM100 INDEX FUND", Vector2(480, 20), 260.0, 380.0, Color(0.2, 0.8, 0.6)],
	]

	for p in panels:
		var title: String = p[0]
		var bank_pos: Vector2 = p[1]
		var w: float = p[2]
		var h: float = p[3]
		var border_col: Color = p[4]

		var screen_pos := bank_pos + half
		var drawer := _PlaceholderPanel.new()
		drawer.panel_title = title
		drawer.panel_size = Vector2(w, h)
		drawer.border_color = border_col
		drawer.position = screen_pos
		canvas.add_child(drawer)


class _PlaceholderPanel extends Control:
	var panel_title: String = ""
	var panel_size: Vector2 = Vector2(200, 200)
	var border_color: Color = Color.WHITE

	func _ready():
		size = panel_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		# Semi-transparent fill
		draw_rect(Rect2(Vector2.ZERO, panel_size), Color(0, 0, 0, 0.5), true)
		# Border
		draw_rect(Rect2(Vector2.ZERO, panel_size), border_color, false, 2.0)
		# Title text
		var font := ThemeDB.fallback_font
		var font_size := 14
		if font:
			var text_pos := Vector2(8, 20)
			draw_string(font, text_pos, panel_title, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 16, font_size, border_color)
