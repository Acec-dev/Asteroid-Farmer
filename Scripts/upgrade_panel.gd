extends PanelContainer

@export var slide_duration: float = 0.5

# Anchor positions when visible (proportional to graphs panel)
# Graphs panel takes bottom 27.78% of height (anchor_top = 0.7222222)
# Upgrade panel takes left 27.78% of width, stops above graphs panel
const ANCHOR_LEFT_VISIBLE = 0.0
const ANCHOR_RIGHT_VISIBLE = 0.2777778
const ANCHOR_TOP_VISIBLE = 0.0
const ANCHOR_BOTTOM_VISIBLE = 0.7222222

var panel_visible: bool = false
var tween: Tween
var _scroll_vbox: VBoxContainer

# Inventory UI references
var _iron_label: Label
var _nickel_label: Label
var _silica_label: Label
var _platinum_label: Label
var _cargo_label: Label
var _credit_label: Label
var _iron_price_label: Label
var _nickel_price_label: Label
var _silica_price_label: Label
var _platinum_price_label: Label
var _sell_btn: Button
var _mono_font: Font

# Gold mineral UI references
var _gold_label: Label
var _gold_price_label: Label

# Exotic mineral UI references
var _palladium_label: Label
var _titanium_label: Label
var _cobalt_label: Label
var _iridium_label: Label

# Upgrade cost definitions per level
var upgrade_costs = {
	"weapons": {
		"Primary Cannon": [0, 50, 150, 400],
		"Laser Beam": [100, 200, 400, 800],
		"Rocket Launcher": [100, 200, 400, 800],
		"Mine Layer": [100, 200, 400, 800],
		"Railgun": [150, 300, 600, 1200],
	},
	"shield": {
		"max_capacity": [50, 100, 250, 500, 1000],
		"regen_rate": [50, 100, 250, 500, 1000],
		"regen_delay": [75, 150, 350, 700, 1400],
	},
	"radar": {
		"zoom_level": [50, 100, 200, 400, 800],
	},
	"cargo": {
		"capacity": [75, 150, 300, 600, 1200],
	}
}

var display_names = {
	"max_capacity": "Max Capacity",
	"regen_rate": "Regen Rate",
	"regen_delay": "Regen Delay",
	"zoom_level": "Zoom Level",
	"capacity": "Cargo Hold",
	"rocket_damage": "  Damage",
	"rocket_speed": "  Speed",
	"rocket_fire_rate": "  Fire Rate",
	"mine_place_speed": "  Place Speed",
	"mine_blast_radius": "  Blast Radius",
	"mine_damage": "  Damage",
}

func _ready() -> void:
	add_to_group("upgrade_panel")
	_mono_font = load("res://Assets/DMMono-Regular.ttf")

	# Panel stylebox: pure black, sharp corners, gray border
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 1)
	panel_style.border_color = Color(0.6, 0.6, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", panel_style)

	# Set anchors for visible position
	anchor_left = ANCHOR_LEFT_VISIBLE
	anchor_right = ANCHOR_RIGHT_VISIBLE
	anchor_top = ANCHOR_TOP_VISIBLE
	anchor_bottom = ANCHOR_BOTTOM_VISIBLE
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0

	custom_minimum_size = Vector2(200, 200)

	# Start hidden off-screen to the left
	var width = ANCHOR_RIGHT_VISIBLE - ANCHOR_LEFT_VISIBLE
	anchor_left = -width
	anchor_right = 0.0

	# Build UI hierarchy
	_build_ui()
	_build_upgrade_list()
	_build_inventory_section()

	# React to upgrade and credit changes
	GameState.upgrades_changed.connect(_refresh_upgrade_list)
	GameState.credits_changed.connect(func(_c): _refresh_upgrade_list())

	# React to inventory and price changes
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.credits_changed.connect(_refresh_inventory)
	GameState.upgrades_changed.connect(_refresh_inventory)
	GameState.prices_changed.connect(_refresh_prices)
	GameState.exotic_minerals_changed.connect(_refresh_exotic_inventory)
	_refresh_inventory()
	_refresh_prices()
	_refresh_exotic_inventory()

var _inventory_vbox: VBoxContainer

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	# Main vertical split: scrollable upgrades on top, inventory pinned at bottom
	var outer_vbox = VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(outer_vbox)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_scroll_vbox)

	# Inventory container pinned at the bottom
	_inventory_vbox = VBoxContainer.new()
	_inventory_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_vbox.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(_inventory_vbox)

