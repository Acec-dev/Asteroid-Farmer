extends Node2D

var _ship_node: Node2D
var _ship_rest_pos: Vector2
var _bob_time: float = 0.0
const BOB_AMPLITUDE := 4.0
const BOB_SPEED := 1.5
const FLY_IN_DURATION := 1.2

# UI references
var _vault_visual: _VaultDrawer
var _balance_label: Label
var _wallet_label: Label
var _interest_info_label: Label
var _countdown_label: Label
var _bank_panel: PanelContainer
var _upgrade_panel: PanelContainer
var _history_panel: PanelContainer
var _bond_panel: PanelContainer
var _futures_panel: PanelContainer
var _history_vbox: VBoxContainer
var _bond_status_vbox: VBoxContainer
var _futures_status_vbox: VBoxContainer
var _fuel_price_label: Label
var _futures_info_label: Label
var _upgrade_btns: Dictionary = {}
var _bond_btns: Dictionary = {}
var _futures_long_btns: Dictionary = {}
var _futures_short_btns: Dictionary = {}
var _deposit_btns: Array[Button] = []
var _withdraw_btns: Array[Button] = []

# GM100 panel references
var _gm100_panel: PanelContainer
var _gm100_graph: _GM100Graph
var _gm100_value_label: Label
var _gm100_phase_label: Label
var _gm100_invested_label: Label
var _gm100_rate_label: Label
var _gm100_countdown_label: Label
var _gm100_invest_btns: Array[Button] = []
var _gm100_withdraw_btns: Array[Button] = []

func _ready() -> void:
	_spawn_docked_ship()
	_build_vault_visual()
	_build_bank_panel()
	_build_upgrade_panel()
	_build_history_panel()
	_build_bond_panel()
	_build_futures_panel()
	_build_gm100_panel()

	GameState.bank_balance_changed.connect(_on_bank_balance_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.bank_upgraded.connect(_on_bank_upgraded)
	GameState.bank_bond_changed.connect(_on_bond_changed)
	GameState.fuel_futures_changed.connect(_on_futures_changed)
	GameState.gm100_changed.connect(_on_gm100_changed)

	_refresh_ui()

func _spawn_docked_ship() -> void:
	var viewport_size = get_viewport_rect().size
	_ship_rest_pos = Vector2(viewport_size.x * -0.35, viewport_size.y * -0.18)
	var start_pos = Vector2(-viewport_size.x * 0.6, _ship_rest_pos.y + 40)

	_ship_node = Node2D.new()
	_ship_node.name = "DockedShip"
	_ship_node.position = start_pos
	add_child(_ship_node)

	var ship_draw = _ShipDrawer.new()
	_ship_node.add_child(ship_draw)

	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_ship_node, "position", _ship_rest_pos, FLY_IN_DURATION)

func _process(delta: float) -> void:
	if _ship_node:
		_bob_time += delta
		_ship_node.position.y = _ship_rest_pos.y + sin(_bob_time * BOB_SPEED * TAU) * BOB_AMPLITUDE

	# Update vault fill animation
	if _vault_visual:
		_vault_visual.target_fill = float(GameState.bank_balance) / float(maxi(GameState.get_bank_capacity(), 1))
		_vault_visual.queue_redraw()

	# Update countdown
	if _countdown_label and GameState.bank_balance > 0:
		var remaining = GameState.get_bank_compound_interval() - GameState.bank_interest_timer
		_countdown_label.text = "Next interest in %ds" % ceili(remaining)
	elif _countdown_label:
		_countdown_label.text = ""

	# Update active bond progress
	_refresh_bond_status()

	# Update fuel price display and active futures
	_refresh_fuel_price_display()
	_refresh_futures_status()

	# Update GM100 display
	_refresh_gm100_display()

# === VAULT VISUAL ===

func _build_vault_visual() -> void:
	_vault_visual = _VaultDrawer.new()
	_vault_visual.position = Vector2(-80, -100)
	add_child(_vault_visual)

	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	# Balance label centered above vault
	_balance_label = Label.new()
	_balance_label.text = "0 cr"
	_balance_label.add_theme_font_size_override("font_size", 22)
	_balance_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	if mono_font:
		_balance_label.add_theme_font_override("font", mono_font)
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.custom_minimum_size.x = 160
	_balance_label.position = Vector2(-80, -140)
	add_child(_balance_label)

	# "VAULT" label above balance
	var vault_title = Label.new()
	vault_title.text = "VAULT"
	vault_title.add_theme_font_size_override("font_size", 14)
	vault_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if mono_font:
		vault_title.add_theme_font_override("font", mono_font)
	vault_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vault_title.custom_minimum_size.x = 160
	vault_title.position = Vector2(-80, -162)
	add_child(vault_title)

	# Countdown label below vault
	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.add_theme_font_size_override("font_size", 12)
	_countdown_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if mono_font:
		_countdown_label.add_theme_font_override("font", mono_font)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.custom_minimum_size.x = 160
	_countdown_label.position = Vector2(-80, 108)
	add_child(_countdown_label)

