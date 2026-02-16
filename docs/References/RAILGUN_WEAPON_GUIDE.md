# Railgun Weapon Guide

## Overview

The **Railgun** is a high-damage, piercing weapon that fires a powerful shot through multiple asteroids in a line. It's designed for tactical, high-impact moments and rewards precise aim.

---

## Key Features

### **Piercing Shots**
- Fires through multiple asteroids in a single shot
- Damage decreases with each pierce (damage falloff)
- Can hit up to 20 asteroids per shot (configurable)

### **High Damage**
- Base damage: **3.0** (compared to Primary Cannon's 1.0)
- Damage upgradeable to 7.0 at max level
- Ideal for clearing dense asteroid clusters

### **Manual Fire**
- Press **R** key to fire (edge-detected, no auto-fire)
- 2 second cooldown between shots
- Cooldown reduces with upgrades

### **Visual Feedback**
- Electric blue beam shows shot trajectory
- White flash on fire, fades to cyan
- Beam duration: 0.15 seconds

---

## Stats

| Level | Damage | Cooldown | Pierce Falloff | Effective Hits* |
|-------|--------|----------|----------------|-----------------|
| 0 | 3.0 | 2.0s | 20% | ~6 asteroids |
| 1 | 4.0 | 1.75s | 15% | ~8 asteroids |
| 2 | 5.0 | 1.5s | 10% | ~12 asteroids |
| 3 | 7.0 | 1.25s | 5% | ~18 asteroids |

*Effective Hits = Number of asteroids destroyed before damage falls below 0.5

### Damage Falloff Explained

Pierce falloff determines how much damage is retained after hitting each asteroid:

- **20% falloff**: Each hit reduces damage by 20%
  - 1st hit: 3.0 damage
  - 2nd hit: 2.4 damage (80% of 3.0)
  - 3rd hit: 1.92 damage (80% of 2.4)
  - 4th hit: 1.54 damage
  - ...continues until < 0.5

- **5% falloff** (max level): Each hit reduces damage by only 5%
  - 1st hit: 7.0 damage
  - 2nd hit: 6.65 damage (95% of 7.0)
  - 3rd hit: 6.32 damage
  - ...much longer effective range!

---

## Usage

### **Unlocking the Railgun**
```gdscript
GameState.unlock_weapon("Railgun")
```

### **Upgrading the Railgun**
```gdscript
GameState.upgrade_weapon("Railgun")
```

### **Firing**
1. Aim at a cluster of asteroids
2. Press **R** key
3. Wait for cooldown before next shot

### **Best Use Cases**

✅ **Do use when:**
- Multiple asteroids are lined up
- Facing dense asteroid clusters
- High-value targets (multiple asteroids in formation)
- Need burst damage with limited shots

❌ **Don't use when:**
- Only one asteroid in range (use primary cannon instead)
- Asteroids are scattered (low pierce value)
- In the middle of cooldown (no effect)

---

## Tactical Tips

### **Positioning**
- Line up shots to maximize pierce count
- Wait for asteroids to cluster naturally
- Use radar zoom to spot dense formations

### **Timing**
- Don't waste shots on single targets
- Save for "oh shit" moments with many asteroids
- Use during high-difficulty waves

### **Combo with Other Weapons**
- **Primary Cannon**: Clean up stragglers after railgun shot
- **Laser Beam**: Focus single tough asteroids between railgun cooldowns
- **Rockets**: Clear wide areas while railgun recharges

---

## Upgrade Priority

Recommended upgrade path:

1. **Unlock Railgun** (Level 0)
   - Immediate access to piercing shots
   - Good for learning the weapon

2. **First Upgrade** (Level 1)
   - +1.0 damage (3.0 → 4.0)
   - Better pierce falloff (20% → 15%)
   - Recommended early upgrade

3. **Second Upgrade** (Level 2)
   - +1.0 damage (4.0 → 5.0)
   - Faster cooldown (1.75s → 1.5s)
   - Even better falloff (15% → 10%)

4. **Max Upgrade** (Level 3)
   - +2.0 damage (5.0 → 7.0)
   - Fastest cooldown (1.25s)
   - Minimal falloff (5%)
   - **Most powerful weapon in the game**

---

## Technical Details

### **How Piercing Works**

The railgun uses repeated raycasts to find all asteroids in its path:

1. Fire raycast in aimed direction
2. If hit, apply damage and add to exclusion list
3. Reduce damage by falloff percentage
4. Repeat raycast excluding already-hit asteroids
5. Continue until damage < 0.5 or max pierce count reached

### **Damage Application**

The railgun attempts three damage methods:
1. `hit_by_railgun(weapon, damage)` - Custom railgun handler
2. `hit_by_projectile(owner)` - Standard weapon handler
3. `take_damage(amount)` - Generic damage handler

### **Visual Beam**

- Rendered using `Line2D` node
- Points: Start position → Last hit position (or max range)
- Color fades from white → cyan over 0.15 seconds
- Alpha decreases over beam duration

---

## Customization

Want to tweak the railgun? Edit these properties:

```gdscript
# In railgun.gd
max_range = 2500.0              # How far the shot travels
pierce_damage_falloff = 0.2     # Damage reduction per pierce
max_pierce_count = 20           # Maximum asteroids to pierce
min_pierce_damage = 0.5         # Stop piercing below this

# Visual properties
beam_width = 20.0               # Beam thickness
beam_duration = 0.15            # How long beam is visible
beam_color = Color(0.2, 0.8, 1.0)  # Cyan color
```

---

## Example Shop Integration

```gdscript
# Unlock railgun for 2000 credits
func buy_railgun_unlock():
    if GameState.credits >= 2000:
        GameState.add_credits(-2000)
        GameState.unlock_weapon("Railgun")
        print("Railgun unlocked! Press R to fire!")

# Upgrade railgun for 1500 credits
func buy_railgun_upgrade():
    if GameState.credits >= 1500:
        GameState.add_credits(-1500)
        if GameState.upgrade_weapon("Railgun"):
            print("Railgun upgraded!")
        else:
            print("Already at max level!")
```

---

## Input Controls

| Key | Action |
|-----|--------|
| **R** | Fire Railgun |
| Right Click | Laser Beam |
| M | Place Mine |
| Auto | Primary Cannon |
| Auto | Rockets (when unlocked) |

---

## Balancing Notes

The railgun is designed to be:
- **High skill ceiling**: Rewards good positioning and timing
- **High impact**: Game-changing when used correctly
- **Limited use**: Long cooldown prevents spam
- **Scalable**: Upgrades significantly improve performance

At max level, the railgun can clear entire asteroid waves with a single well-placed shot.

---

## Future Enhancements

Possible additions:
- **Charge mechanic**: Hold R to charge for more damage
- **Overcharge**: Higher damage but longer cooldown
- **Ricochet**: Shots bounce between asteroids
- **Heat system**: Fire too quickly and weapon overheats
- **Scope mode**: Zoom in for precise aiming

---

## Summary

**Railgun at a Glance:**
- **Damage**: High (3-7)
- **Fire Rate**: Slow (every 1.25-2s)
- **Range**: Very Long (2500 units)
- **Pierce**: Yes (up to 20 targets)
- **Control**: Manual (R key)
- **Unlock Cost**: High (premium weapon)

**Perfect for:** Players who value precision over spray, tactical gameplay over button mashing, and satisfying one-shot multi-kills over constant firing.

**Pairs well with:** Radar upgrades (for spotting clusters), Shield upgrades (while waiting for cooldown), Primary Cannon (for cleanup).

**The ultimate "delete that cluster" button!**
