extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1


func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var save_data = _build_save_data()
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for writing")
		return false
	file.store_string(json_string)
	file.close()
	print("SaveManager: Game saved")
	return true


func load_game() -> bool:
	if not save_exists():
		push_error("SaveManager: No save file found")
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: Failed to open save file for reading")
		return false
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("SaveManager: Failed to parse save file")
		return false
	var save_data = json.data
	if typeof(save_data) != TYPE_DICTIONARY:
		push_error("SaveManager: Save data is not a dictionary")
		return false
	_restore_save_data(save_data)
	print("SaveManager: Game loaded")
	return true


func delete_save() -> void:
	if save_exists():
		DirAccess.remove_absolute(SAVE_PATH)
		print("SaveManager: Save file deleted")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# === BUILD SAVE DATA ===

func _build_save_data() -> Dictionary:
	var data := {}
	data["version"] = SAVE_VERSION
	data["run_time"] = GameState.run_time

	# Core state
	data["credits"] = GameState.credits
	data["minerals"] = _enum_dict_to_str(GameState.minerals)
	data["exotic_minerals"] = _enum_dict_to_str(GameState.exotic_minerals)
	data["voyage_drone_count"] = GameState.voyage_drone_count
	data["expedition_drone_count"] = GameState.expedition_drone_count
	data["skim_drill_count"] = GameState.skim_drill_count
	data["bore_drill_count"] = GameState.bore_drill_count
	data["core_drill_count"] = GameState.core_drill_count
	data["helium_stored"] = GameState.helium_stored
	data["silo_capacity"] = GameState.silo_capacity
	data["cargo_capacity"] = GameState.cargo_capacity
	data["max_shield"] = GameState.max_shield
	data["current_shield"] = GameState.current_shield
	data["shield_regen_rate"] = GameState.shield_regen_rate
	data["shield_regen_delay"] = GameState.shield_regen_delay
	data["fire_rate"] = GameState.fire_rate
	data["move_follow_strength"] = GameState.move_follow_strength
	data["projectile_speed"] = GameState.projectile_speed

	# Upgrades
	data["upgrades"] = _save_upgrades()
	data["drone_upgrade_levels"] = _save_drone_upgrades()

	# Bank
	data["bank_balance"] = GameState.bank_balance
	data["bank_interest_timer"] = GameState.bank_interest_timer
	data["bank_upgrade_levels"] = _save_bank_upgrades()
	data["bank_bonds"] = _save_bonds()
	data["bank_transaction_history"] = GameState.bank_transaction_history.duplicate(true)

	# Financial instruments
	data["fuel_futures"] = _save_fuel_futures()
	data["gm100_invested"] = GameState.gm100_invested
	data["gm100_return_timer"] = GameState.gm100_return_timer
	data["gm100_has_invested"] = GameState.gm100_has_invested

	# Market state
	data["market"] = _save_market()

	# Voyage state
	data["voyage"] = _save_voyage()

	# Expedition state
	data["expedition"] = _save_expedition()

	return data


# === RESTORE SAVE DATA ===