# === BANK PANEL (deposit/withdraw) ===

func _build_bank_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_bank_panel = PanelContainer.new()
	_bank_panel.name = "BankPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.3, 0.7, 0.3)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_bank_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_bank_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "GALACTIC BANK"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_separator(vbox)

	# Wallet display
	_wallet_label = Label.new()
	_wallet_label.text = "Wallet: 0 cr"
	_wallet_label.add_theme_font_size_override("font_size", 14)
	_wallet_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_wallet_label.add_theme_font_override("font", mono_font)
	vbox.add_child(_wallet_label)

	# Interest info
	_interest_info_label = Label.new()
	_interest_info_label.add_theme_font_size_override("font_size", 11)
	_interest_info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if mono_font:
		_interest_info_label.add_theme_font_override("font", mono_font)
	_interest_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_interest_info_label)

	_add_separator(vbox)

	# Deposit header
	var dep_header = Label.new()
	dep_header.text = "DEPOSIT"
	dep_header.add_theme_font_size_override("font_size", 12)
	dep_header.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	if mono_font:
		dep_header.add_theme_font_override("font", mono_font)
	vbox.add_child(dep_header)

	var dep_row = HBoxContainer.new()
	dep_row.add_theme_constant_override("separation", 4)
	for amount in [10, 50, -1]:  # -1 means ALL
		var btn = Button.new()
		btn.text = "ALL" if amount == -1 else "%dcr" % amount
		_apply_button_style(btn, mono_font, 12)
		btn.pressed.connect(_on_deposit_pressed.bind(amount))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dep_row.add_child(btn)
		_deposit_btns.append(btn)
	vbox.add_child(dep_row)

	# Withdraw header
	var wd_header = Label.new()
	wd_header.text = "WITHDRAW"
	wd_header.add_theme_font_size_override("font_size", 12)
	wd_header.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
	if mono_font:
		wd_header.add_theme_font_override("font", mono_font)
	vbox.add_child(wd_header)

	var wd_row = HBoxContainer.new()
	wd_row.add_theme_constant_override("separation", 4)
	for amount in [10, 50, -1]:
		var btn = Button.new()
		btn.text = "ALL" if amount == -1 else "%dcr" % amount
		_apply_button_style(btn, mono_font, 12)
		btn.pressed.connect(_on_withdraw_pressed.bind(amount))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wd_row.add_child(btn)
		_withdraw_btns.append(btn)
	vbox.add_child(wd_row)

	_bank_panel.position = Vector2(200, -340)
	_bank_panel.size = Vector2(240, 0)
	add_child(_bank_panel)

# === UPGRADE PANEL ===

func _build_upgrade_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_upgrade_panel = PanelContainer.new()
	_upgrade_panel.name = "UpgradePanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.6, 0.6, 0.3)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_upgrade_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_upgrade_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "BANK UPGRADES"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_separator(vbox)

	var display_info = {
		"vault_capacity": {"name": "Vault Capacity", "desc": "Max deposit limit"},
		"interest_rate": {"name": "Interest Rate", "desc": "% earned per cycle"},
		"compound_speed": {"name": "Compound Speed", "desc": "Seconds between interest"},
	}

	for upgrade_name in GameState.bank_upgrades:
		var data = GameState.bank_upgrades[upgrade_name]
		var info = display_info[upgrade_name]

		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var header_row = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = info.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		if mono_font:
			name_label.add_theme_font_override("font", mono_font)
		header_row.add_child(name_label)

		var level_label = Label.new()
		level_label.name = "BankUpgLevel_" + upgrade_name
		level_label.add_theme_font_size_override("font_size", 12)
		if mono_font:
			level_label.add_theme_font_override("font", mono_font)
		header_row.add_child(level_label)
		row.add_child(header_row)

		var desc_label = Label.new()
		desc_label.text = info.desc
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if mono_font:
			desc_label.add_theme_font_override("font", mono_font)
		row.add_child(desc_label)

		var btn = Button.new()
		btn.name = "BankUpgBtn_" + upgrade_name
		_apply_button_style(btn, mono_font, 11)
		btn.pressed.connect(_on_upgrade_pressed.bind(upgrade_name))
		row.add_child(btn)
		_upgrade_btns[upgrade_name] = btn

		vbox.add_child(row)

	_upgrade_panel.position = Vector2(200, -30)
	_upgrade_panel.size = Vector2(240, 0)
	add_child(_upgrade_panel)

# === TRANSACTION HISTORY PANEL ===

func _build_history_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_history_panel = PanelContainer.new()
	_history_panel.name = "HistoryPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.5, 0.5, 0.5)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_history_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_history_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "TRANSACTIONS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_separator(vbox)

	_history_vbox = VBoxContainer.new()
	_history_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_history_vbox)

	# Empty state
	var empty_label = Label.new()
	empty_label.name = "EmptyLabel"
	empty_label.text = "No transactions yet"
	empty_label.add_theme_font_size_override("font_size", 11)
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	if mono_font:
		empty_label.add_theme_font_override("font", mono_font)
	_history_vbox.add_child(empty_label)

	_history_panel.position = Vector2(-500, -340)
	_history_panel.size = Vector2(260, 0)
	add_child(_history_panel)

