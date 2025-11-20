# Weapon and Upgrade System Guide

This guide explains the new component-based weapon and upgrade system implemented in Asteroid Farmer.

## Architecture Overview

The game now uses a **component-based architecture** for weapons and upgrades:

```
Player
├── WeaponManager (manages all weapons)
│   ├── PrimaryCannon (always enabled)
│   ├── LaserBeam (unlock required)
│   ├── RocketLauncher (unlock required)
│   └── MineLayer (unlock required)
├── ShieldComponent (handles shield regen/damage)
└── RadarComponent (handles camera zoom)
```

## Benefits

- **Modular**: Each weapon is self-contained
- **Data-driven**: Upgrades are defined in GameState
- **Easy to extend**: Add new weapons without touching player.gd
- **Consistent interface**: All weapons work the same way
- **Auto-syncing**: Components automatically update when upgrades change

---

## How to Use Upgrades

All upgrades are managed through `GameState.upgrades`. Here's how to unlock and upgrade systems:

### Unlocking Weapons

```gdscript
# Unlock a weapon (makes it available to the player)
GameState.unlock_weapon("Laser Beam")
GameState.unlock_weapon("Rocket Launcher")
GameState.unlock_weapon("Mine Layer")
```

### Upgrading Weapons

```gdscript
# Upgrade a weapon to the next level (increases damage, reduces cooldown, etc.)
GameState.upgrade_weapon("Primary Cannon")
GameState.upgrade_weapon("Laser Beam")
```

### Upgrading Non-Weapon Systems

```gdscript
# Upgrade shield capacity
GameState.upgrade_system("shield", "max_capacity")

# Upgrade shield regen rate
GameState.upgrade_system("shield", "regen_rate")

# Upgrade radar (increases camera zoom)
GameState.upgrade_system("radar", "zoom_level")
```

### Checking Unlock Status

```gdscript
# Check if a weapon is unlocked
if GameState.is_weapon_unlocked("Laser Beam"):
    print("Laser is available!")
```

### Getting Current Values

```gdscript
# Get the current value of an upgrade
var max_shield = GameState.get_upgrade_value("shield", "max_capacity")
var zoom = GameState.get_upgrade_value("radar", "zoom_level")
```

---

## Upgrade Data Structure

All upgrades are defined in `GameState.upgrades`:

```gdscript
var upgrades = {
    "weapons": {
        "Primary Cannon": {
            "unlocked": true,  # Always unlocked
            "level": 0,
            "damage_values": [1.0, 2.0, 3.0, 5.0],
            "cooldown_values": [0.5, 0.4, 0.3, 0.2]
        },
        "Laser Beam": {
            "unlocked": false,
            "level": 0,
            "max_damage_values": [50.0, 75.0, 100.0, 150.0]
        },
        # ... more weapons
    },
    "shield": {
        "max_capacity": {
            "level": 0,
            "values": [100.0, 150.0, 200.0, 300.0, 500.0]
        },
        "regen_rate": {
            "level": 0,
            "values": [10.0, 15.0, 20.0, 30.0, 50.0]
        }
    },
    "radar": {
        "zoom_level": {
            "level": 0,
            "values": [1.0, 1.2, 1.5, 2.0, 2.5]
        }
    }
}
```

---

## Adding a New Weapon

To add a new weapon to the game:

### 1. Create the Weapon Script

Create a new file in `scripts/weapons/` that extends `WeaponBase`:

```gdscript
# scripts/weapons/my_weapon.gd
class_name MyWeapon
extends WeaponBase

func _init() -> void:
    weapon_name = "My Weapon"
    base_damage = 10.0
    base_cooldown = 1.0
    enabled = false  # Requires unlock

func _execute_fire() -> void:
    # Your weapon firing logic here
    print("My weapon fired!")
```

### 2. Add to GameState

Add weapon definition to `game_state.gd`:

```gdscript
var upgrades = {
    "weapons": {
        # ... existing weapons
        "My Weapon": {
            "unlocked": false,
            "level": 0,
            "damage_values": [10.0, 20.0, 30.0],
            "cooldown_values": [1.0, 0.8, 0.6]
        }
    }
}
```

### 3. Register in Player

Add to player.gd `_setup_weapon_system()`:

```gdscript
var my_weapon = MyWeapon.new()
weapon_manager.add_weapon(my_weapon, "secondary")
```

### 4. Unlock and Use

```gdscript
# Unlock the weapon when player purchases it
GameState.unlock_weapon("My Weapon")

# Upgrade it
GameState.upgrade_weapon("My Weapon")
```

---

## Adding a New Upgrade System

To add a new non-weapon upgrade (like shield/radar):

### 1. Create the Component Script

Create a new file in `scripts/components/`:

```gdscript
# scripts/components/my_component.gd
class_name MyComponent
extends Node

func _ready() -> void:
    sync_with_game_state()

    if GameState.has_signal("upgrades_changed"):
        GameState.upgrades_changed.connect(_on_upgrades_changed)

func sync_with_game_state() -> void:
    if GameState.upgrades.has("my_system"):
        # Read upgrade values here
        pass

func _on_upgrades_changed() -> void:
    sync_with_game_state()
```

