extends SceneTree

# Test script to simulate market prices
# Run with: godot --script test_market_simulation.gd

func _init():
	# Create GameState instance
	var game_state = preload("res://game_state.gd").new()

	print("\n" + "="*60)
	print("SCENARIO 1: Normal market fluctuation (30 ticks, no sales)")
	print("="*60)
	game_state.simulate_market_ticks(30)

	print("\n" + "="*60)
	print("SCENARIO 2: Selling 10 nickel at tick 5")
	print("="*60)
	game_state.simulate_market_ticks(30, 5, 10)

	print("\n" + "="*60)
	print("SCENARIO 3: Selling 20 nickel at tick 10")
	print("="*60)
	game_state.simulate_market_ticks(30, 10, 20)

	quit()
