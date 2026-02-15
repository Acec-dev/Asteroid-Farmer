extends Node

# Voyage tiers: duration (seconds), break chance per drone, min/max minerals per surviving drone
enum VoyageTier { SHORT, MEDIUM, LONG }

const VOYAGE_DATA = {
	VoyageTier.SHORT: {
		"name": "Short Expedition",
		"duration": 30.0,
		"break_chance": 0.05,
		"min_minerals": 1,
		"max_minerals": 2,
	},
	VoyageTier.MEDIUM: {
		"name": "Medium Expedition",
		"duration": 45.0,
		"break_chance": 0.20,
		"min_minerals": 2,
		"max_minerals": 4,
	},
	VoyageTier.LONG: {
		"name": "Long Expedition",
		"duration": 60.0,
		"break_chance": 0.35,
		"min_minerals": 4,
		"max_minerals": 8,
	},
}

# Current voyage state
var voyage_active: bool = false
var voyage_tier: VoyageTier = VoyageTier.SHORT
var voyage_drones_sent: int = 0
var voyage_elapsed: float = 0.0
var voyage_duration: float = 0.0

func _process(delta: float) -> void:
	if not voyage_active:
		return
	voyage_elapsed += delta
	var progress = clampf(voyage_elapsed / voyage_duration, 0.0, 1.0)
	GameState.emit_signal("voyage_progress_updated", progress)
	if voyage_elapsed >= voyage_duration:
		_complete_voyage()

func start_voyage(tier: VoyageTier) -> bool:
	if voyage_active:
		return false
	if GameState.drone_count <= 0:
		return false

	var data = VOYAGE_DATA[tier]
	voyage_active = true
	voyage_tier = tier
	voyage_drones_sent = GameState.drone_count
	voyage_elapsed = 0.0
	voyage_duration = data.duration

	GameState.emit_signal("voyage_started")
	return true

func get_progress() -> float:
	if not voyage_active:
		return 0.0
	return clampf(voyage_elapsed / voyage_duration, 0.0, 1.0)

func get_tier_data(tier: VoyageTier) -> Dictionary:
	return VOYAGE_DATA[tier]

func _complete_voyage() -> void:
	voyage_active = false
	var data = VOYAGE_DATA[voyage_tier]
	var break_chance: float = data.break_chance
	var min_minerals: int = data.min_minerals
	var max_minerals: int = data.max_minerals

	var drones_lost := 0
	var drones_survived := 0
	var minerals_gained := {}
	for type in GameState.MineralType.values():
		minerals_gained[type] = 0

	# Roll for each drone
	for i in range(voyage_drones_sent):
		if randf() < break_chance:
			drones_lost += 1
		else:
			drones_survived += 1
			# Each surviving drone brings back random minerals
			var mineral_count = randi_range(min_minerals, max_minerals)
			for _j in range(mineral_count):
				var mineral_type = _random_mineral()
				minerals_gained[mineral_type] += 1

	# Remove lost drones
	if drones_lost > 0:
		GameState.remove_drones(drones_lost)

	# Add minerals to inventory
	for type in minerals_gained:
		if minerals_gained[type] > 0:
			GameState.add_mineral(type, minerals_gained[type])

	var results = {
		"drones_sent": voyage_drones_sent,
		"drones_survived": drones_survived,
		"drones_lost": drones_lost,
		"minerals_gained": minerals_gained,
		"tier": voyage_tier,
	}

	voyage_drones_sent = 0
	GameState.emit_signal("voyage_completed", results)

func _random_mineral() -> GameState.MineralType:
	# Weighted random: iron most common, platinum rarest
	var roll = randf()
	if roll < 0.40:
		return GameState.MineralType.IRON
	elif roll < 0.70:
		return GameState.MineralType.NICKEL
	elif roll < 0.90:
		return GameState.MineralType.SILICA
	else:
		return GameState.MineralType.PLATINUM