# === BOND PANEL ===

func _build_bond_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_bond_panel = PanelContainer.new()
	_bond_panel.name = "BondPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.3, 0.5, 0.8)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_bond_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_bond_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "BONDS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_separator(vbox)

	var info = Label.new()
	info.text = "Lock credits for a guaranteed return"
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if mono_font:
		info.add_theme_font_override("font", mono_font)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)

	for tier_key in GameState.BOND_TIERS:
		var tier = GameState.BOND_TIERS[tier_key]
		var btn = Button.new()
		var return_pct = int(tier.rate * 100)
		btn.text = "%s: %dcr (%ds, +%d%%)" % [tier.name, tier.min_investment, int(tier.duration), return_pct]
		_apply_button_style(btn, mono_font, 11)
		btn.pressed.connect(_on_bond_pressed.bind(tier_key))
		btn.name = "BondBtn_" + tier_key
		vbox.add_child(btn)
		_bond_btns[tier_key] = btn

	_add_separator(vbox)

	# Active bonds status area
	var active_title = Label.new()
	active_title.text = "ACTIVE BONDS"
	active_title.add_theme_font_size_override("font_size", 12)
	active_title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	if mono_font:
		active_title.add_theme_font_override("font", mono_font)
	vbox.add_child(active_title)

	_bond_status_vbox = VBoxContainer.new()
	_bond_status_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_bond_status_vbox)

	_bond_panel.position = Vector2(-500, 20)
	_bond_panel.size = Vector2(260, 0)
	add_child(_bond_panel)

# === FUEL FUTURES PANEL ===

func _build_futures_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_futures_panel = PanelContainer.new()
	_futures_panel.name = "FuturesPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.9, 0.5, 0.2)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_futures_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_futures_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "FUEL FUTURES"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_separator(vbox)

	# Fuel price display
	_fuel_price_label = Label.new()
	_fuel_price_label.text = "Fuel Price: %d cr" % GameState.get_fuel_price()
	_fuel_price_label.add_theme_font_size_override("font_size", 14)
	_fuel_price_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	if mono_font:
		_fuel_price_label.add_theme_font_override("font", mono_font)
	_fuel_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_fuel_price_label)

	# Info text
	_futures_info_label = Label.new()
	_futures_info_label.text = "Buy LONG (price up) or SHORT (price down)"
	_futures_info_label.add_theme_font_size_override("font_size", 10)
	_futures_info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if mono_font:
		_futures_info_label.add_theme_font_override("font", mono_font)
	_futures_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_futures_info_label)

	_add_separator(vbox)

	# Tier buttons (LONG / SHORT for each tier)
	for tier_key in GameState.FUEL_FUTURES_TIERS:
		var tier = GameState.FUEL_FUTURES_TIERS[tier_key]

		# Tier header
		var tier_header = Label.new()
		tier_header.text = "%s: %dcr | %ds | %dx" % [tier.name, tier.cost, int(tier.duration), int(tier.leverage)]
		tier_header.add_theme_font_size_override("font_size", 11)
		tier_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		if mono_font:
			tier_header.add_theme_font_override("font", mono_font)
		vbox.add_child(tier_header)

		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)

		# LONG button
		var long_btn = Button.new()
		long_btn.text = "LONG"
		long_btn.name = "FutureLong_" + tier_key
		_apply_button_style(long_btn, mono_font, 11)
		long_btn.pressed.connect(_on_future_pressed.bind(tier_key, true))
		long_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(long_btn)
		_futures_long_btns[tier_key] = long_btn

		# SHORT button
		var short_btn = Button.new()
		short_btn.text = "SHORT"
		short_btn.name = "FutureShort_" + tier_key
		_apply_button_style(short_btn, mono_font, 11)
		short_btn.pressed.connect(_on_future_pressed.bind(tier_key, false))
		short_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(short_btn)
		_futures_short_btns[tier_key] = short_btn

		vbox.add_child(btn_row)

	_add_separator(vbox)

	# Active futures status area
	var active_title = Label.new()
	active_title.text = "ACTIVE CONTRACTS"
	active_title.add_theme_font_size_override("font_size", 12)
	active_title.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	if mono_font:
		active_title.add_theme_font_override("font", mono_font)
	vbox.add_child(active_title)

	_futures_status_vbox = VBoxContainer.new()
	_futures_status_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_futures_status_vbox)

	_futures_panel.position = Vector2(480, -340)
	_futures_panel.size = Vector2(260, 0)
	add_child(_futures_panel)

# === GM100 INDEX FUND PANEL ===

