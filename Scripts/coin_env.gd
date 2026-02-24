extends Node3D

@export var coin_scene: PackedScene
@export var spawn_height: float = 5.0
@export var drop_interval: float = 0.15

const NUM_STACKS := 13       # positions -6 through 6
const MAX_STACK_HEIGHT := 40
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
