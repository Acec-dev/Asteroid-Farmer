# Asteroid Spawner System Guide

## Overview

The new **AsteroidSpawner** component provides a modular, configurable asteroid spawning system that addresses several issues with the original implementation:

### Problems Solved:
1. ✅ **Visible spawn radius** - Asteroids now spawn at screen edges (beyond camera view)
2. ✅ **Predictable trajectories** - Asteroids fly across the screen instead of toward the player
3. ✅ **No configurability** - Now fully modular with difficulty scaling
4. ✅ **Fixed stats** - Asteroid health, speed, and count are now configurable
5. ✅ **Better balance** - Mix of active hunting and passive dodging

---

## Architecture

```
Main Scene
└── AsteroidSpawner (Component)
    ├── Spawns at screen edges
    ├── Random trajectories across screen
    ├── Syncs with GameState difficulty
    └── Auto-adjusts spawn rate, speed, health
```

---

## How It Works

### 1. Screen-Edge Spawning

Asteroids spawn just outside the visible camera bounds:

```
Screen Edges:
┌─────────────────────────────┐
│ ←Top edge (random X)        │
│ ↓                           │
│ Left edge  [Camera View]    │ Right edge
│ (random Y)                  │ (random Y)
│                           ↑ │
│        Bottom edge (random X)│
└─────────────────────────────┘
```

The spawner:
- Calculates current camera bounds (accounts for zoom!)
- Picks random edge (top/right/bottom/left)
- Spawns `spawn_edge_buffer` pixels beyond visible area (default: 100px)

**This fixes the "visible spawn ring" problem when camera zooms out!**

---

### 2. Trajectory Modes

The spawner supports multiple trajectory modes:

#### **RANDOM_ACROSS** (Default - Recommended)
Asteroids fly across the screen in random directions:
- Spawns from top → aims toward bottom half
- Spawns from bottom → aims toward top half
- Spawns from left → aims toward right half
- Spawns from right → aims toward left half

**Behavior:**
- Player must seek out some asteroids (active hunting)
- Player must dodge asteroids that cross their path (passive defense)
- Natural, realistic asteroid field feeling

#### **TOWARD_PLAYER** (Original Behavior)
Asteroids aim toward the player position.

#### **TOWARD_CENTER**
Asteroids aim toward the screen center.

#### **MIXED**
- 60% random across
- 20% toward player
- 20% toward center

**Example:**
```gdscript
# In main.gd setup
asteroid_spawner.trajectory_mode = AsteroidSpawner.TrajectoryMode.RANDOM_ACROSS
```

---

### 3. Difficulty Scaling

The spawner automatically adjusts based on `GameState.upgrades.spawner.difficulty.level`:

| Level | Name | Interval | Count/Spawn | Health | Speed Range |
|-------|------|----------|-------------|--------|-------------|
| 0 | Easy | 3.0s | 1 | 2 | 150-250 |
| 1 | Normal | 2.0s | 1 | 2 | 200-300 |
| 2 | Hard | 1.5s | 1 | 3 | 250-400 |
| 3 | Very Hard | 1.0s | 2 | 3 | 300-500 |
| 4+ | Extreme | 0.8s | 2 | 4 | 350-600 |

**Default:** Level 1 (Normal)

---

## Usage

### Basic Usage (Automatic)

The spawner is automatically set up in `main.gd` and syncs with GameState:

```gdscript
# main.gd (already done)
func _setup_asteroid_spawner() -> void:
    asteroid_spawner = AsteroidSpawner.new()
    asteroid_spawner.asteroid_scene = asteroid_scene
    asteroid_spawner.player = _player
    asteroid_spawner.camera = player_cam
    asteroid_spawner.trajectory_mode = AsteroidSpawner.TrajectoryMode.RANDOM_ACROSS
    add_child(asteroid_spawner)
```

That's it! The spawner will:
- Auto-find the camera
- Sync with GameState difficulty
- Start spawning asteroids

---

### Controlling Difficulty