func _build_gm100_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_gm100_panel = PanelContainer.new()
	_gm100_panel.name = "GM100Panel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.2, 0.8, 0.6)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_gm100_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_gm100_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "GM100 INDEX FUND"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.7))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_separator(vbox)

	# GM100 Graph
	_gm100_graph = _GM100Graph.new()
	_gm100_graph.custom_minimum_size = Vector2(236, 80)
	vbox.add_child(_gm100_graph)

	# Index value and phase
	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)

	_gm100_value_label = Label.new()
	_gm100_value_label.text = "Index: 100"
	_gm100_value_label.add_theme_font_size_override("font_size", 14)
	_gm100_value_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.7))
	_gm100_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mono_font:
		_gm100_value_label.add_theme_font_override("font", mono_font)
	info_row.add_child(_gm100_value_label)

	_gm100_phase_label = Label.new()
	_gm100_phase_label.text = "NORMAL"
	_gm100_phase_label.add_theme_font_size_override("font_size", 14)
	_gm100_phase_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if mono_font:
		_gm100_phase_label.add_theme_font_override("font", mono_font)
	info_row.add_child(_gm100_phase_label)

	vbox.add_child(info_row)

	# Rate and return info
	_gm100_rate_label = Label.new()
	_gm100_rate_label.text = "Return: 5% every 4min"
	_gm100_rate_label.add_theme_font_size_override("font_size", 10)
	_gm100_rate_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if mono_font:
		_gm100_rate_label.add_theme_font_override("font", mono_font)
	vbox.add_child(_gm100_rate_label)

	_add_separator(vbox)

	# Invested amount
	_gm100_invested_label = Label.new()
	_gm100_invested_label.text = "Invested: 0 cr"
	_gm100_invested_label.add_theme_font_size_override("font_size", 14)
	_gm100_invested_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_gm100_invested_label.add_theme_font_override("font", mono_font)
	vbox.add_child(_gm100_invested_label)

	# Countdown to next return
	_gm100_countdown_label = Label.new()
	_gm100_countdown_label.text = ""
	_gm100_countdown_label.add_theme_font_size_override("font_size", 10)
	_gm100_countdown_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	if mono_font:
		_gm100_countdown_label.add_theme_font_override("font", mono_font)
	vbox.add_child(_gm100_countdown_label)

	_add_separator(vbox)

	# Invest header
	var invest_header = Label.new()
	invest_header.text = "INVEST"
	invest_header.add_theme_font_size_override("font_size", 12)
	invest_header.add_theme_color_override("font_color", Color(0.2, 0.9, 0.7))
	if mono_font:
		invest_header.add_theme_font_override("font", mono_font)
	vbox.add_child(invest_header)

	var invest_row = HBoxContainer.new()
	invest_row.add_theme_constant_override("separation", 4)
	for amount in [50, 100, -1]:  # -1 means ALL
		var btn = Button.new()
		btn.text = "ALL" if amount == -1 else "%dcr" % amount
		_apply_button_style(btn, mono_font, 12)
		btn.pressed.connect(_on_gm100_invest_pressed.bind(amount))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		invest_row.add_child(btn)
		_gm100_invest_btns.append(btn)
	vbox.add_child(invest_row)

	# Withdraw header
	var wd_header = Label.new()
	wd_header.text = "WITHDRAW"
	wd_header.add_theme_font_size_override("font_size", 12)
	wd_header.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
	if mono_font:
		wd_header.add_theme_font_override("font", mono_font)
	vbox.add_child(wd_header)

	var wd_row = HBoxContainer.new()
	wd_row.add_theme_constant_override("separation", 4)
	for amount in [50, 100, -1]:
		var btn = Button.new()
		btn.text = "ALL" if amount == -1 else "%dcr" % amount
		_apply_button_style(btn, mono_font, 12)
		btn.pressed.connect(_on_gm100_withdraw_pressed.bind(amount))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wd_row.add_child(btn)
		_gm100_withdraw_btns.append(btn)
	vbox.add_child(wd_row)

	_gm100_panel.position = Vector2(480, 20)
	_gm100_panel.size = Vector2(260, 0)
	add_child(_gm100_panel)

# === HELPERS ===

func _add_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.6, 0.6, 0.6)
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)

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

# === REFRESH ===

func _refresh_ui() -> void:
	# Balance
	if _balance_label:
		_balance_label.text = "%d cr" % GameState.bank_balance

	# Wallet
	if _wallet_label:
		_wallet_label.text = "Wallet: %d cr" % GameState.credits

	# Interest info
	if _interest_info_label:
		var rate = GameState.get_bank_interest_rate()
		var interval = GameState.get_bank_compound_interval()
		var capacity = GameState.get_bank_capacity()
		_interest_info_label.text = "%d%% every %ds | Capacity: %d cr" % [int(rate * 100), int(interval), capacity]

	# Deposit buttons: disabled if no credits or vault full
	var can_deposit = GameState.credits > 0 and GameState.bank_balance < GameState.get_bank_capacity()
	for btn in _deposit_btns:
		btn.disabled = not can_deposit

	# Withdraw buttons: disabled if bank empty
	var can_withdraw = GameState.bank_balance > 0
	for btn in _withdraw_btns:
		btn.disabled = not can_withdraw

	_refresh_upgrades_ui()
	_refresh_history_ui()
	_refresh_bond_buttons()
	_refresh_futures_buttons()
	_refresh_gm100_buttons()