func slide_in() -> void:
	if panel_visible:
		return
	panel_visible = true

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)

	tween.tween_property(self, "anchor_left", ANCHOR_LEFT_VISIBLE, slide_duration)
	tween.tween_property(self, "anchor_right", ANCHOR_RIGHT_VISIBLE, slide_duration)

func slide_out() -> void:
	if not panel_visible:
		return
	panel_visible = false

	var width = ANCHOR_RIGHT_VISIBLE - ANCHOR_LEFT_VISIBLE

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)

	tween.tween_property(self, "anchor_left", -width, slide_duration)
	tween.tween_property(self, "anchor_right", 0.0, slide_duration)

func toggle() -> void:
	if panel_visible:
		slide_out()
	else:
		slide_in()

# === Upgrade List Generation ===

func _build_upgrade_list() -> void:
	for child in _scroll_vbox.get_children():
		child.queue_free()

	_add_section_header("WEAPONS")
	for weapon_name in GameState.upgrades.weapons:
		_add_upgrade_row("weapons", weapon_name)
		# Add infinite sub-upgrade rows for Rocket Launcher
		if weapon_name == "Rocket Launcher":
			for sub_type in ["rocket_damage", "rocket_speed", "rocket_fire_rate"]:
				_add_rocket_sub_row(sub_type)
		# Add infinite sub-upgrade rows for Mine Layer
		if weapon_name == "Mine Layer":
			for sub_type in ["mine_place_speed", "mine_blast_radius", "mine_damage"]:
				_add_mine_sub_row(sub_type)

	_add_section_header("SHIELDS")
	for upgrade_name in GameState.upgrades.shield:
		_add_upgrade_row("shield", upgrade_name)

	_add_section_header("RADAR")
	for upgrade_name in GameState.upgrades.radar:
		_add_upgrade_row("radar", upgrade_name)

	_add_section_header("CARGO")
	for upgrade_name in GameState.upgrades.cargo:
		_add_upgrade_row("cargo", upgrade_name)

	_add_section_header("TRACTOR BEAM")
	_add_tractor_beam_row()

func _add_section_header(title: String) -> void:
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	if _mono_font:
		label.add_theme_font_override("font", _mono_font)
	_scroll_vbox.add_child(label)

	var sep = HSeparator.new()
	_style_separator(sep)
	_scroll_vbox.add_child(sep)

