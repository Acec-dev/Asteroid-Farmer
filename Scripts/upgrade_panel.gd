extends PanelContainer

@export var slide_duration: float = 0.5

# Anchor positions when visible (proportional to graphs panel)
# Graphs panel takes bottom 27.78% of height (anchor_top = 0.7222222)
# Upgrade panel takes right 27.78% of width, stops above graphs panel
const ANCHOR_LEFT_VISIBLE = 0.7222222
const ANCHOR_RIGHT_VISIBLE = 1.0
const ANCHOR_TOP_VISIBLE = 0.0
const ANCHOR_BOTTOM_VISIBLE = 0.7222222

var panel_visible: bool = false
var tween: Tween
var _scroll_vbox: VBoxContainer

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
	}
}

var display_names = {
	"max_capacity": "Max Capacity",
	"regen_rate": "Regen Rate",
	"regen_delay": "Regen Delay",
	"zoom_level": "Zoom Level",
}

func _ready() -> void:
	add_to_group("upgrade_panel")

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

	# Start hidden off-screen to the right
	var width = ANCHOR_RIGHT_VISIBLE - ANCHOR_LEFT_VISIBLE
	anchor_left = 1.0
	anchor_right = 1.0 + width

	# Build UI hierarchy
	_build_ui()
	_build_upgrade_list()

	# React to upgrade and credit changes
	GameState.upgrades_changed.connect(_refresh_upgrade_list)
	GameState.credits_changed.connect(func(_c): _refresh_upgrade_list())

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_scroll_vbox)

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

	tween.tween_property(self, "anchor_left", 1.0, slide_duration)
	tween.tween_property(self, "anchor_right", 1.0 + width, slide_duration)

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

	_add_section_header("SHIELDS")
	for upgrade_name in GameState.upgrades.shield:
		_add_upgrade_row("shield", upgrade_name)

	_add_section_header("RADAR")
	for upgrade_name in GameState.upgrades.radar:
		_add_upgrade_row("radar", upgrade_name)

func _add_section_header(title: String) -> void:
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_scroll_vbox.add_child(label)

	var sep = HSeparator.new()
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
	row.add_child(name_label)

	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.custom_minimum_size.x = 40
	row.add_child(level_label)

	var buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.custom_minimum_size.x = 100
	buy_btn.pressed.connect(_on_buy_pressed.bind(system, upgrade_name))
	row.add_child(buy_btn)

	_scroll_vbox.add_child(row)
	_update_row(row, system, upgrade_name)

# === Row Update ===

func _update_row(row: HBoxContainer, system: String, upgrade_name: String) -> void:
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

	if system == "weapons":
		is_locked = not data.unlocked
		if data.has("damage_values"):
			max_level = data.damage_values.size() - 1
		elif data.has("max_damage_values"):
			max_level = data.max_damage_values.size() - 1
		else:
			max_level = 3
	else:
		max_level = data.values.size() - 1

	# Level display
	if system == "weapons" and is_locked:
		level_label.text = "LOCKED"
		level_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
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