func _refresh_upgrades_ui() -> void:
	var value_formatters = {
		"vault_capacity": func(v): return "%d cr" % int(v),
		"interest_rate": func(v): return "%d%%" % int(v * 100),
		"compound_speed": func(v): return "%ds" % int(v),
	}

	for upgrade_name in GameState.bank_upgrades:
		var data = GameState.bank_upgrades[upgrade_name]
		var btn = _upgrade_btns.get(upgrade_name)
		if not btn:
			continue

		var level_label = _upgrade_panel.find_child("BankUpgLevel_" + upgrade_name, true, false)
		if level_label:
			var current_val = data.values[data.level]
			var formatter = value_formatters.get(upgrade_name)
			var val_str = formatter.call(current_val) if formatter else str(current_val)
			if data.level >= data.max_level:
				level_label.text = "MAX (%s)" % val_str
				level_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			else:
				level_label.text = "Lv.%d (%s)" % [data.level, val_str]
				level_label.add_theme_color_override("font_color", Color.WHITE)

		if data.level >= data.max_level:
			btn.text = "MAXED"
			btn.disabled = true
		else:
			var cost = data.costs[data.level + 1]
			btn.text = "Upgrade: %d cr" % cost
			btn.disabled = not GameState.can_afford_bank_upgrade(upgrade_name)

func _refresh_history_ui() -> void:
	if not _history_vbox:
		return

	# Clear existing
	for child in _history_vbox.get_children():
		child.queue_free()

	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	if GameState.bank_transaction_history.size() == 0:
		var empty = Label.new()
		empty.text = "No transactions yet"
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		if mono_font:
			empty.add_theme_font_override("font", mono_font)
		_history_vbox.add_child(empty)
		return

	var type_display = {
		"deposit": {"prefix": "+", "color": Color(0.3, 0.9, 0.3)},
		"withdraw": {"prefix": "-", "color": Color(0.9, 0.5, 0.3)},
		"interest": {"prefix": "+", "color": Color(0.9, 0.9, 0.3)},
		"upgrade": {"prefix": "-", "color": Color(0.7, 0.5, 0.8)},
		"bond_buy": {"prefix": "-", "color": Color(0.4, 0.7, 1.0)},
		"bond_mature": {"prefix": "+", "color": Color(0.3, 0.8, 1.0)},
		"future_buy": {"prefix": "-", "color": Color(0.9, 0.6, 0.2)},
		"future_settle": {"prefix": "+", "color": Color(0.9, 0.7, 0.3)},
		"gm100_invest": {"prefix": "-", "color": Color(0.2, 0.8, 0.6)},
		"gm100_withdraw": {"prefix": "+", "color": Color(0.2, 0.9, 0.7)},
		"gm100_return": {"prefix": "+", "color": Color(0.3, 1.0, 0.7)},
		"gm100_loss": {"prefix": "-", "color": Color(0.9, 0.4, 0.4)},
	}

	# Show last 10
	var count = mini(GameState.bank_transaction_history.size(), 10)
	for i in range(count):
		var tx = GameState.bank_transaction_history[i]
		var info = type_display.get(tx.type, {"prefix": "", "color": Color.WHITE})

		var row = HBoxContainer.new()
		var type_label = Label.new()
		type_label.text = tx.type.to_upper()
		type_label.add_theme_font_size_override("font_size", 10)
		type_label.add_theme_color_override("font_color", info.color)
		type_label.custom_minimum_size.x = 80
		if mono_font:
			type_label.add_theme_font_override("font", mono_font)
		row.add_child(type_label)

		var amount_label = Label.new()
		amount_label.text = "%s%d cr" % [info.prefix, tx.amount]
		amount_label.add_theme_font_size_override("font_size", 10)
		amount_label.add_theme_color_override("font_color", info.color)
		amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if mono_font:
			amount_label.add_theme_font_override("font", mono_font)
		row.add_child(amount_label)

		var bal_label = Label.new()
		bal_label.text = "bal:%d" % tx.balance
		bal_label.add_theme_font_size_override("font_size", 10)
		bal_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		bal_label.custom_minimum_size.x = 65
		bal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if mono_font:
			bal_label.add_theme_font_override("font", mono_font)
		row.add_child(bal_label)

		_history_vbox.add_child(row)

func _refresh_bond_buttons() -> void:
	for tier_key in GameState.BOND_TIERS:
		var tier = GameState.BOND_TIERS[tier_key]
		var btn = _bond_btns.get(tier_key)
		if btn:
			btn.disabled = GameState.credits < tier.min_investment