func _add_upgrade_row(system: String, upgrade_name: String) -> void:
	var row = HBoxContainer.new()
	row.name = system + "_" + upgrade_name.replace(" ", "_")
	row.set_meta("system", system)
	row.set_meta("upgrade_name", upgrade_name)

	var name_label = Label.new()
	name_label.text = display_names.get(upgrade_name, upgrade_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	if _mono_font:
		name_label.add_theme_font_override("font", _mono_font)
	row.add_child(name_label)

	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.custom_minimum_size.x = 40
	if _mono_font:
		level_label.add_theme_font_override("font", _mono_font)
	row.add_child(level_label)

	var buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.custom_minimum_size.x = 100
	_apply_button_style(buy_btn, 12)
	buy_btn.pressed.connect(_on_buy_pressed.bind(system, upgrade_name))
	row.add_child(buy_btn)

	_scroll_vbox.add_child(row)
	_update_row(row, system, upgrade_name)

## Add a rocket sub-upgrade row (damage, speed, or fire rate)
func _add_rocket_sub_row(upgrade_type: String) -> void:
	var row = HBoxContainer.new()
	row.name = "rocket_sub_" + upgrade_type
	row.set_meta("system", "rocket_sub")
	row.set_meta("upgrade_name", upgrade_type)

	var name_label = Label.new()
	name_label.text = display_names.get(upgrade_type, upgrade_type)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	if _mono_font:
		name_label.add_theme_font_override("font", _mono_font)
	row.add_child(name_label)

	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.custom_minimum_size.x = 40
	if _mono_font:
		level_label.add_theme_font_override("font", _mono_font)
	row.add_child(level_label)

	var buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.custom_minimum_size.x = 100
	_apply_button_style(buy_btn, 12)
	buy_btn.pressed.connect(_on_rocket_sub_buy.bind(upgrade_type))
	row.add_child(buy_btn)

	_scroll_vbox.add_child(row)
	_update_rocket_sub_row(row, upgrade_type)

## Update a rocket sub-upgrade row
func _update_rocket_sub_row(row: HBoxContainer, upgrade_type: String) -> void:
	var level_label = row.get_node("LevelLabel")
	var buy_btn = row.get_node("BuyButton")
	var data = GameState.upgrades.weapons["Rocket Launcher"]
	var is_unlocked = data.unlocked

	if not is_unlocked:
		row.visible = false
		return
	row.visible = true

	var level: int = data.get(upgrade_type + "_level", 0)
	level_label.text = "Lv." + str(level)
	level_label.add_theme_color_override("font_color", Color.WHITE)

	var cost = GameState.get_rocket_upgrade_cost(upgrade_type)
	buy_btn.text = str(cost) + "cr"
	buy_btn.disabled = GameState.credits < cost

## Purchase a rocket sub-upgrade
func _on_rocket_sub_buy(upgrade_type: String) -> void:
	var cost = GameState.get_rocket_upgrade_cost(upgrade_type)
	if GameState.credits < cost:
		return
	GameState.add_credits(-cost)
	GameState.upgrade_rocket_stat(upgrade_type)

## Add a mine sub-upgrade row (place speed or blast radius)
func _add_mine_sub_row(upgrade_type: String) -> void:
	var row = HBoxContainer.new()
	row.name = "mine_sub_" + upgrade_type
	row.set_meta("system", "mine_sub")
	row.set_meta("upgrade_name", upgrade_type)

	var name_label = Label.new()
	name_label.text = display_names.get(upgrade_type, upgrade_type)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	if _mono_font:
		name_label.add_theme_font_override("font", _mono_font)
	row.add_child(name_label)

	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.custom_minimum_size.x = 40
	if _mono_font:
		level_label.add_theme_font_override("font", _mono_font)
	row.add_child(level_label)

	var buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.custom_minimum_size.x = 100
	_apply_button_style(buy_btn, 12)
	buy_btn.pressed.connect(_on_mine_sub_buy.bind(upgrade_type))
	row.add_child(buy_btn)

	_scroll_vbox.add_child(row)
	_update_mine_sub_row(row, upgrade_type)

## Update a mine sub-upgrade row
func _update_mine_sub_row(row: HBoxContainer, upgrade_type: String) -> void:
	var level_label = row.get_node("LevelLabel")
	var buy_btn = row.get_node("BuyButton")
	var data = GameState.upgrades.weapons["Mine Layer"]
	var is_unlocked = data.unlocked

	if not is_unlocked:
		row.visible = false
		return
	row.visible = true

	var level: int = data.get(upgrade_type + "_level", 0)
	level_label.text = "Lv." + str(level)
	level_label.add_theme_color_override("font_color", Color.WHITE)

	var cost = GameState.get_mine_upgrade_cost(upgrade_type)
	buy_btn.text = str(cost) + "cr"
	buy_btn.disabled = GameState.credits < cost

## Purchase a mine sub-upgrade
func _on_mine_sub_buy(upgrade_type: String) -> void:
	var cost = GameState.get_mine_upgrade_cost(upgrade_type)
	if GameState.credits < cost:
		return
	GameState.add_credits(-cost)
	GameState.upgrade_mine_stat(upgrade_type)

## Add the Tractor Beam infinite upgrade row
func _add_tractor_beam_row() -> void:
	var row = HBoxContainer.new()
	row.name = "tractor_beam_power"
	row.set_meta("system", "tractor_beam")
	row.set_meta("upgrade_name", "power")

	var name_label = Label.new()
	name_label.text = "Magnetism"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	if _mono_font:
		name_label.add_theme_font_override("font", _mono_font)
	row.add_child(name_label)

	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.custom_minimum_size.x = 40
	if _mono_font:
		level_label.add_theme_font_override("font", _mono_font)
	row.add_child(level_label)

	var buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.custom_minimum_size.x = 100
	_apply_button_style(buy_btn, 12)
	buy_btn.pressed.connect(_on_tractor_beam_buy)
	row.add_child(buy_btn)

	_scroll_vbox.add_child(row)
	_update_tractor_beam_row(row)

## Update the Tractor Beam row
func _update_tractor_beam_row(row: HBoxContainer) -> void:
	var level_label = row.get_node("LevelLabel")
	var buy_btn = row.get_node("BuyButton")
	var level: int = GameState.upgrades.tractor_beam.power.level

	level_label.text = "Lv." + str(level)
	level_label.add_theme_color_override("font_color", Color.WHITE)

	var cost = GameState.get_tractor_beam_cost()
	buy_btn.text = str(cost) + "cr"
	buy_btn.disabled = GameState.credits < cost

## Purchase a tractor beam upgrade
func _on_tractor_beam_buy() -> void:
	var cost = GameState.get_tractor_beam_cost()
	if GameState.credits < cost:
		return
	GameState.add_credits(-cost)
	GameState.upgrade_tractor_beam()

# === Row Update ===

func _update_row(row: HBoxContainer, system: String, upgrade_name: String) -> void:
	# Rocket sub-upgrade rows are handled separately
	if system == "rocket_sub":
		_update_rocket_sub_row(row, upgrade_name)
		return

	# Mine sub-upgrade rows are handled separately
	if system == "mine_sub":
		_update_mine_sub_row(row, upgrade_name)
		return

	# Tractor beam row is handled separately
	if system == "tractor_beam":
		_update_tractor_beam_row(row)
		return

	var level_label = row.get_node("LevelLabel")
	var buy_btn = row.get_node("BuyButton")

	var data: Dictionary
	if system == "weapons":
		data = GameState.upgrades.weapons[upgrade_name]
	else:
		data = GameState.upgrades[system][upgrade_name]

	var level: int = data.level
	var max_level: int
	var is_locked: bool = false
	# Weapons with infinite sub-upgrades: main row is unlock-only
	var has_sub_upgrades: bool = (upgrade_name == "Rocket Launcher" or upgrade_name == "Mine Layer")

	if system == "weapons":
		is_locked = not data.unlocked
		if has_sub_upgrades:
			max_level = 0
		elif data.has("damage_values"):
			max_level = data.damage_values.size() - 1
		elif data.has("max_damage_values"):
			max_level = data.max_damage_values.size()
		else:
			max_level = 3
	else:
		max_level = data.values.size() - 1

	# Level display
	if system == "weapons" and is_locked:
		level_label.text = "LOCKED"
		level_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
	elif has_sub_upgrades and not is_locked:
		level_label.text = "READY"
		level_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	elif level >= max_level:
		level_label.text = "MAX"
		level_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		level_label.text = "Lv." + str(level)
		level_label.add_theme_color_override("font_color", Color.WHITE)

	# Cost and button
	var cost = _get_cost(system, upgrade_name, level, is_locked)

	if system == "weapons" and is_locked:
		buy_btn.text = str(cost) + "cr UNLOCK"
		buy_btn.disabled = GameState.credits < cost
	elif has_sub_upgrades and not is_locked:
		buy_btn.text = "---"
		buy_btn.disabled = true
	elif level >= max_level:
		buy_btn.text = "MAXED"
		buy_btn.disabled = true
	else:
		buy_btn.text = str(cost) + "cr"
		buy_btn.disabled = GameState.credits < cost

func _get_cost(system: String, upgrade_name: String, level: int, is_locked: bool) -> int:
	if not upgrade_costs.has(system) or not upgrade_costs[system].has(upgrade_name):
		return 999

	var costs = upgrade_costs[system][upgrade_name]

	if system == "weapons" and is_locked:
		return costs[0] if costs.size() > 0 else 100

	if level < costs.size():
		return costs[level]
	return costs[-1] if costs.size() > 0 else 999

# === Purchase Logic ===

func _on_buy_pressed(system: String, upgrade_name: String) -> void:
	var data: Dictionary
	if system == "weapons":
		data = GameState.upgrades.weapons[upgrade_name]
	else:
		data = GameState.upgrades[system][upgrade_name]

	var is_locked = system == "weapons" and not data.unlocked
	var level = data.level
	var cost = _get_cost(system, upgrade_name, level, is_locked)

	if GameState.credits < cost:
		return

	GameState.add_credits(-cost)

	if system == "weapons" and is_locked:
		GameState.unlock_weapon(upgrade_name)
	elif system == "weapons":
		GameState.upgrade_weapon(upgrade_name)
	else:
		GameState.upgrade_system(system, upgrade_name)

func _refresh_upgrade_list() -> void:
	if not _scroll_vbox:
		return
	for row in _scroll_vbox.get_children():
		if row is HBoxContainer and row.has_meta("system"):
			var system = row.get_meta("system")
			var upgrade_name = row.get_meta("upgrade_name")
			_update_row(row, system, upgrade_name)

# === Inventory Section ===

func _build_inventory_section() -> void:
	var sep = HSeparator.new()
	_style_separator(sep)
	_inventory_vbox.add_child(sep)

	_add_section_header_to("INVENTORY", _inventory_vbox)

	# Mineral rows: name on left, price on right
	var minerals_box = VBoxContainer.new()
	minerals_box.add_theme_constant_override("separation", 2)
	_inventory_vbox.add_child(minerals_box)

	var iron_row = _make_inventory_row("Iron", "0", "$0")
	minerals_box.add_child(iron_row)
	_iron_label = iron_row.get_node("CountLabel")
	_iron_price_label = iron_row.get_node("PriceLabel")

	var nickel_row = _make_inventory_row("Nickel", "0", "$0")
	minerals_box.add_child(nickel_row)
	_nickel_label = nickel_row.get_node("CountLabel")
	_nickel_price_label = nickel_row.get_node("PriceLabel")

	var silica_row = _make_inventory_row("Silica", "0", "$0")
	minerals_box.add_child(silica_row)
	_silica_label = silica_row.get_node("CountLabel")
	_silica_price_label = silica_row.get_node("PriceLabel")

	var platinum_row = _make_inventory_row("Platinum", "0", "$0")
	minerals_box.add_child(platinum_row)
	_platinum_label = platinum_row.get_node("CountLabel")
	_platinum_price_label = platinum_row.get_node("PriceLabel")

	var gold_row = _make_inventory_row("Gold", "0", "$0")
	minerals_box.add_child(gold_row)
	_gold_label = gold_row.get_node("CountLabel")
	_gold_price_label = gold_row.get_node("PriceLabel")

	# Cargo capacity display
	_cargo_label = Label.new()
	_cargo_label.text = "Cargo: 0/%d" % GameState.cargo_capacity
	_cargo_label.add_theme_font_size_override("font_size", 13)
	_cargo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if _mono_font:
		_cargo_label.add_theme_font_override("font", _mono_font)
	_inventory_vbox.add_child(_cargo_label)

	# Credits row
	_credit_label = Label.new()
	_credit_label.text = "Credits: 0"
	_credit_label.add_theme_font_size_override("font_size", 14)
	_credit_label.add_theme_color_override("font_color", Color.WHITE)
	if _mono_font:
		_credit_label.add_theme_font_override("font", _mono_font)
	_inventory_vbox.add_child(_credit_label)

	# Sell button
	_sell_btn = Button.new()
	_sell_btn.text = "SELL ALL"
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_style(_sell_btn, 12)
	_sell_btn.pressed.connect(_on_sell_all)
	_inventory_vbox.add_child(_sell_btn)

	# Exotic minerals section
	var exotic_sep = HSeparator.new()
	_style_separator(exotic_sep)
	_inventory_vbox.add_child(exotic_sep)

	_add_section_header_to("EXOTIC MINERALS", _inventory_vbox)

	var exotic_box = VBoxContainer.new()
	exotic_box.add_theme_constant_override("separation", 2)
	_inventory_vbox.add_child(exotic_box)

	var palladium_row = _make_exotic_row("Palladium", "0")
	exotic_box.add_child(palladium_row)
	_palladium_label = palladium_row.get_node("CountLabel")

	var titanium_row = _make_exotic_row("Titanium", "0")
	exotic_box.add_child(titanium_row)
	_titanium_label = titanium_row.get_node("CountLabel")

	var cobalt_row = _make_exotic_row("Cobalt", "0")
	exotic_box.add_child(cobalt_row)
	_cobalt_label = cobalt_row.get_node("CountLabel")

	var iridium_row = _make_exotic_row("Iridium", "0")
	exotic_box.add_child(iridium_row)
	_iridium_label = iridium_row.get_node("CountLabel")

func _make_inventory_row(mineral_name: String, count: String, price: String) -> HBoxContainer:
	var row = HBoxContainer.new()

	var name_label = Label.new()
	name_label.text = mineral_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	if _mono_font:
		name_label.add_theme_font_override("font", _mono_font)
	row.add_child(name_label)

	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = count
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.custom_minimum_size.x = 40
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _mono_font:
		count_label.add_theme_font_override("font", _mono_font)
	row.add_child(count_label)

	var price_label = Label.new()
	price_label.name = "PriceLabel"
	price_label.text = price
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.custom_minimum_size.x = 40
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if _mono_font:
		price_label.add_theme_font_override("font", _mono_font)
	row.add_child(price_label)

	return row

func _add_section_header_to(title: String, parent: Control) -> void:
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	if _mono_font:
		label.add_theme_font_override("font", _mono_font)
	parent.add_child(label)

	var sep = HSeparator.new()
	_style_separator(sep)
	parent.add_child(sep)

func _refresh_inventory(_new_credits: int = 0) -> void:
	if not _iron_label:
		return
	_iron_label.text = str(GameState.minerals[GameState.MineralType.IRON])
	_nickel_label.text = str(GameState.minerals[GameState.MineralType.NICKEL])
	_silica_label.text = str(GameState.minerals[GameState.MineralType.SILICA])
	_platinum_label.text = str(GameState.minerals[GameState.MineralType.PLATINUM])
	if _gold_label:
		_gold_label.text = str(GameState.minerals[GameState.MineralType.GOLD])
	var total := GameState.get_total_minerals()
	if GameState.is_over_encumbered():
		var speed_pct := int(GameState.get_speed_multiplier() * 100)
		_cargo_label.text = "Cargo: %d/%d SLOW (%d%%)" % [total, GameState.cargo_capacity, speed_pct]
		_cargo_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	elif total >= GameState.cargo_capacity:
		_cargo_label.text = "Cargo: %d/%d FULL" % [total, GameState.cargo_capacity]
		_cargo_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	else:
		_cargo_label.text = "Cargo: %d/%d" % [total, GameState.cargo_capacity]
		_cargo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_credit_label.text = "Credits: %d" % GameState.credits

func _refresh_prices() -> void:
	if not _iron_price_label:
		return
	_iron_price_label.text = "$%d" % GameState.market_prices[GameState.MineralType.IRON]
	_nickel_price_label.text = "$%d" % GameState.market_prices[GameState.MineralType.NICKEL]
	_silica_price_label.text = "$%d" % GameState.market_prices[GameState.MineralType.SILICA]
	_platinum_price_label.text = "$%d" % GameState.market_prices[GameState.MineralType.PLATINUM]
	if _gold_price_label:
		_gold_price_label.text = "$%d" % GameState.market_prices[GameState.MineralType.GOLD]

func _make_exotic_row(mineral_name: String, count: String) -> HBoxContainer:
	var row = HBoxContainer.new()

	var name_label = Label.new()
	name_label.text = mineral_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	if _mono_font:
		name_label.add_theme_font_override("font", _mono_font)
	row.add_child(name_label)

	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = count
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	count_label.custom_minimum_size.x = 40
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _mono_font:
		count_label.add_theme_font_override("font", _mono_font)
	row.add_child(count_label)

	return row

func _refresh_exotic_inventory() -> void:
	if not _palladium_label:
		return
	_palladium_label.text = str(GameState.exotic_minerals[GameState.ExoticMineralType.PALLADIUM])
	_titanium_label.text = str(GameState.exotic_minerals[GameState.ExoticMineralType.TITANIUM])
	_cobalt_label.text = str(GameState.exotic_minerals[GameState.ExoticMineralType.COBALT])
	_iridium_label.text = str(GameState.exotic_minerals[GameState.ExoticMineralType.IRIDIUM])

func _style_separator(sep: HSeparator) -> void:
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.6, 0.6, 0.6)
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)

func _apply_button_style(btn: Button, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.35))
	if _mono_font:
		btn.add_theme_font_override("font", _mono_font)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 1)
	normal.border_color = Color(0.6, 0.6, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.1, 0.1, 0.1, 1)
	hover.border_color = Color.WHITE
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(0)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.2, 0.2, 0.2, 1)
	pressed.border_color = Color.WHITE
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(0)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.05, 0.05, 0.05, 1)
	disabled.border_color = Color(0.25, 0.25, 0.25)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(0)
	disabled.set_content_margin_all(6)
	btn.add_theme_stylebox_override("disabled", disabled)

	var focus = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", focus)

func _on_sell_all() -> void:
	GameState.sell_all()
