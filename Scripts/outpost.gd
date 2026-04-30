extends Node2D

# Outpost scene — strategic / accumulation half of the loop. Player owns
# drills (3 tiers) that passively produce Helium into Outpost silos.
# Drill purchases mirror GameState.buy_voyage_drone(): check credits,
# deduct, increment count, emit <tier>_drills_changed signal.

@onready var camera: Camera2D = $Camera2D
@onready var production_timer: Timer = $ProductionTimer

# Right-side menu layout — mirrors base.gd
const RIGHT_MENU_WIDTH := 280.0
const RIGHT_MENU_PADDING := 20.0
const RIGHT_MENU_TOP_OFFSET := 60.0
const RIGHT_MENU_SPACING := 12

var _right_menu: VBoxContainer

# Drill bay UI
var _drill_panel: PanelContainer
var _drill_buy_btns: Dictionary = {}      # DrillTier -> Button
var _drill_count_labels: Dictionary = {}  # DrillTier -> Label
var _drill_rate_label: Label

# Silo bay UI
var _silo_panel: PanelContainer
var _silo_buy_btns: Dictionary = {}       # silo_key -> Button
var _silo_capacity_label: Label
var _helium_bar: Control
var _helium_amount_label: Label

# Wallet display
var _wallet_label: Label
var _vault_label: Label


func _ready() -> void:
	_build_wallet_display()
	_build_right_side_menu()
	_build_drill_bay_ui()
	_build_silo_bay_ui()

	# Production tick: every wait_time, drills produce helium into silos.
	production_timer.timeout.connect(_on_production_tick)
	production_timer.start()

	GameState.credits_changed.connect(_on_credits_changed)
	GameState.bank_balance_changed.connect(_on_bank_balance_changed)
	GameState.skim_drills_changed.connect(_on_drills_changed)
	GameState.bore_drills_changed.connect(_on_drills_changed)
	GameState.core_drills_changed.connect(_on_drills_changed)
	GameState.helium_changed.connect(_on_helium_changed)
	GameState.silo_capacity_changed.connect(_on_silo_capacity_changed)

	_refresh_all()


# === WALLET DISPLAY ===

func _build_wallet_display() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")
	var viewport_size = get_viewport_rect().size
	var x_pos = -viewport_size.x * 0.5 + 16
	var y_pos = -viewport_size.y * 0.5 + 12

	_wallet_label = Label.new()
	_wallet_label.text = "%d cr" % GameState.credits
	_wallet_label.add_theme_font_size_override("font_size", 18)
	_wallet_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_wallet_label.add_theme_font_override("font", mono_font)
	_wallet_label.position = Vector2(x_pos, y_pos)
	add_child(_wallet_label)

	_vault_label = Label.new()
	_vault_label.add_theme_font_size_override("font_size", 13)
	_vault_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	if mono_font:
		_vault_label.add_theme_font_override("font", mono_font)
	_vault_label.position = Vector2(x_pos, y_pos + 24)
	add_child(_vault_label)

	_refresh_wallet_display()


func _refresh_wallet_display() -> void:
	if _wallet_label:
		_wallet_label.text = "%d cr" % GameState.credits
	if _vault_label:
		if GameState.bank_balance > 0:
			_vault_label.text = "vault: %d cr" % GameState.bank_balance
		else:
			_vault_label.text = ""


# === RIGHT-SIDE MENU CONTAINER ===

func _build_right_side_menu() -> void:
	var viewport_size = get_viewport_rect().size
	_right_menu = VBoxContainer.new()
	_right_menu.name = "RightSideMenu"
	_right_menu.add_theme_constant_override("separation", RIGHT_MENU_SPACING)
	_right_menu.custom_minimum_size.x = RIGHT_MENU_WIDTH
	_right_menu.position = Vector2(
		viewport_size.x * 0.5 - RIGHT_MENU_WIDTH - RIGHT_MENU_PADDING,
		-viewport_size.y * 0.5 + RIGHT_MENU_TOP_OFFSET
	)
	add_child(_right_menu)


# === DRILL BAY ===