func _refresh_bond_status() -> void:
	if not _bond_status_vbox:
		return

	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	# Clear existing
	for child in _bond_status_vbox.get_children():
		child.queue_free()

	if GameState.bank_bonds.size() == 0:
		var none_label = Label.new()
		none_label.text = "No active bonds"
		none_label.add_theme_font_size_override("font_size", 10)
		none_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		if mono_font:
			none_label.add_theme_font_override("font", mono_font)
		_bond_status_vbox.add_child(none_label)
		return

	for bond in GameState.bank_bonds:
		var tier = GameState.BOND_TIERS[bond.tier]
		var remaining = bond.duration - bond.elapsed
		var progress = bond.elapsed / bond.duration

		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)

		var info_label = Label.new()
		info_label.text = "%s: %dcr -> %dcr (%ds)" % [tier.name, bond.principal, bond.payout, ceili(remaining)]
		info_label.add_theme_font_size_override("font_size", 10)
		info_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		if mono_font:
			info_label.add_theme_font_override("font", mono_font)
		row.add_child(info_label)

		var bar = _BondProgressBar.new()
		bar.progress = progress
		row.add_child(bar)

		_bond_status_vbox.add_child(row)

func _refresh_futures_buttons() -> void:
	var at_max = GameState.fuel_futures.size() >= GameState.MAX_FUEL_FUTURES
	for tier_key in GameState.FUEL_FUTURES_TIERS:
		var tier = GameState.FUEL_FUTURES_TIERS[tier_key]
		var long_btn = _futures_long_btns.get(tier_key)
		var short_btn = _futures_short_btns.get(tier_key)
		var cant_afford = GameState.credits < tier.cost
		if long_btn:
			long_btn.disabled = cant_afford or at_max
		if short_btn:
			short_btn.disabled = cant_afford or at_max

func _refresh_fuel_price_display() -> void:
	if _fuel_price_label:
		_fuel_price_label.text = "Fuel Price: %d cr" % GameState.get_fuel_price()

func _refresh_futures_status() -> void:
	if not _futures_status_vbox:
		return

	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	for child in _futures_status_vbox.get_children():
		child.queue_free()

	if GameState.fuel_futures.size() == 0:
		var none_label = Label.new()
		none_label.text = "No active contracts"
		none_label.add_theme_font_size_override("font_size", 10)
		none_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		if mono_font:
			none_label.add_theme_font_override("font", mono_font)
		_futures_status_vbox.add_child(none_label)
		return

	var current_price = GameState.get_fuel_price()
	for future in GameState.fuel_futures:
		var tier = GameState.FUEL_FUTURES_TIERS[future.tier]
		var remaining = future.duration - future.elapsed
		var progress = future.elapsed / future.duration
		var direction = "LONG" if future.is_long else "SHORT"

		# Calculate current projected payout
		var price_change: float
		if future.is_long:
			price_change = float(current_price - future.strike_price) / float(future.strike_price)
		else:
			price_change = float(future.strike_price - current_price) / float(future.strike_price)
		var projected = int(floor(future.cost * (1.0 + price_change * future.leverage)))
		projected = maxi(projected, 0)

		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)

		var info_label = Label.new()
		info_label.text = "%s %s @%d (%ds)" % [tier.name, direction, future.strike_price, ceili(remaining)]
		info_label.add_theme_font_size_override("font_size", 10)
		if future.is_long:
			info_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			info_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		if mono_font:
			info_label.add_theme_font_override("font", mono_font)
		row.add_child(info_label)

		var payout_label = Label.new()
		var profit = projected - future.cost
		var profit_str: String
		if profit >= 0:
			profit_str = "+%d" % profit
		else:
			profit_str = "%d" % profit
		payout_label.text = "Payout: %dcr (%s)" % [projected, profit_str]
		payout_label.add_theme_font_size_override("font_size", 10)
		if projected >= future.cost:
			payout_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		else:
			payout_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		if mono_font:
			payout_label.add_theme_font_override("font", mono_font)
		row.add_child(payout_label)

		var bar = _FuturesProgressBar.new()
		bar.progress = progress
		bar.is_profitable = projected >= future.cost
		row.add_child(bar)

		_futures_status_vbox.add_child(row)

func _refresh_gm100_display() -> void:
	if not Market:
		return

	# Update index value
	if _gm100_value_label:
		_gm100_value_label.text = "Index: %d" % int(Market.get_gm100_value())

	# Update phase indicator
	if _gm100_phase_label:
		match Market.gm100_phase:
			Market.GM100Phase.BOOM:
				_gm100_phase_label.text = "BOOM"
				_gm100_phase_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			Market.GM100Phase.BUST:
				_gm100_phase_label.text = "BUST"
				_gm100_phase_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			_:
				_gm100_phase_label.text = "NORMAL"
				_gm100_phase_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	# Update rate display
	if _gm100_rate_label:
		var rate = GameState.get_gm100_current_rate()
		var rate_pct = int(rate * 100)
		if rate >= 0:
			_gm100_rate_label.text = "Return: +%d%% every 4min" % rate_pct
			_gm100_rate_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		else:
			_gm100_rate_label.text = "Return: %d%% every 4min" % rate_pct
			_gm100_rate_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	# Update invested amount and cost basis
	if _gm100_invested_label:
		if GameState.gm100_invested > 0 and GameState.gm100_cost_basis > 0:
			_gm100_invested_label.text = "Invested: %d cr (basis: %.0f)" % [GameState.gm100_invested, GameState.gm100_cost_basis]
		else:
			_gm100_invested_label.text = "Invested: %d cr" % GameState.gm100_invested

	# Update countdown
	if _gm100_countdown_label and GameState.gm100_invested > 0:
		var remaining = GameState.get_gm100_return_interval() - GameState.gm100_return_timer
		_gm100_countdown_label.text = "Next return in %ds" % ceili(remaining)
	elif _gm100_countdown_label:
		_gm100_countdown_label.text = ""

	# Update graph
	if _gm100_graph:
		_gm100_graph.price_history = Market.get_gm100_history().duplicate()
		_gm100_graph.queue_redraw()