### 2. Add to GameState

```gdscript
var upgrades = {
    # ... existing upgrades
    "my_system": {
        "my_upgrade": {
            "level": 0,
            "values": [1.0, 2.0, 3.0, 4.0]
        }
    }
}
```

### 3. Add to Player

```gdscript
func _ready() -> void:
    var my_component = MyComponent.new()
    add_child(my_component)
```

---

## Input Mapping

Weapons can be bound to input actions:

```gdscript
# In player.gd
weapon_manager.bind_input("fire_laser", "Laser Beam")
weapon_manager.bind_input("place_mine", "Mine Layer")
```

Or activate manually:

```gdscript
# In player.gd _handle_weapon_input()
if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
    weapon_manager.activate_weapon("Laser Beam")
else:
    weapon_manager.deactivate_weapon("Laser Beam")
```

---

## Weapon States

Each weapon has three states:
- **Unlocked**: Can the weapon be used? (set via `GameState.unlock_weapon()`)
- **Enabled**: Is the weapon currently active? (set via `weapon.enabled`)
- **Active**: Is the weapon currently firing? (controlled by input)

---

## Example: Shop/Upgrade System

Here's how you might implement a shop:

```gdscript
# In your shop/menu script
func purchase_laser_unlock():
    if GameState.credits >= 1000:
        GameState.add_credits(-1000)
        GameState.unlock_weapon("Laser Beam")
        print("Laser Beam unlocked!")

func purchase_shield_upgrade():
    if GameState.credits >= 500:
        GameState.add_credits(-500)
        GameState.upgrade_system("shield", "max_capacity")
        print("Shield upgraded!")

func purchase_radar_upgrade():
    if GameState.credits >= 300:
        GameState.add_credits(-300)
        GameState.upgrade_system("radar", "zoom_level")
        print("Radar upgraded! Camera zoom increased.")
```

---

## Testing Upgrades

To test upgrades during development, add this to your game start:

```gdscript
# In main.gd or player.gd _ready()
func _test_upgrades():
    # Unlock all weapons
    GameState.unlock_weapon("Laser Beam")
    GameState.unlock_weapon("Rocket Launcher")
    GameState.unlock_weapon("Mine Layer")

    # Upgrade shield
    GameState.upgrade_system("shield", "max_capacity")

    # Upgrade radar
    GameState.upgrade_system("radar", "zoom_level")

    print("All weapons unlocked for testing!")
```

---

## File Structure

```
Asteroid-Farmer/
├── player.gd                           # Main player script (now much cleaner!)
├── game_state.gd                       # Global state with upgrade registry
├── scripts/
│   ├── weapons/
│   │   ├── weapon_base.gd              # Base class for all weapons
│   │   ├── weapon_manager.gd           # Manages all weapons on player
│   │   ├── primary_cannon.gd           # Hitscan dual cannons
│   │   ├── laser_beam.gd               # Continuous beam weapon
│   │   ├── rocket_launcher.gd          # Homing rockets
│   │   └── mine_layer.gd               # Placeable mines
│   └── components/
│       ├── shield_component.gd         # Shield regen/damage system
│       └── radar_component.gd          # Camera zoom control
├── rocket.gd                           # Rocket projectile (spawned by RocketLauncher)
└── mine.gd                             # Mine projectile (spawned by MineLayer)
```

---

## Migration Notes

If you had custom code that used the old system:

### Old Way:
```gdscript
player.enable_laser()
player.enable_rockets()
```

### New Way:
```gdscript
GameState.unlock_weapon("Laser Beam")
GameState.unlock_weapon("Rocket Launcher")
```

The old `enable_*()` functions still exist in player.gd for backward compatibility, but they now just call the GameState functions.

---

## Troubleshooting

**Q: Weapon not firing after unlock?**
A: Make sure you called `weapon_manager.sync_upgrades()` after unlocking. This happens automatically if you use `GameState.unlock_weapon()`.

**Q: Shield not regenerating?**
A: Check that `ShieldComponent` is added as a child of the player and that `take_damage()` is being called on the player.

**Q: Camera not zooming with radar upgrade?**
A: Make sure there's a Camera2D node in the scene. `RadarComponent` will search for it automatically.

**Q: Upgrades not persisting between scenes?**
A: GameState is an autoload singleton, so upgrades persist. Make sure you're not resetting the upgrades dictionary somewhere.

---

## Performance Notes

- Weapons only update when enabled
- Components use signals to avoid polling GameState every frame
- Projectiles (rockets, mines) are still separate scenes - no pooling yet
- Future optimization: Implement object pooling for projectiles

---

## Future Enhancements

Possible additions to the system:
- Weapon ammo system
- Weapon combo/synergy effects
- Upgrade cost scaling
- Save/load upgrade state
- Weapon slot limits
- Upgrade tree/dependencies
- Projectile pooling
- Weapon stat UI/tooltips