#### **Set Difficulty Level**
```gdscript
# Set specific difficulty
GameState.set_spawner_difficulty(2)  # Hard mode

# Increase difficulty (for progression)
GameState.increase_spawner_difficulty()

# Get current difficulty
var current_diff = GameState.get_spawner_difficulty()
```

#### **In a Shop/Upgrade System**
```gdscript
func buy_difficulty_increase():
    if GameState.credits >= 500:
        GameState.add_credits(-500)
        if GameState.increase_spawner_difficulty():
            print("Difficulty increased! More asteroids, higher rewards!")
```

#### **Wave-Based Progression**
```gdscript
# Increase difficulty every N asteroids destroyed
var asteroids_destroyed = 0

func on_asteroid_destroyed():
    asteroids_destroyed += 1

    if asteroids_destroyed % 50 == 0:  # Every 50 asteroids
        GameState.increase_spawner_difficulty()
        print("Wave ", asteroids_destroyed / 50, " complete! Difficulty increased!")
```

---

### Manual Configuration

You can also manually configure the spawner:

```gdscript
# Set custom spawn rate
asteroid_spawner.spawn_interval = 1.5  # Seconds between spawns
asteroid_spawner.spawn_count = 2  # Asteroids per spawn

# Set custom asteroid stats
asteroid_spawner.asteroid_health = 3  # Hit points
asteroid_spawner.asteroid_speed_min = 200.0
asteroid_spawner.asteroid_speed_max = 400.0

# Change trajectory mode
asteroid_spawner.trajectory_mode = AsteroidSpawner.TrajectoryMode.MIXED

# Pause/resume spawning
asteroid_spawner.set_spawning_enabled(false)  # Pause
asteroid_spawner.set_spawning_enabled(true)   # Resume

# Manually trigger spawn (for testing)
asteroid_spawner.spawn_now(5)  # Spawn 5 asteroids immediately
```

---

## Advanced Features

### Custom Trajectory Patterns

Want to add custom trajectory logic? Modify `_get_direction_for_edge()` in `asteroid_spawner.gd`:

```gdscript
# Example: Spiral pattern
func _get_custom_trajectory(spawn_pos: Vector2) -> Vector2:
    var angle = Time.get_ticks_msec() / 1000.0
    return Vector2.RIGHT.rotated(angle)
```

### Size Variation

Want variable asteroid sizes? Extend the spawner:

```gdscript
# In _spawn_single_asteroid()
asteroid.radius = randf_range(20.0, 40.0)  # Random size
```

### Mineral Type Control

Want specific mineral types at higher difficulties?

```gdscript
# In _spawn_single_asteroid()
if _difficulty_level >= 3:
    asteroid.mineral_kind = GameState.MineralType.NICKEL  # Rare minerals
else:
    asteroid.mineral_kind = GameState.MineralType.IRON  # Common
```

---

## Spawn Edge Buffer

The `spawn_edge_buffer` controls how far beyond the screen asteroids spawn:

```gdscript
asteroid_spawner.spawn_edge_buffer = 200.0  # Spawn 200px off-screen
```

**Recommendations:**
- **Small buffer (50-100px):** Asteroids appear suddenly (more challenging)
- **Medium buffer (100-200px):** Default, balanced
- **Large buffer (200-400px):** More warning time (easier)

---

## Signals

The spawner emits signals for integration:

```gdscript
# Connect to spawner events
asteroid_spawner.asteroid_spawned.connect(_on_asteroid_spawned)

func _on_asteroid_spawned(asteroid: Asteroid):
    print("Asteroid spawned at: ", asteroid.global_position)
    # Track total spawned, update UI, etc.
```

---

## Testing

### Test Difficulty Levels

Use the test script to quickly test different difficulty levels:

```gdscript
# test_asteroid_spawner.gd
extends Node

func _ready():
    # Test difficulty 3 (Very Hard)
    GameState.set_spawner_difficulty(3)

func _input(event):
    # Press 0-4 to set difficulty
    if event.is_action_pressed("ui_text_0"):
        GameState.set_spawner_difficulty(0)  # Easy
    elif event.is_action_pressed("ui_text_1"):
        GameState.set_spawner_difficulty(1)  # Normal
    elif event.is_action_pressed("ui_text_2"):
        GameState.set_spawner_difficulty(2)  # Hard
    elif event.is_action_pressed("ui_text_3"):
        GameState.set_spawner_difficulty(3)  # Very Hard
    elif event.is_action_pressed("ui_text_4"):
        GameState.set_spawner_difficulty(4)  # Extreme
```