func _refresh_gm100_buttons() -> void:
	var can_invest = GameState.credits >= GameState.GM100_MIN_INVESTMENT
	for btn in _gm100_invest_btns:
		btn.disabled = not can_invest
	var can_withdraw = GameState.gm100_invested > 0
	for btn in _gm100_withdraw_btns:
		btn.disabled = not can_withdraw

# === CALLBACKS ===

func _on_deposit_pressed(amount: int) -> void:
	if amount == -1:
		amount = GameState.credits
	GameState.bank_deposit(amount)

func _on_withdraw_pressed(amount: int) -> void:
	if amount == -1:
		amount = GameState.bank_balance
	GameState.bank_withdraw(amount)

func _on_upgrade_pressed(upgrade_name: String) -> void:
	GameState.buy_bank_upgrade(upgrade_name)

func _on_bond_pressed(tier_key: String) -> void:
	GameState.buy_bond(tier_key)

func _on_future_pressed(tier_key: String, is_long: bool) -> void:
	GameState.buy_fuel_future(tier_key, is_long)

func _on_futures_changed() -> void:
	_refresh_ui()

func _on_bank_balance_changed(_balance: int) -> void:
	_refresh_ui()

func _on_credits_changed(_credits: int) -> void:
	_refresh_ui()

func _on_bank_upgraded() -> void:
	_refresh_ui()

func _on_bond_changed() -> void:
	_refresh_ui()

func _on_gm100_changed() -> void:
	_refresh_ui()

func _on_gm100_invest_pressed(amount: int) -> void:
	if amount == -1:
		amount = GameState.credits
	GameState.gm100_invest(amount)

func _on_gm100_withdraw_pressed(amount: int) -> void:
	if amount == -1:
		amount = GameState.gm100_invested
	GameState.gm100_withdraw(amount)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_base_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/base.tscn")

# === INNER CLASSES ===

class _ShipDrawer extends Node2D:
	func _draw() -> void:
		var points = PackedVector2Array([
			Vector2(60, 0),
			Vector2(-20, -16),
			Vector2(-20, 16),
			Vector2(60, 0)
		])
		draw_polyline(points, Color.WHITE, 2.0)


class _VaultDrawer extends Node2D:
	var target_fill: float = 0.0
	var _particle_time: float = 0.0

	const VAULT_W := 160.0
	const VAULT_H := 200.0

	func _process(delta: float) -> void:
		_particle_time += delta

	func _draw() -> void:
		var x := 0.0
		var y := 0.0

		# Fill level
		var fill = clampf(target_fill, 0.0, 1.0)
		var fill_h = VAULT_H * fill
		if fill_h > 0:
			var fill_color = Color(0.25, 0.7, 0.25, 0.4)
			draw_rect(Rect2(x + 2, y + VAULT_H - fill_h, VAULT_W - 4, fill_h), fill_color, true)

			# Animated dots inside the fill area
			for i in range(8):
				var dot_phase = _particle_time * 0.5 + i * 0.8
				var dot_x = x + 10 + fmod(dot_phase * 17.3 + i * 23.7, VAULT_W - 20)
				var dot_base_y = y + VAULT_H - fmod(dot_phase * 12.0 + i * 31.0, fill_h)
				var dot_y = dot_base_y + sin(dot_phase * 2.0) * 3.0
				if dot_y > y + VAULT_H - fill_h and dot_y < y + VAULT_H:
					var dot_alpha = 0.3 + 0.3 * sin(dot_phase * 3.0)
					draw_circle(Vector2(dot_x, dot_y), 2.0, Color(0.4, 0.9, 0.4, dot_alpha))

		# Vault outline - gets brighter as it fills
		var border_brightness = 0.4 + 0.6 * fill
		var border_color = Color(border_brightness, border_brightness, border_brightness)
		var border_width = 1.5 + fill * 1.0
		draw_rect(Rect2(x, y, VAULT_W, VAULT_H), border_color, false, border_width)

		# Door outline on the front
		var door_w = VAULT_W * 0.5
		var door_h = VAULT_H * 0.6
		var door_x = x + (VAULT_W - door_w) * 0.5
		var door_y = y + (VAULT_H - door_h) * 0.5
		draw_rect(Rect2(door_x, door_y, door_w, door_h), Color(border_brightness * 0.7, border_brightness * 0.7, border_brightness * 0.7), false, 1.0)

		# Door handle (small circle)
		var handle_x = door_x + door_w * 0.75
		var handle_y = door_y + door_h * 0.5
		draw_circle(Vector2(handle_x, handle_y), 4.0, Color(border_brightness, border_brightness, border_brightness))
		draw_circle(Vector2(handle_x, handle_y), 2.5, Color(0, 0, 0))

		# Capacity indicator line
		draw_line(Vector2(x + VAULT_W + 6, y), Vector2(x + VAULT_W + 6, y + VAULT_H), Color(0.3, 0.3, 0.3), 1.0)
		if fill > 0:
			draw_line(Vector2(x + VAULT_W + 6, y + VAULT_H - fill_h), Vector2(x + VAULT_W + 6, y + VAULT_H), Color(0.3, 0.7, 0.3), 2.0)


