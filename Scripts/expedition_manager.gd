extends Node

# Expedition tiers: longer, riskier than voyages, but yield exotic minerals
enum ExpeditionTier { NEAR_ORBIT, DEEP_SPACE, UNCHARTED }

const EXPEDITION_DATA = {
	ExpeditionTier.NEAR_ORBIT: {
		"name": "Near Orbit",
		"duration": 60.0,
		"break_chance": 0.35,
		"min_minerals": 1,
		"max_minerals": 2,
	},
	ExpeditionTier.DEEP_SPACE: {
		"name": "Deep Space",
		"duration": 120.0,
		"break_chance": 0.20,
		"min_minerals": 2,
		"max_minerals": 4,
	},
	ExpeditionTier.UNCHARTED: {
		"name": "Uncharted",
		"duration": 180.0,
		"break_chance": 0.10,
		"min_minerals": 4,
		"max_minerals": 8,
	},
}

# Current expedition state
var expedition_active: bool = false
var expedition_tier: ExpeditionTier = ExpeditionTier.NEAR_ORBIT
var expedition_drones_sent: int = 0
var expedition_elapsed: float = 0.0
var expedition_duration: float = 0.0

func _process(delta: float) -> void:
	if not expedition_active:
		return
	expedition_elapsed += delta
	var progress = clampf(expedition_elapsed / expedition_duration, 0.0, 1.0)
	GameState.emit_signal("expedition_progress_updated", progress)
	if expedition_elapsed >= expedition_duration:
		_complete_expedition()

func start_expedition(tier: ExpeditionTier) -> bool:
	if expedition_active:
		return false
	if GameState.expedition_drone_count <= 0:
		return false

	var data = EXPEDITION_DATA[tier]
	expedition_active = true
	expedition_tier = tier
	expedition_drones_sent = GameState.expedition_drone_count
	expedition_elapsed = 0.0
	# Apply warp drive upgrade to duration
	expedition_duration = data.duration * GameState.get_duration_multiplier()

	GameState.emit_signal("expedition_started")
	return true

func get_progress() -> float:
	if not expedition_active:
		return 0.0
	return clampf(expedition_elapsed / expedition_duration, 0.0, 1.0)

func get_tier_data(tier: ExpeditionTier) -> Dictionary:
	return EXPEDITION_DATA[tier]

func _complete_expedition() -> void:
	expedition_active = false
	var data = EXPEDITION_DATA[expedition_tier]
	var base_break_chance: float = data.break_chance
	# Apply drone armor upgrade
	var break_reduction = GameState.get_break_chance_reduction()
	var break_chance = base_break_chance * (1.0 - break_reduction)

	var min_minerals: int = data.min_minerals
	var max_minerals: int = data.max_minerals

	var drones_lost := 0
	var drones_survived := 0
	var minerals_gained := {}
	for type in GameState.ExoticMineralType.values():
		minerals_gained[type] = 0

	# Roll for each drone
	for i in range(expedition_drones_sent):
		if randf() < break_chance:
			drones_lost += 1
		else:
			drones_survived += 1
			# Each surviving drone brings back exotic minerals
			var base_count = randi_range(min_minerals, max_minerals)
			# Apply deep probes yield multiplier
			var mineral_count = int(ceil(base_count * GameState.get_exotic_yield_multiplier()))
			for _j in range(mineral_count):
				var mineral_type = _random_exotic_mineral()
				minerals_gained[mineral_type] += 1

	# Remove lost drones
	if drones_lost > 0:
		GameState.remove_expedition_drones(drones_lost)

	# Add exotic minerals to inventory
	for type in minerals_gained:
		if minerals_gained[type] > 0:
			GameState.add_exotic_mineral(type, minerals_gained[type])

	var results = {
		"drones_sent": expedition_drones_sent,
		"drones_survived": drones_survived,
		"drones_lost": drones_lost,
		"minerals_gained": minerals_gained,
		"tier": expedition_tier,
	}

	# Record in history
	var total_minerals := 0
	for type in minerals_gained:
		total_minerals += minerals_gained[type]
	var history_entry = {
		"type": "expedition",
		"tier": data.name,
		"drones_sent": results.drones_sent,
		"drones_survived": drones_survived,
		"drones_lost": drones_lost,
		"minerals_gained": total_minerals,
	}
	GameState.add_expedition_history(history_entry)

	expedition_drones_sent = 0
	GameState.emit_signal("expedition_completed", results)

func _random_exotic_mineral() -> GameState.ExoticMineralType:
	# Weighted random: cobalt most common, iridium rarest
	var roll = randf()
	if roll < 0.40:
		return GameState.ExoticMineralType.COBALT
	elif roll < 0.70:
		return GameState.ExoticMineralType.TITANIUM
	elif roll < 0.90:
		return GameState.ExoticMineralType.XENOCRYST
	else:
		return GameState.ExoticMineralType.IRIDIUM
