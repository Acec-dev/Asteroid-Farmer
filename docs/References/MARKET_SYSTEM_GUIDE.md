# Market System & Price Graph Guide

## Overview

The market system has been refactored into a modular, timer-controlled architecture. This provides better control over price updates and enables price history tracking for graphical display.

## New Architecture

### Market.gd (Autoload Singleton)

**Location:** Autoloaded as `Market` (registered before GameState in project.godot)

**Purpose:**
- Handles all market price calculations
- Tracks price history (last 10 prices per mineral)
- Emits signals when prices change
- Provides timer-based price updates

**Key Features:**
```gdscript
# Configurable update interval
@export var update_interval: float = 3.0  # Seconds between price updates

# Current prices
var market_prices: Dictionary

# Price history (last 10 prices per mineral)
var price_history: Dictionary

# Signals
signal prices_changed(new_prices: Dictionary)

# Methods
func get_price(mineral: String) -> int
func get_price_history(mineral: String) -> Array
func record_nickel_sale(amount: int) -> void
func reset_market() -> void
```

**Pricing Models:**

1. **Iron:** Random walk (-1, 0, +1 per tick), range 1-7 credits
2. **Nickel:** Supply/demand based on player sales, range 1-7 credits
   - Selling nickel increases supply pressure
   - Pressure decays over time (0.15 per tick)
3. **Silica:** Predictable sine wave pattern, range 1-7 credits

### MineralPriceGraph.gd (Reusable 2D Node)

**Type:** `extends Control`

**Purpose:**
Displays a line graph of the last 10 prices for a specified mineral. Automatically updates when Market prices change.

**Configuration:**
```gdscript
# Select which mineral to track
@export var mineral_type: String = "iron"  # Options: "iron", "nickel", "silica"

# Visual customization
@export var line_color: Color = Color.CYAN
@export var line_width: float = 2.0
@export var point_radius: float = 4.0
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.8)
@export var grid_color: Color = Color(0.3, 0.3, 0.4, 0.5)
@export var show_grid: bool = true
@export var show_labels: bool = true

# Layout
@export var margin_left: float = 40.0
@export var margin_right: float = 20.0
@export var margin_top: float = 30.0
@export var margin_bottom: float = 30.0
```

**Methods:**
```gdscript
func set_mineral_type(new_mineral: String) -> void
func refresh() -> void  # Force redraw
```

## Integration Guide

### Option 1: Programmatically Add Graphs (No Scene Editing)

Add this to your InventoryMenu.gd or any Control node:

```gdscript
func _ready() -> void:
    # ... existing code ...

    # Create a price graph for iron
    var iron_graph = preload("res://MineralPriceGraph.gd").new()
    iron_graph.mineral_type = "iron"
    iron_graph.line_color = Color.STEEL_BLUE
    iron_graph.custom_minimum_size = Vector2(300, 200)
    iron_graph.position = Vector2(20, 20)  # Position it where you want
    add_child(iron_graph)
```

### Option 2: Add via Godot Editor (Scene File)

1. Open your InventoryMenu scene in Godot
2. Add a new node (Control or any parent you want)
3. Attach the `MineralPriceGraph.gd` script
4. In the Inspector, set:
   - `mineral_type` to "iron", "nickel", or "silica"
   - Customize colors and appearance
   - Set `custom_minimum_size` for desired graph dimensions
5. The graph will automatically connect to Market and update

### Option 3: Create a Dedicated Market Screen

See `PriceGraphExample.gd` for a complete example showing all three minerals side-by-side.

## Changes to GameState

GameState no longer calculates prices. Instead, it:
- Listens to `Market.prices_changed` signal
- Updates its `market_prices` dictionary when Market signals
- Forwards the `prices_changed` signal for backward compatibility
- Calls `Market.record_nickel_sale()` when nickel is sold

**GameState still provides:**
```gdscript
var market_prices: Dictionary       # Synced from Market
func get_market_price(mineral: String) -> int  # Convenience wrapper
```

## Controlling Price Update Timing

### Default Behavior
Prices update every 3 seconds automatically via Market's internal Timer node.

### Custom Update Interval