func _build_drill_bay_ui() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_drill_panel = PanelContainer.new()
	_drill_panel.name = "DrillBayPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.9, 0.8, 0.3)  # gold = positive/income
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_drill_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_drill_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "DRILL BAY"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	_style_separator(sep)
	vbox.add_child(sep)

	# Aggregate production-rate readout (helium/min from all owned drills)
	_drill_rate_label = Label.new()
	_drill_rate_label.add_theme_font_size_override("font_size", 11)
	_drill_rate_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if mono_font:
		_drill_rate_label.add_theme_font_override("font", mono_font)
	_drill_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_drill_rate_label)

	# One row per tier: name + count, description, buy button
	for tier in GameState.DrillTier.values():
		var data = GameState.DRILL_DATA[tier]

		var header_row = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = data.name.to_upper()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 13)
		# Color hint follows the bible: gold accent for Bore, gold+red for Core
		match tier:
			GameState.DrillTier.SKIM:
				name_label.add_theme_color_override("font_color", Color.WHITE)
			GameState.DrillTier.BORE:
				name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
			GameState.DrillTier.CORE:
				name_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		if mono_font:
			name_label.add_theme_font_override("font", mono_font)
		header_row.add_child(name_label)

		var count_label = Label.new()
		count_label.text = "x0"
		count_label.add_theme_font_size_override("font_size", 13)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.custom_minimum_size.x = 40
		if mono_font:
			count_label.add_theme_font_override("font", mono_font)
		header_row.add_child(count_label)
		_drill_count_labels[tier] = count_label

		vbox.add_child(header_row)

		var desc_label = Label.new()
		desc_label.text = "%.1f He/min · %.1f fuel/min" % [data.helium_per_min, data.fuel_per_min]
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if mono_font:
			desc_label.add_theme_font_override("font", mono_font)
		vbox.add_child(desc_label)

		var btn = Button.new()
		btn.text = "Buy %s Drill (%d cr)" % [data.name, data.cost]
		_apply_button_style(btn, mono_font, 12)
		btn.pressed.connect(_on_buy_drill_pressed.bind(tier))
		vbox.add_child(btn)
		_drill_buy_btns[tier] = btn

	_drill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_menu.add_child(_drill_panel)


# === SILO BAY ===

func _build_silo_bay_ui() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_silo_panel = PanelContainer.new()
	_silo_panel.name = "SiloBayPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.6, 0.6, 0.6)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_silo_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_silo_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "FUEL SILOS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	_style_separator(sep)
	vbox.add_child(sep)

	# Helium fill bar
	_helium_bar = _HeliumBar.new()
	vbox.add_child(_helium_bar)

	_helium_amount_label = Label.new()
	_helium_amount_label.add_theme_font_size_override("font_size", 11)
	_helium_amount_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_helium_amount_label.add_theme_font_override("font", mono_font)
	_helium_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_helium_amount_label)

	_silo_capacity_label = Label.new()
	_silo_capacity_label.add_theme_font_size_override("font_size", 10)
	_silo_capacity_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if mono_font:
		_silo_capacity_label.add_theme_font_override("font", mono_font)
	_silo_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_silo_capacity_label)

	var sep2 = HSeparator.new()
	_style_separator(sep2)
	vbox.add_child(sep2)

	# One button per silo type
	for silo_key in GameState.SILO_DATA:
		var data = GameState.SILO_DATA[silo_key]
		var btn = Button.new()
		btn.text = "Build %s (+%d, %d cr)" % [data.name, data.capacity, data.cost]
		_apply_button_style(btn, mono_font, 12)
		btn.pressed.connect(_on_buy_silo_pressed.bind(silo_key))
		vbox.add_child(btn)
		_silo_buy_btns[silo_key] = btn

	_silo_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_menu.add_child(_silo_panel)


# === STYLING HELPERS (mirror base.gd) ===

func _apply_button_style(btn: Button, font: Font, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.35))
	if font:
		btn.add_theme_font_override("font", font)

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


func _style_separator(sep: HSeparator) -> void:
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.6, 0.6, 0.6)
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)


# === REFRESH ===

func _refresh_all() -> void:
	_refresh_wallet_display()
	_refresh_drill_ui()
	_refresh_silo_ui()


func _refresh_drill_ui() -> void:
	for tier in GameState.DrillTier.values():
		var count: int = GameState.get_drill_count(tier)
		if _drill_count_labels.has(tier):
			_drill_count_labels[tier].text = "x%d" % count
		if _drill_buy_btns.has(tier):
			var data = GameState.DRILL_DATA[tier]
			_drill_buy_btns[tier].disabled = GameState.credits < int(data.cost)
	if _drill_rate_label:
		var total_rate := GameState.get_total_helium_per_min()
		_drill_rate_label.text = "Producing %.1f He/min" % total_rate