func _restore_save_data(data: Dictionary) -> void:
	# Core state
	GameState.run_time = data.get("run_time", 0.0)
	GameState.credits = int(data.get("credits", 0))
	_restore_minerals(data.get("minerals", {}))
	_restore_exotic_minerals(data.get("exotic_minerals", {}))
	GameState.voyage_drone_count = int(data.get("voyage_drone_count", 0))
	GameState.expedition_drone_count = int(data.get("expedition_drone_count", 0))
	GameState.skim_drill_count = int(data.get("skim_drill_count", 0))
	GameState.bore_drill_count = int(data.get("bore_drill_count", 0))
	GameState.core_drill_count = int(data.get("core_drill_count", 0))
	GameState.helium_stored = float(data.get("helium_stored", 0.0))
	GameState.silo_capacity = int(data.get("silo_capacity", 0))
	GameState.cargo_capacity = int(data.get("cargo_capacity", 40))
	GameState.max_shield = data.get("max_shield", 100.0)
	GameState.current_shield = data.get("current_shield", 100.0)
	GameState.shield_regen_rate = data.get("shield_regen_rate", 10.0)
	GameState.shield_regen_delay = data.get("shield_regen_delay", 3.0)
	GameState.fire_rate = data.get("fire_rate", 4.0)
	GameState.move_follow_strength = data.get("move_follow_strength", 12.0)
	GameState.projectile_speed = data.get("projectile_speed", 800.0)

	# Upgrades
	_restore_upgrades(data.get("upgrades", {}))
	_restore_drone_upgrades(data.get("drone_upgrade_levels", {}))

	# Bank
	GameState.bank_balance = int(data.get("bank_balance", 0))
	GameState.bank_interest_timer = data.get("bank_interest_timer", 0.0)
	_restore_bank_upgrades(data.get("bank_upgrade_levels", {}))
	_restore_bonds(data.get("bank_bonds", []))
	GameState.bank_transaction_history.clear()
	for entry in data.get("bank_transaction_history", []):
		if typeof(entry) == TYPE_DICTIONARY:
			GameState.bank_transaction_history.append(entry)

	# Financial instruments
	_restore_fuel_futures(data.get("fuel_futures", []))
	GameState.gm100_invested = int(data.get("gm100_invested", 0))
	GameState.gm100_return_timer = data.get("gm100_return_timer", 0.0)
	GameState.gm100_has_invested = data.get("gm100_has_invested", GameState.gm100_invested > 0)

	# Market state
	_restore_market(data.get("market", {}))

	# Voyage state
	_restore_voyage(data.get("voyage", {}))

	# Expedition state
	_restore_expedition(data.get("expedition", {}))

	# Emit signals so any active UI refreshes
	GameState.emit_signal("credits_changed", GameState.credits)
	GameState.emit_signal("inventory_changed")
	GameState.emit_signal("upgrades_changed")
	GameState.emit_signal("exotic_minerals_changed")
	GameState.emit_signal("drone_upgrades_changed")
	GameState.emit_signal("bank_balance_changed", GameState.bank_balance)
	GameState.emit_signal("bank_bond_changed")
	GameState.emit_signal("fuel_futures_changed")
	GameState.emit_signal("gm100_changed")
	GameState.emit_signal("voyage_drones_changed", GameState.voyage_drone_count)
	GameState.emit_signal("expedition_drones_changed", GameState.expedition_drone_count)
	GameState.emit_signal("skim_drills_changed", GameState.skim_drill_count)
	GameState.emit_signal("bore_drills_changed", GameState.bore_drill_count)
	GameState.emit_signal("core_drills_changed", GameState.core_drill_count)
	GameState.emit_signal("helium_changed", GameState.helium_stored)
	GameState.emit_signal("silo_capacity_changed", GameState.silo_capacity)


# === SERIALIZATION HELPERS ===

func _enum_dict_to_str(d: Dictionary) -> Dictionary:
	var result = {}
	for key in d:
		result[str(int(key))] = d[key]
	return result


func _restore_minerals(data: Dictionary) -> void:
	for key in data:
		var mineral_type = int(key)
		if GameState.minerals.has(mineral_type):
			GameState.minerals[mineral_type] = int(data[key])


func _restore_exotic_minerals(data: Dictionary) -> void:
	for key in data:
		var mineral_type = int(key)
		if GameState.exotic_minerals.has(mineral_type):
			GameState.exotic_minerals[mineral_type] = int(data[key])


# --- Upgrades ---

func _save_upgrades() -> Dictionary:
	var result = {}
	var u = GameState.upgrades

	# Weapons — save only mutable fields
	var weapons = {}
	for weapon_name in u.weapons:
		var w = u.weapons[weapon_name]
		var wd = {"unlocked": w.unlocked, "level": w.level}
		if weapon_name == "Rocket Launcher":
			wd["rocket_damage_level"] = w.rocket_damage_level
			wd["rocket_speed_level"] = w.rocket_speed_level
			wd["rocket_fire_rate_level"] = w.rocket_fire_rate_level
		if weapon_name == "Mine Layer":
			wd["mine_place_speed_level"] = w.mine_place_speed_level
			wd["mine_blast_radius_level"] = w.mine_blast_radius_level
		weapons[weapon_name] = wd
	result["weapons"] = weapons

	result["shield"] = {
		"max_capacity": u.shield.max_capacity.level,
		"regen_rate": u.shield.regen_rate.level,
		"regen_delay": u.shield.regen_delay.level,
	}
	result["radar"] = {"zoom_level": u.radar.zoom_level.level}
	result["cargo"] = {"capacity": u.cargo.capacity.level}
	result["tractor_beam"] = {"power": u.tractor_beam.power.level}
	result["spawner"] = {"difficulty": u.spawner.difficulty.level}
	return result


