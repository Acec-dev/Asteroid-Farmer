Asteroid Farmer
--------------

Asteroid Farmer is a minimalist 2D black and white space action game inspired by the classic arcade game Asteroids. The player controls a small white spaceship in an empty black void, shooting and destroying asteroids to collect valuable minerals. These minerals can be sold for credits that can be used to buy upgrades, improving the ship’s performance and weapons over time.

The game focuses on smooth controls, clear visuals, and a satisfying gameplay loop built around mining, upgrading, and surviving in an endless asteroid field.

Core Gameplay

1. The player controls a small ship using the keyboard and mouse or a controller.
   - WASD or the left analog stick moves the ship in any direction.
   - The ship always rotates to face the cursor (or the right stick on a controller).
   - This setup allows twin-stick-style movement and aiming.
2. The ship automatically fires two hitscan projectiles in a straight line from its nose at a steady rate (visual projectiles are displayed for feedback).
3. Asteroids drift across space. The player shoots them to break them apart. Large asteroids require 2 hits, small ones require 1 hit.
4. The player must avoid colliding with asteroids, as they deal shield damage. When shields reach zero, the game ends.
5. Shields regenerate automatically after a 3-second delay, adding tactical survival gameplay.
6. Destroyed asteroids can drop mineral items (iron, nickel, silica).
7. The player collects minerals by flying into them. Floating "+1 [mineral]" text provides immediate feedback.
8. Minerals are stored in an inventory and can be sold for credits based on dynamic market prices that fluctuate every 3 seconds.
9. Credits are used to purchase ship upgrades, such as faster firing, shield capacity, shield regeneration, and the homing rocket secondary weapon.

Asteroid Behavior

Asteroids spawn in a ring around the player at random angles and distances. Each asteroid moves along a straight path that passes roughly through a central region of the game space, but not always through the exact center. This makes movement patterns appear natural and varied.

Asteroids have a health system based on their size:
- **Large asteroids** have 2 hit points and require multiple shots to destroy
- **Small asteroids** have 1 hit point and are destroyed in a single hit

Large asteroids split into two smaller ones when destroyed. Smaller asteroids are faster and can still drop minerals. All asteroids move with no gravity or drag, coasting endlessly through space after receiving their initial impulse. When asteroids collide with the player, they damage the player's shield and are destroyed in the impact, creating natural risk-reward tension.

Player Movement

The player moves freely in two dimensions. There is no gravity or friction. Movement is based on direct velocity control. The ship accelerates smoothly in the direction of input and can move independently of its facing direction. The ship always points toward the cursor, allowing precise aiming and shooting while drifting in any direction.

Projectiles and Weapons

The player ship has two weapon systems:

1. **Primary Hitscan Cannons**: The ship fires two instant hitscan shots simultaneously. Although visual projectiles are displayed for feedback, the actual damage is applied instantly via raycasting with a maximum range of 2000 units. Each shot deals 1 damage. Large asteroids require 2 hits to destroy, while small asteroids require only 1 hit.

2. **Secondary Rocket System**: An upgradeable secondary weapon that fires homing rockets. Rockets actively track the nearest asteroid within a 500-unit detection radius, rotating at 3 radians/second to home in on targets. Upon impact, rockets explode with an 80-unit blast radius, damaging all nearby asteroids. Rockets have a 3-second lifetime and travel at 400 units/second.

Shield System and Combat

The player ship is protected by a regenerating shield system:

- **Shield Capacity**: The player starts with 100 shield points (upgradeable)
- **Collision Damage**: Asteroids deal 20 damage on collision, scaled by their size (larger asteroids = more damage)
- **Shield Regeneration**: After taking damage, shields begin regenerating after a 3-second delay at 10 points per second (both values are upgradeable)
- **Visual Feedback**: When damaged, the ship flashes red briefly
- **Shield Bar UI**: A white bar at the top of the screen displays current shield level, shrinking from right to left as damage is taken
- **Death and Game Over**: When shields are depleted to zero, the game ends and transitions to a game over screen with a restart option after 2 seconds

The shield system adds survival pressure to the otherwise endless mining loop, requiring players to balance aggressive mining with careful positioning to avoid asteroid collisions.

Minerals and Inventory

Each destroyed asteroid has a chance to drop one or more minerals. These include iron, nickel, and silica. When collected, the minerals are added to the player's inventory and a floating text label appears showing "+1 [mineral name]" that rises upward before fading away, providing immediate visual feedback.

The inventory is displayed in a simple menu showing the quantity of each mineral, for example:

Iron: 5
Nickel: 2
Silica: 0

The inventory updates automatically whenever the player collects or sells minerals. The GameState singleton tracks all mineral counts, credits, and upgrade information. It emits a signal whenever mineral quantities change, allowing the UI to update in real time.

