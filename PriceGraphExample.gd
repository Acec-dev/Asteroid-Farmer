extends Control
## Example scene demonstrating MineralPriceGraph usage
## Shows three graphs side-by-side for Iron, Nickel, and Silica

func _ready() -> void:
	# Set up the layout
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	add_child(margin_container)

	var vbox = VBoxContainer.new()
	margin_container.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Mineral Price Graphs - Live Market Data"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Add spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# Container for the three graphs
	var graph_container = HBoxContainer.new()
	graph_container.add_theme_constant_override("separation", 20)
	vbox.add_child(graph_container)

	# Create Iron graph
	var iron_graph = preload("res://MineralPriceGraph.gd").new()
	iron_graph.mineral_type = "iron"
	iron_graph.line_color = Color.STEEL_BLUE
	iron_graph.custom_minimum_size = Vector2(350, 250)
	graph_container.add_child(iron_graph)

	# Create Nickel graph
	var nickel_graph = preload("res://MineralPriceGraph.gd").new()
	nickel_graph.mineral_type = "nickel"
	nickel_graph.line_color = Color.DARK_SEA_GREEN
	nickel_graph.custom_minimum_size = Vector2(350, 250)
	graph_container.add_child(nickel_graph)

	# Create Silica graph
	var silica_graph = preload("res://MineralPriceGraph.gd").new()
	silica_graph.mineral_type = "silica"
	silica_graph.line_color = Color.LIGHT_CORAL
	silica_graph.custom_minimum_size = Vector2(350, 250)
	graph_container.add_child(silica_graph)

	# Add info label
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	var info = Label.new()
	info.text = "Prices update every %.1f seconds. Graphs show last 10 prices." % Market.update_interval
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	print("Price Graph Example scene initialized")