**Option 1: Change via script**
```gdscript
# In any script after Market is loaded
Market.update_interval = 5.0  # 5 seconds between updates
Market._timer.wait_time = Market.update_interval
```

**Option 2: Export and configure in scene**
Since Market is an autoload, you can't directly edit it in a scene. Instead, create a configuration script:

```gdscript
# MarketConfig.gd - attach to main scene or run in _ready()
func _ready() -> void:
    Market.update_interval = 5.0
    Market._timer.wait_time = 5.0
```

### Manual Price Updates
You can manually trigger price updates:
```gdscript
Market._update_market_prices()
```

## Signals

### Market Signals
```gdscript
# Emitted when prices change (every update_interval seconds)
Market.prices_changed.connect(func(new_prices: Dictionary):
    print("Iron: $%d" % new_prices["iron"])
)
```

### GameState Signals (unchanged)
```gdscript
GameState.prices_changed.connect(_on_prices_changed)
GameState.inventory_changed.connect(_on_inventory_changed)
GameState.credits_changed.connect(_on_credits_changed)
```

## Example: Adding Graph to Existing UI

If your InventoryMenu has a Panel with a VBox, add this to `InventoryMenu.gd`:

```gdscript
func _ready() -> void:
    # Existing code...
    GameState.inventory_changed.connect(_refresh)
    GameState.prices_changed.connect(_price_refresh)

    # Add price graph
    _add_price_graph()

func _add_price_graph() -> void:
    # Find or create a container for the graph
    var graph_container = HBoxContainer.new()
    $Panel/VBox.add_child(graph_container)

    # Add graphs for each mineral
    for mineral in ["iron", "nickel", "silica"]:
        var graph = preload("res://MineralPriceGraph.gd").new()
        graph.mineral_type = mineral
        graph.custom_minimum_size = Vector2(200, 150)

        # Color code by mineral
        match mineral:
            "iron": graph.line_color = Color.STEEL_BLUE
            "nickel": graph.line_color = Color.DARK_SEA_GREEN
            "silica": graph.line_color = Color.LIGHT_CORAL

        graph_container.add_child(graph)
```

## Testing the System

1. Run the game
2. Watch console output - Market prints price updates every 3 seconds:
   ```
   Market system initialized - prices update every 3.0 seconds
   Market Update - Iron: $1  Nickel: $2  Silica: $4
   Market Update - Iron: $2  Nickel: $2  Silica: $7
   ...
   ```
3. Add a MineralPriceGraph to any scene to see live visualization
4. Sell nickel to see supply/demand effects on nickel prices

## Best Practices

✅ **DO:**
- Use Market singleton for all price queries: `Market.get_price("iron")`
- Use `Market.get_price_history("iron")` to access historical data
- Let MineralPriceGraph update automatically (it listens to signals)
- Use different colors for different minerals in graphs

❌ **DON'T:**
- Don't manually modify `Market.market_prices` - let the timer handle it
- Don't access `GameState._nickel_recent_sales` - it's been removed
- Don't create your own price update timers - use Market's built-in one

## Troubleshooting

**Graph not updating:**
- Ensure Market is registered as autoload in project.godot
- Check that Market is loaded BEFORE GameState
- Verify the graph's `mineral_type` is spelled correctly

**Prices not changing:**
- Check console for Market update messages
- Verify Market._timer is running: `print(Market._timer.is_stopped())`

**Old code breaking:**
- If you have custom code accessing `GameState._market_timer`, remove it
- Replace any direct price calculations with `Market.get_price()`
- Update nickel sale tracking to use `Market.record_nickel_sale()`

## Architecture Decision: Why a Separate Market Node?

**Benefits:**
1. **Separation of Concerns:** GameState handles player state, Market handles economy
2. **Scalability:** Easy to expand market with trading, events, NPCs, supply chains
3. **Timer Control:** Node owns a Timer child for precise, controllable updates
4. **Testability:** Market can be tested independently
5. **Signal Architecture:** Clean separation - Market → signals → GameState + UI

**GameState Role:** Player data (credits, inventory, upgrades, shields)
**Market Role:** Economic simulation (prices, price history, market events)

This pattern follows Godot best practices for autoload singletons as system managers.