func _restore_upgrades(data: Dictionary) -> void:
	if data.is_empty():
		return
	var u = GameState.upgrades

	if data.has("weapons"):
		for weapon_name in data.weapons:
			if u.weapons.has(weapon_name):
				var saved = data.weapons[weapon_name]
				u.weapons[weapon_name].unlocked = saved.get("unlocked", false)
				u.weapons[weapon_name].level = int(saved.get("level", 0))
				if weapon_name == "Rocket Launcher":
					u.weapons[weapon_name].rocket_damage_level = int(saved.get("rocket_damage_level", 0))
					u.weapons[weapon_name].rocket_speed_level = int(saved.get("rocket_speed_level", 0))
					u.weapons[weapon_name].rocket_fire_rate_level = int(saved.get("rocket_fire_rate_level", 0))
				if weapon_name == "Mine Layer":
					u.weapons[weapon_name].mine_place_speed_level = int(saved.get("mine_place_speed_level", 0))
					u.weapons[weapon_name].mine_blast_radius_level = int(saved.get("mine_blast_radius_level", 0))

	if data.has("shield"):
		u.shield.max_capacity.level = int(data.shield.get("max_capacity", 0))
		u.shield.regen_rate.level = int(data.shield.get("regen_rate", 0))
		u.shield.regen_delay.level = int(data.shield.get("regen_delay", 0))
	if data.has("radar"):
		u.radar.zoom_level.level = int(data.radar.get("zoom_level", 0))
	if data.has("cargo"):
		u.cargo.capacity.level = int(data.cargo.get("capacity", 0))
	if data.has("tractor_beam"):
		u.tractor_beam.power.level = int(data.tractor_beam.get("power", 0))
	if data.has("spawner"):
		u.spawner.difficulty.level = int(data.spawner.get("difficulty", 1))

	GameState._sync_legacy_variables()


# --- Drone upgrades ---

func _save_drone_upgrades() -> Dictionary:
	var result = {}
	for upgrade_name in GameState.drone_upgrades:
		result[upgrade_name] = GameState.drone_upgrades[upgrade_name].level
	return result


func _restore_drone_upgrades(data: Dictionary) -> void:
	# Migrate renamed upgrades from old save data
	if data.has("deep_probes") and not data.has("infrared_scanner"):
		data["infrared_scanner"] = data["deep_probes"]
	for upgrade_name in data:
		if GameState.drone_upgrades.has(upgrade_name):
			GameState.drone_upgrades[upgrade_name].level = int(data[upgrade_name])


# --- Bank upgrades ---

func _save_bank_upgrades() -> Dictionary:
	var result = {}
	for upgrade_name in GameState.bank_upgrades:
		result[upgrade_name] = GameState.bank_upgrades[upgrade_name].level
	return result


func _restore_bank_upgrades(data: Dictionary) -> void:
	for upgrade_name in data:
		if GameState.bank_upgrades.has(upgrade_name):
			GameState.bank_upgrades[upgrade_name].level = int(data[upgrade_name])


# --- Bonds ---

func _save_bonds() -> Array:
	var result = []
	for bond in GameState.bank_bonds:
		result.append({
			"tier": bond.tier,
			"principal": bond.principal,
			"payout": bond.payout,
			"duration": bond.duration,
			"elapsed": bond.elapsed,
		})
	return result


func _restore_bonds(data: Array) -> void:
	GameState.bank_bonds.clear()
	for bond_data in data:
		if typeof(bond_data) == TYPE_DICTIONARY:
			GameState.bank_bonds.append({
				"tier": str(bond_data.get("tier", "short")),
				"principal": int(bond_data.get("principal", 0)),
				"payout": int(bond_data.get("payout", 0)),
				"duration": float(bond_data.get("duration", 60.0)),
				"elapsed": float(bond_data.get("elapsed", 0.0)),
			})


# --- Fuel futures ---

func _save_fuel_futures() -> Array:
	var result = []
	for future in GameState.fuel_futures:
		result.append({
			"tier": future.tier,
			"is_long": future.is_long,
			"cost": future.cost,
			"strike_price": future.strike_price,
			"leverage": future.leverage,
			"duration": future.duration,
			"elapsed": future.elapsed,
		})
	return result