### Spawn Test

```gdscript
# Manually spawn asteroids for testing
asteroid_spawner.spawn_now(10)  # Spawn 10 at once
```

---

## Performance Notes

- **Spawner overhead:** Negligible (one timer + simple calculations)
- **Asteroid cleanup:** Godot handles via `queue_free()`
- **Off-screen culling:** Asteroids naturally leave the screen and can be removed

### Optional: Auto-Cleanup Off-Screen Asteroids

Add this to the spawner:

```gdscript
func _cleanup_far_asteroids():
    var max_distance = 3000.0  # Clean up asteroids 3000px from camera
    var asteroids = get_tree().get_nodes_in_group("asteroids")

    for asteroid in asteroids:
        if asteroid.global_position.distance_to(camera.global_position) > max_distance:
            asteroid.queue_free()
```

---

## Comparison: Old vs New

### Old System (main.gd)
```gdscript
# Hardcoded spawn ring around player
var spawn_ring_radius = 900.0
var spawn_pos = player.position + Vector2.RIGHT.rotated(angle) * 900

# Asteroids aim toward player area
var target = player.position + random_offset
asteroid.setup_motion(spawn_pos, target, speed)

# Fixed stats
var speed = randf_range(220, 360)
var health = 2
```

**Problems:**
- Spawn ring visible when camera zooms out
- Asteroids always come toward player (predictable)
- No difficulty scaling
- Not configurable

### New System (AsteroidSpawner)
```gdscript
# Spawn at screen edges (accounts for camera zoom)
var spawn_pos = _get_screen_edge_position()

# Asteroids fly across screen
var direction = _get_random_across_direction()
asteroid.setup_motion(spawn_pos, spawn_pos + direction * 5000, speed)

# Difficulty-scaled stats
var speed = randf_range(asteroid_speed_min, asteroid_speed_max)
var health = asteroid_health  # Scales with difficulty
```

**Benefits:**
- Always spawns off-screen (no visible spawn ring)
- Natural, varied trajectories
- Difficulty scales automatically
- Fully configurable

---

## Troubleshooting

**Q: Asteroids not spawning?**
A: Check that `asteroid_spawner.camera` is set. The spawner needs a camera reference to calculate screen bounds.

**Q: Asteroids spawning in weird locations?**
A: Make sure the camera zoom is properly detected. Check `camera.zoom` value.

**Q: Difficulty not changing?**
A: Call `GameState.set_spawner_difficulty(level)` and verify `GameState.upgrades_changed` signal is emitted.

**Q: Want to pause spawning?**
A: Use `asteroid_spawner.set_spawning_enabled(false)`.

**Q: Asteroids too fast/slow?**
A: Adjust `asteroid_speed_min` and `asteroid_speed_max`, or change difficulty level.

---

## Future Enhancements

Possible additions:
- **Asteroid types:** Different asteroid classes with unique properties
- **Spawn patterns:** Waves, clusters, formations
- **Dynamic difficulty:** Auto-adjust based on player performance
- **Asteroid density zones:** Denser fields in certain areas
- **Boss asteroids:** Special large asteroids with unique mechanics
- **Comet events:** Fast-moving rare asteroids with bonus rewards

---

## Summary

The new AsteroidSpawner component:
- ✅ Spawns asteroids at screen edges (not player radius)
- ✅ Flies across screen (not toward player)
- ✅ Difficulty scaling (5 levels)
- ✅ Fully configurable (speed, health, count, trajectory)
- ✅ Auto-syncs with GameState
- ✅ Easy to extend and customize

**Recommended settings:**
- Trajectory: `RANDOM_ACROSS`
- Difficulty: Start at 1 (Normal), increase with progression
- Edge buffer: 100px

**Result:** A dynamic, challenging asteroid field that requires both active hunting and defensive play!
