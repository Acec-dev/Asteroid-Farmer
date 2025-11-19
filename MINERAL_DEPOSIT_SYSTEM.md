# Mineral Deposit System

## Overview

The Mineral Deposit System allows players to collect and store minerals in a visual container box. Players can fly over the deposit box and release minerals, which fall down and accumulate in the container with a visual representation.

## Features

- **Visual Container**: A rectangular box that displays accumulated minerals
- **Falling Physics**: Minerals drop from the player ship with gravity
- **Color-Coded Minerals**: Different mineral types have distinct colors
  - Iron: Gray (0.7, 0.7, 0.7)
  - Nickel: Yellowish (0.9, 0.9, 0.6)
  - Silica: Light Blue (0.6, 0.8, 1.0)
- **Range Detection**: Box highlights when player is in range
- **Batch Deposits**: Drop multiple minerals at once

## Usage

### For Players

1. **Collect Minerals**: Destroy asteroids to collect minerals as usual
2. **Fly to Deposit Box**: Navigate your ship over the deposit box (default location: bottom center of screen at 640, 600)
3. **Deposit Minerals**: When over the box (it will highlight), press **E** or **Space** to drop minerals
4. **Watch Them Fall**: Minerals fall from your ship into the box below

### Controls

- **E Key** or **Space**: Drop minerals into the deposit box (when in range)

## Configuration

### MineralDepositBox Properties

Located in `mineral_deposit_box.gd`:

```gdscript
@export var box_width: float = 200.0           # Width of container
@export var box_height: float = 150.0          # Height of container
@export var visual_mineral_size: float = 3.0   # Size of displayed minerals
@export var max_visual_minerals: int = 100     # Max minerals shown (performance limit)
```

### Player Properties

Located in `player.gd`:

```gdscript
@export var minerals_per_drop: int = 5      # Minerals dropped per button press
@export var drop_spread: float = 30.0       # Horizontal spread of dropped minerals
```

### Main Scene Configuration

Located in `main.gd`:

```gdscript
@export var spawn_deposit_box: bool = true              # Enable/disable deposit box
@export var deposit_box_position: Vector2 = Vector2(640, 600)  # Box location
```

## API Reference

### MineralDepositBox

#### Methods

- `add_mineral(type: GameState.MineralType)` - Add a mineral to the deposit
- `get_total_minerals() -> int` - Get total count of deposited minerals
- `withdraw_all() -> Dictionary` - Remove and return all deposited minerals
- `is_player_in_range() -> bool` - Check if player is within deposit range

#### Properties

- `deposited_minerals: Dictionary` - Tracks count by mineral type
- `_visual_minerals: Array[Dictionary]` - Visual representation data

### FallingMineral

A physics-enabled mineral that falls from the player ship.

#### Methods

- `set_initial_velocity(vel: Vector2)` - Set starting velocity

#### Properties

- `kind: GameState.MineralType` - Type of mineral
- `fall_speed: float = 200.0` - Base falling speed
- `gravity: float = 400.0` - Gravity acceleration
- `lifetime: float = 5.0` - Auto-delete timer

## Integration

### Adding to Your Scene

The deposit box is automatically spawned in `main.gd`:

```gdscript
func _spawn_deposit_box() -> void:
    var deposit_box_script = load("res://mineral_deposit_box.gd")
    _deposit_box = Area2D.new()
    _deposit_box.set_script(deposit_box_script)
    _deposit_box.global_position = deposit_box_position
    add_child(_deposit_box)
```

### Manual Instantiation

```gdscript
# Create deposit box
var box = Area2D.new()
box.set_script(load("res://mineral_deposit_box.gd"))
box.global_position = Vector2(640, 600)
add_child(box)
```

## Future Enhancements

Potential improvements to consider:

1. **Multiple Boxes**: Support for multiple deposit locations
2. **Auto-Collect**: Option to automatically collect when flying over
3. **Visual Effects**: Particle effects when minerals are deposited
4. **Storage Upgrades**: Increase box capacity through gameplay
5. **Sell from Box**: Direct selling from deposit box
6. **Box Types**: Different boxes for different mineral types
7. **Mineral Sorting**: Automatic sorting by type within the box

## Technical Details

### Physics System

- Falling minerals use Area2D with custom velocity
- Gravity is applied each frame in `_process()`
- Collision detection triggers collection

### Performance

- Visual mineral display is capped at `max_visual_minerals` (default: 100)
- Actual storage is unlimited (dictionary-based)
- Old minerals are auto-deleted after 5 seconds if uncollected

### Event Flow

1. Player presses deposit key (E/Space)
2. Player script checks for nearby deposit box
3. Minerals removed from GameState inventory
4. FallingMineral instances spawned
5. Minerals fall with gravity
6. Box's Area2D detects falling minerals
7. Minerals added to box storage
8. Visual representation updated
9. Box redraws to show new minerals

## Files

- `mineral_deposit_box.gd` - Container logic and visual representation
- `falling_mineral.gd` - Physics-enabled dropping mineral
- `player.gd` - Modified to handle deposit input and mineral dropping
- `main.gd` - Modified to spawn deposit box in scene

## License

Part of the Asteroid Farmer project.