class _BondProgressBar extends Control:
	var progress: float = 0.0
	const BAR_WIDTH := 220.0
	const BAR_HEIGHT := 8.0

	func _get_minimum_size() -> Vector2:
		return Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)

	func _draw() -> void:
		var x := 2.0
		var y := 2.0

		draw_rect(Rect2(x, y, BAR_WIDTH, BAR_HEIGHT), Color(0.1, 0.1, 0.1), true)

		var fill_w = BAR_WIDTH * clampf(progress, 0.0, 1.0)
		if fill_w > 0:
			draw_rect(Rect2(x, y, fill_w, BAR_HEIGHT), Color(0.4, 0.7, 1.0), true)

		draw_rect(Rect2(x, y, BAR_WIDTH, BAR_HEIGHT), Color(0.4, 0.4, 0.4), false, 1.0)


class _FuturesProgressBar extends Control:
	var progress: float = 0.0
	var is_profitable: bool = true
	const BAR_WIDTH := 220.0
	const BAR_HEIGHT := 8.0

	func _get_minimum_size() -> Vector2:
		return Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)

	func _draw() -> void:
		var x := 2.0
		var y := 2.0

		draw_rect(Rect2(x, y, BAR_WIDTH, BAR_HEIGHT), Color(0.1, 0.1, 0.1), true)

		var fill_w = BAR_WIDTH * clampf(progress, 0.0, 1.0)
		if fill_w > 0:
			var fill_color: Color
			if is_profitable:
				fill_color = Color(0.3, 0.8, 0.3)
			else:
				fill_color = Color(0.9, 0.4, 0.4)
			draw_rect(Rect2(x, y, fill_w, BAR_HEIGHT), fill_color, true)

		draw_rect(Rect2(x, y, BAR_WIDTH, BAR_HEIGHT), Color(0.4, 0.4, 0.4), false, 1.0)


class _GM100Graph extends Control:
	var price_history: Array = []
	const GRAPH_COLOR := Color(0.2, 0.9, 0.7)
	const GRID_COLOR := Color(0.2, 0.2, 0.25, 0.5)
	const BG_COLOR := Color(0.05, 0.08, 0.08, 0.9)
	const MARGIN := 4.0

	func _get_minimum_size() -> Vector2:
		return Vector2(236, 80)

	func _draw() -> void:
		var w := size.x - MARGIN * 2
		var h := size.y - MARGIN * 2
		var origin := Vector2(MARGIN, MARGIN)

		# Background
		draw_rect(Rect2(origin, Vector2(w, h)), BG_COLOR, true)

		# Grid lines
		for i in range(1, 4):
			var gy = origin.y + h * (float(i) / 4.0)
			draw_line(Vector2(origin.x, gy), Vector2(origin.x + w, gy), GRID_COLOR, 1.0)

		if price_history.is_empty():
			return

		# Determine value range
		var min_val: float = price_history[0]
		var max_val: float = price_history[0]
		for p in price_history:
			min_val = minf(min_val, p)
			max_val = maxf(max_val, p)

		# Add padding to range
		var range_pad = maxf((max_val - min_val) * 0.1, 5.0)
		min_val -= range_pad
		max_val += range_pad
		var val_range = max_val - min_val
		if val_range < 1.0:
			val_range = 1.0

		var num_points = price_history.size()

		# Draw line segments
		if num_points >= 2:
			for i in range(num_points - 1):
				var p1: float = price_history[i]
				var p2: float = price_history[i + 1]
				var x1 = origin.x + (float(i) / (num_points - 1)) * w
				var x2 = origin.x + (float(i + 1) / (num_points - 1)) * w
				var y1 = origin.y + h - ((p1 - min_val) / val_range) * h
				var y2 = origin.y + h - ((p2 - min_val) / val_range) * h
				draw_line(Vector2(x1, y1), Vector2(x2, y2), GRAPH_COLOR, 2.0)

		# Draw data points
		for i in range(num_points):
			var p: float = price_history[i]
			var px: float
			if num_points > 1:
				px = origin.x + (float(i) / (num_points - 1)) * w
			else:
				px = origin.x + w * 0.5
			var py = origin.y + h - ((p - min_val) / val_range) * h
			draw_circle(Vector2(px, py), 3.0, GRAPH_COLOR)

		# Border
		draw_rect(Rect2(origin, Vector2(w, h)), Color(0.2, 0.5, 0.4, 0.6), false, 1.0)