func _restore_fuel_futures(data: Array) -> void:
	GameState.fuel_futures.clear()
	for fd in data:
		if typeof(fd) == TYPE_DICTIONARY:
			GameState.fuel_futures.append({
				"tier": str(fd.get("tier", "spot")),
				"is_long": bool(fd.get("is_long", true)),
				"cost": int(fd.get("cost", 25)),
				"strike_price": int(fd.get("strike_price", 50)),
				"leverage": float(fd.get("leverage", 1.0)),
				"duration": float(fd.get("duration", 30.0)),
				"elapsed": float(fd.get("elapsed", 0.0)),
			})


# --- Market ---

func _save_market() -> Dictionary:
	return {
		"prices": _enum_dict_to_str(Market.market_prices),
		"fuel_price": Market.fuel_price,
		"fuel_drift": Market._fuel_drift,
		"nickel_recent_sales": Market._nickel_recent_sales,
		"nickel_appreciation": Market._nickel_appreciation,
		"market_cycle": Market._market_cycle,
		"platinum_pressure": Market._platinum_pressure,
		"gm100_value": Market.gm100_value,
		"gm100_phase": int(Market.gm100_phase),
		"gm100_phase_timer": Market.gm100_phase_timer,
		"gm100_phase_duration": Market.gm100_phase_duration,
		"gm100_drift": Market._gm100_drift,
	}


func _restore_market(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("prices"):
		for key in data.prices:
			var mineral_type = int(key)
			if Market.market_prices.has(mineral_type):
				Market.market_prices[mineral_type] = int(data.prices[key])
	Market.fuel_price = int(data.get("fuel_price", 50))
	Market._fuel_drift = data.get("fuel_drift", 0.0)
	Market._nickel_recent_sales = data.get("nickel_recent_sales", 0.0)
	Market._nickel_appreciation = data.get("nickel_appreciation", 0.0)
	Market._market_cycle = int(data.get("market_cycle", 0))
	Market._platinum_pressure = data.get("platinum_pressure", 0.0)
	Market.gm100_value = data.get("gm100_value", 200.0)
	Market.gm100_phase = int(data.get("gm100_phase", 0))
	Market.gm100_phase_timer = data.get("gm100_phase_timer", 0.0)
	Market.gm100_phase_duration = data.get("gm100_phase_duration", 0.0)
	Market._gm100_drift = data.get("gm100_drift", 0.0)
	GameState.market_prices = Market.market_prices.duplicate()


# --- Voyage ---

func _save_voyage() -> Dictionary:
	return {
		"active": VoyageManager.voyage_active,
		"tier": int(VoyageManager.voyage_tier),
		"drones_sent": VoyageManager.voyage_drones_sent,
		"elapsed": VoyageManager.voyage_elapsed,
		"duration": VoyageManager.voyage_duration,
	}


func _restore_voyage(data: Dictionary) -> void:
	if data.is_empty():
		return
	VoyageManager.voyage_active = bool(data.get("active", false))
	VoyageManager.voyage_tier = int(data.get("tier", 0))
	VoyageManager.voyage_drones_sent = int(data.get("drones_sent", 0))
	VoyageManager.voyage_elapsed = data.get("elapsed", 0.0)
	VoyageManager.voyage_duration = data.get("duration", 0.0)


# --- Expedition ---

func _save_expedition() -> Dictionary:
	return {
		"active": ExpeditionManager.expedition_active,
		"tier": int(ExpeditionManager.expedition_tier),
		"drones_sent": ExpeditionManager.expedition_drones_sent,
		"elapsed": ExpeditionManager.expedition_elapsed,
		"duration": ExpeditionManager.expedition_duration,
	}


func _restore_expedition(data: Dictionary) -> void:
	if data.is_empty():
		return
	ExpeditionManager.expedition_active = bool(data.get("active", false))
	ExpeditionManager.expedition_tier = int(data.get("tier", 0))
	ExpeditionManager.expedition_drones_sent = int(data.get("drones_sent", 0))
	ExpeditionManager.expedition_elapsed = data.get("elapsed", 0.0)
	ExpeditionManager.expedition_duration = data.get("duration", 0.0)
