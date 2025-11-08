# Quick Start: Mineral Price Graphs

## What's New

✨ **Market System Refactor:**
- New `Market.gd` autoload singleton handles all price calculations
- Timer-based updates (default: 3 seconds, configurable)
- Tracks price history (last 10 prices per mineral)

✨ **MineralPriceGraph Component:**
- Reusable 2D node for displaying price history
- Modular - configure which mineral to track
- Auto-updates when prices change
- Fully customizable appearance

## 30-Second Integration

Add this to any Control node in your game:

```gdscript
func _ready() -> void:
    # Create a graph for iron prices
    var graph = preload("res://MineralPriceGraph.gd").new()
    graph.mineral_type = "iron"  # or "nickel" or "silica"
    graph.custom_minimum_size = Vector2(300, 200)
    add_child(graph)
```

That's it! The graph will automatically:
- Connect to Market signals
- Display the last 10 prices
- Update when prices change

## Customization

```gdscript
var graph = preload("res://MineralPriceGraph.gd").new()
graph.mineral_type = "nickel"
graph.line_color = Color.GREEN
graph.line_width = 3.0
graph.show_grid = true
graph.background_color = Color(0.1, 0.1, 0.2, 0.9)
add_child(graph)
```

## Change Price Update Speed

```gdscript
# In your main scene _ready():
Market.update_interval = 5.0  # Update every 5 seconds
Market._timer.wait_time = 5.0
```

## Examples Included

- **PriceGraphExample.gd** - Standalone scene with all 3 graphs
- **InventoryMenuWithGraphs.gd** - How to add graphs to existing UI

## Files Added

- `Market.gd` - Market system (autoloaded as "Market")
- `MineralPriceGraph.gd` - Graph component
- `PriceGraphExample.gd` - Example scene
- `InventoryMenuWithGraphs.gd` - Integration example
- `MARKET_SYSTEM_GUIDE.md` - Complete documentation

## Files Modified

- `game_state.gd` - Now uses Market signals instead of internal calculations
- `project.godot` - Market registered as autoload (loads before GameState)

## Architecture

**Before:**
```
GameState._process() → calculates prices → emits signal → UI updates
```

**After:**
```
Market.Timer.timeout → calculates prices → emits signal → GameState & UI update
```

**Benefits:**
- Better separation of concerns
- Precise timer control
- Price history tracking
- Scalable for future market features

For complete documentation, see `MARKET_SYSTEM_GUIDE.md`