Economy and Upgrades

Minerals can be sold from the inventory menu for credits. The game features a **dynamic market pricing system** where mineral values fluctuate over time:

- **Iron**: Follows a random walk pattern, changing by -1, 0, or +1 credits every 3 seconds (price range: 1-7 credits)
- **Nickel**: Uses supply and demand mechanics - the price drops when you sell large quantities and gradually recovers over time as sales pressure decays (price range: 1-7 credits)
- **Silica**: Follows a sine wave pattern, creating predictable boom-and-bust cycles (price range: 1-7 credits)

This dynamic pricing adds strategic depth, encouraging players to time their sales and diversify their mining targets based on current market conditions.

Credits are used to buy upgrades that enhance the ship. Available upgrades include:

- Faster firing rate (fire_rate in GameState)
- Higher projectile speed
- Improved movement speed and handling
- Increased shield capacity (max_shield)
- Faster shield regeneration (shield_regen_rate)
- Reduced shield regeneration delay
- Secondary rocket weapon unlock

Upgrades create a sense of progression as the player becomes more efficient at mining and combat.

Visual Style

The entire game is rendered in black and white.
- Background: solid black
- Ships, asteroids, and projectiles: white outlines or filled polygons drawn using the _draw() function
- Minerals: small white shapes or dots
The visual style is inspired by vector-display arcade games. It is clean, simple, and high contrast.

User Interface

The game features a minimalist UI that displays essential information:

- **Shield Bar**: A white horizontal bar at the top of the screen showing current shield status. The bar shrinks from right to left as damage is taken, with a white outline showing maximum capacity.
- **Inventory Menu**: Text labels showing mineral counts and player credits, updating automatically through signals.
- **Floating Feedback Text**: When collecting minerals, "+1 [mineral name]" text floats upward from the player ship before fading away.
- **Market Prices**: Dynamic display of current mineral prices that update every 3 seconds.

The interface is minimal, high-contrast (black and white), and designed for clarity during fast-paced gameplay.

Technical Overview

- Engine: Godot 4.x
- Core scripts:
  - **main.gd**: Handles player and asteroid spawning
  - **player.gd**: Ship movement, aiming, hitscan shooting logic, shield system, and damage handling
  - **Projectile.gd** and **Projectile_visual.gd**: Visual-only projectile display for hitscan feedback
  - **rocket.gd**: Homing rocket weapon with target tracking and explosion mechanics
  - **asteroid.gd** and **asteroid_visuals.gd**: Asteroid physics, health system, splitting, and rendering
  - **mineral.gd**: Collectible mineral drops
  - **GameState.gd**: Autoload singleton managing minerals, credits, market prices, shield stats, and upgrades
  - **InventoryMenu.gd**: Updates mineral labels and UI
  - **shield_bar.gd**: Real-time shield display that responds to damage/regeneration signals
  - **floating_text_2d.gd**: Spawns floating feedback text for mineral collection
  - **game_over.gd**: Game over screen with restart functionality

All motion uses RigidBody2D or CharacterBody2D nodes with gravity and damping disabled to simulate zero-gravity space physics. The player uses CharacterBody2D for precise control, while asteroids use RigidBody2D for realistic physics interactions.

Design Goals

- Keep the gameplay simple and satisfying while allowing depth through upgrades.
- Maintain a clean, minimalist aesthetic with sharp contrast.
- Ensure the code is modular and easy to expand with new mineral types, upgrades, or weapons.
- Capture the mechanical precision and rhythm of classic Asteroids, but with a modern progression loop.

Example Gameplay Summary

The player's ship glides through space, twin hitscan cannons firing instantly at a cluster of tumbling asteroids. A large asteroid takes two hits before breaking apart with a particle burst, spawning smaller fragments and dropping mineral shards. "+1 Iron" floats upward as the player collects the minerals.

A smaller asteroid drifts too close and collides with the ship - the shield bar at the top shrinks as 20 damage is dealt, and the ship flashes red. The player carefully positions away from the asteroid field, waiting 3 seconds for shield regeneration to begin. The white shield bar slowly fills back up.

After accumulating resources, the player checks the market prices: Iron at 4 credits (random walk), Nickel at 6 credits (high demand), and Silica at 2 credits (sine wave low point). They sell their Nickel stockpile at peak price, watching the price drop from supply pressure. With the credits earned, they purchase the rocket weapon upgrade.

Back in space, a rocket launches from the ship, banking smoothly to track a distant asteroid. It homes in and explodes on impact, the blast radius damaging three nearby rocks simultaneously. The gameplay loop of mining, surviving, market timing, and upgrading continues as the player becomes increasingly powerful.