func _refresh_silo_ui() -> void:
	if _helium_bar and is_instance_valid(_helium_bar):
		var fill = 0.0
		if GameState.silo_capacity > 0:
			fill = clampf(GameState.helium_stored / float(GameState.silo_capacity), 0.0, 1.0)
		_helium_bar.set_meta("fill", fill)
		_helium_bar.queue_redraw()
	if _helium_amount_label:
		_helium_amount_label.text = "%d / %d He" % [int(GameState.helium_stored), GameState.silo_capacity]
	if _silo_capacity_label:
		if GameState.is_silo_full():
			_silo_capacity_label.text = "SILOS FULL — drills idle"
			_silo_capacity_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		elif GameState.silo_capacity == 0:
			_silo_capacity_label.text = "no silos — build one to store helium"
			_silo_capacity_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			_silo_capacity_label.text = ""
	for silo_key in _silo_buy_btns:
		var data = GameState.SILO_DATA[silo_key]
		_silo_buy_btns[silo_key].disabled = GameState.credits < int(data.cost)


# === PRODUCTION TICK ===

func _on_production_tick() -> void:
	# Each tick (1s), drills produce helium_per_min / 60 each.
	# If silos are full or absent, they idle (paying you nothing).
	var per_min := GameState.get_total_helium_per_min()
	if per_min <= 0.0:
		return
	var produced := per_min * production_timer.wait_time / 60.0
	GameState.add_helium(produced)


# === SIGNAL HANDLERS ===

func _on_credits_changed(_credits: int) -> void:
	_refresh_wallet_display()
	_refresh_drill_ui()
	_refresh_silo_ui()


func _on_bank_balance_changed(_balance: int) -> void:
	_refresh_wallet_display()


func _on_drills_changed(_count: int) -> void:
	_refresh_drill_ui()


func _on_helium_changed(_amount: float) -> void:
	_refresh_silo_ui()


func _on_silo_capacity_changed(_capacity: int) -> void:
	_refresh_silo_ui()


# === BUTTON CALLBACKS ===

func _on_buy_drill_pressed(tier: int) -> void:
	GameState.buy_drill(tier)


func _on_buy_silo_pressed(silo_key: String) -> void:
	GameState.buy_silo(silo_key)


func _on_back_button_pressed() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_base_button_pressed() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://Scenes/base.tscn")


func _on_bank_button_pressed() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://Scenes/bank.tscn")


# === INNER CLASSES ===

# Helium fill bar — diagonal hatch fill per the design plan, white outline.
class _HeliumBar extends Control:
	const BAR_WIDTH := 230.0
	const BAR_HEIGHT := 28.0
	const HATCH_SPACING := 6.0

	func _get_minimum_size() -> Vector2:
		return Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)

	func _draw() -> void:
		var fill: float = float(get_meta("fill", 0.0))
		var x_start := 2.0
		var y_start := 2.0
		var fill_width = BAR_WIDTH * fill

		# Outline (white, 1px)
		draw_rect(Rect2(x_start, y_start, BAR_WIDTH, BAR_HEIGHT), Color.WHITE, false, 1.0)

		# Diagonal hatch fill — clipped to filled portion
		if fill_width > 0.0:
			var clip_rect = Rect2(x_start, y_start, fill_width, BAR_HEIGHT)
			# Lines drawn at 45 degrees from top-right to bottom-left.
			# Sweep starting offsets along the bar so the whole filled area is hatched.
			var sweep := BAR_WIDTH + BAR_HEIGHT
			var i := 0.0
			while i < sweep:
				var p1 = Vector2(x_start + i, y_start)
				var p2 = Vector2(x_start + i - BAR_HEIGHT, y_start + BAR_HEIGHT)
				# Crude clip: only draw if any part of the segment falls in the
				# filled region. For exactness, clip line endpoints to clip_rect.
				var clipped = _clip_segment_to_rect(p1, p2, clip_rect)
				if clipped.size() == 2:
					draw_line(clipped[0], clipped[1], Color.WHITE, 1.0)
				i += HATCH_SPACING

	# Liang-Barsky-ish minimal segment-rect clipper. Returns [] or [p1, p2].
	func _clip_segment_to_rect(p1: Vector2, p2: Vector2, r: Rect2) -> Array:
		var t0 := 0.0
		var t1 := 1.0
		var dx = p2.x - p1.x
		var dy = p2.y - p1.y
		var p_arr = [-dx, dx, -dy, dy]
		var q_arr = [p1.x - r.position.x, r.position.x + r.size.x - p1.x, p1.y - r.position.y, r.position.y + r.size.y - p1.y]
		for i in range(4):
			var p: float = p_arr[i]
			var q: float = q_arr[i]
			if p == 0.0:
				if q < 0.0:
					return []
			else:
				var t: float = q / p
				if p < 0.0:
					if t > t1: return []
					if t > t0: t0 = t
				else:
					if t < t0: return []
					if t < t1: t1 = t
		return [Vector2(p1.x + t0 * dx, p1.y + t0 * dy), Vector2(p1.x + t1 * dx, p1.y + t1 * dy)]
