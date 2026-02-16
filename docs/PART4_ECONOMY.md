# Asteroid Farmer - Part 4: Economy & Market System

> Part 4 of 7. See the [Table of Contents](./README.md) for all parts.

---

## Overview

The economy is built on four pillars:

1. **Mineral Market** — Dynamic pricing with 4 distinct models
2. **Banking** — Vault storage with compound interest
3. **Bonds** — Fixed-term investments with guaranteed returns
4. **Fuel Futures** — Speculative contracts on fuel price movement

All pricing logic lives in `Scripts/Market.gd`. All financial state lives in `Scripts/game_state.gd`.

---

## Mineral Types

### Standard Minerals (from asteroids and voyages)

| Mineral | Enum | Base Price | Pricing Model | Price Range |
|---------|------|-----------|---------------|-------------|
| Iron | `MineralType.IRON` | 1 | Random Walk | 1-7 |
| Nickel | `MineralType.NICKEL` | 2 | Supply/Demand | 1-7 |
| Silica | `MineralType.SILICA` | 3 | Sine Wave | 1-7 |
| Platinum | `MineralType.PLATINUM` | 5 | Boom & Bust | 2-10 |

### Exotic Minerals (from expeditions only)

| Mineral | Enum | Used For |
|---------|------|----------|
| Cobalt | `ExoticMineralType.COBALT` | Drone Armor upgrades |
| Titanium | `ExoticMineralType.TITANIUM` | Mineral Scanner upgrades |
| Xenocryst | `ExoticMineralType.XENOCRYST` | Warp Drive upgrades |
| Iridium | `ExoticMineralType.IRIDIUM` | Deep Probes upgrades |

Exotic minerals are **not sold for credits**. They are exclusively spent on drone upgrades.

---

## Pricing Models

Prices update every **3 seconds** (configurable via `Market.update_interval`). After each update, the new price is appended to history (max 10 entries) and `prices_changed` is emitted.

### Iron — Random Walk

The simplest model. Each tick, the price moves -1, 0, or +1 randomly.

```gdscript
var change := randi() % 3 - 1  # -1, 0, or +1
market_prices[IRON] = clampi(price + change, 1, 7)
```

**Behavior**: Unpredictable, no trend. Iron is the baseline commodity. The player cannot influence iron prices.

### Nickel — Supply & Demand with Appreciation

A reactive model that punishes bulk selling and rewards patience.

**Mechanics**:
- `_nickel_recent_sales`: Tracks recent sale volume, decays at 0.15 per tick
- `_nickel_appreciation`: Accumulates at 0.2 per tick when sales < 1.0, max 3.0
- Selling resets appreciation to 0

**Formula**:
```
base_price = 4
appreciation_bonus = floor(_nickel_appreciation)
sales_impact = floor(_nickel_recent_sales * 0.05 * base_price)
price = clamp(base_price + appreciation_bonus - sales_impact, 1, 7)
```

**Strategy**: Hold nickel and wait for appreciation to build. Selling dumps the price and resets the bonus. Sell in small batches if possible.

### Silica — Sine Wave

A completely predictable cyclical pattern.

```gdscript
_market_cycle += 1
var wave := sin(_market_cycle * 0.5) * 3
price = clampi(4 + int(wave), 1, 7)
```

**Behavior**: Price oscillates between 1 and 7 in a regular sine pattern. One full cycle takes approximately 12-13 ticks (36-39 seconds).

**Strategy**: Time sales to the peak of the wave. The graphs panel visualizes this pattern clearly.

### Platinum — Boom & Bust

Price slowly climbs until a random crash.

**Mechanics**:
- `_platinum_pressure`: Increases by `randf_range(0.1, 0.4)` each tick
- Bust chance: `pressure * 0.03` — increases as pressure builds
- On bust: pressure resets to 0, price crashes

**Formula**:
```
bonus = floor(_platinum_pressure)
price = clamp(5 + bonus, 2, 10)
```

**Strategy**: Platinum starts at 5 and climbs. The longer you wait, the higher the payout — but also the higher the crash risk. Sell before the bust.

### Fuel — Mean-Reverting with Spikes

Fuel is not a mineral the player collects. It's used for the **Fuel Futures** financial system.

**Constants**:
| Constant | Value |
|----------|-------|
| Base price | 50 |
| Min price | 15 |
| Max price | 95 |
| Mean reversion | 0.08 |
| Volatility | 4.0 |
| Spike chance | 12% per tick |
| Spike magnitude | 12.0 |

**Formula**:
```
reversion = (50 - current_price) * 0.08
noise = randf_range(-4.0, 4.0)
if randf() < 0.12:
    noise += randf_range(-12.0, 12.0)
price += reversion + noise  (accumulated as float, applied as int)
price = clamp(price, 15, 95)
```

**Behavior**: Gravitates toward 50 but with high volatility and occasional sharp spikes.

---

## Price History & Graphs

The game visualizes market data through line graphs rendered entirely via Godot's `_draw()` API — no chart libraries, no textures.

### Two Variants

| Script | Class | Style |
|--------|-------|-------|
| `MineralPriceGraph.gd` | (none) | Colored lines (cyan default), dark background, dots at each data point |
| `MineralPriceGraph.B&W.gd` | `PriceGraph` | White lines on black background, no dots — matches the game's monochrome aesthetic |

The **B&W variant** (`PriceGraph`) is the one used in-game. It uses the DM Mono font for titles, disables the grid by default, and sets `point_radius` to 0 for clean lines only.

### How They Work

Each graph instance tracks **one mineral type** via its `@export var mineral_type` property. On `_ready()`, the graph connects to `Market.prices_changed` and caches the last 10 prices from `Market.get_price_history(mineral_type)`. Every time the market ticks (every 3 seconds), the graph receives the signal, updates its cache, and calls `queue_redraw()`.

### Drawing Process

The `_draw()` method renders three layers:

1. **Background** — Black filled rectangle (`Color(0, 0, 0, 0.8)`)
2. **Labels** — Mineral name + " Price History" as title, `$0`-`$8` on the Y-axis, "Time ->" on the X-axis
3. **Price line** — Points are spread evenly across the graph width. Each consecutive pair is connected by a `draw_line()` call. Y position is calculated as `price / max_price * graph_height`.

Optional grid lines (horizontal for price levels, vertical for time points) can be enabled via `show_grid`.

### Configurable Properties

| Property | Default (B&W) | Description |
|----------|--------------|-------------|
| `mineral_type` | `IRON` | Which mineral to track |
| `line_color` | `Color.WHITE` | Line and point color |
| `line_width` | 2.0 | Thickness of connecting lines |
| `point_radius` | 0.0 | Radius of dots at data points (0 = no dots) |
| `background_color` | `Color(0, 0, 0, 0.8)` | Graph background |
| `grid_color` | `Color(0.3, 0.3, 0.4, 0.5)` | Grid line color |
| `text_color` | `Color.WHITE` | Label text color |
| `show_grid` | false | Toggle grid lines |
| `show_labels` | true | Toggle title and axis labels |
| `max_price` | 8 | Y-axis ceiling |
| `margin_left/right/top/bottom` | 40/20/30/30 | Graph area padding for labels |

### Panel Container

The graphs live inside `graphs_panel.gd` (`Scenes/graphs_panel_ui.tscn`), a `PanelContainer` that occupies the bottom 27.78% of the screen. It slides in from the left when TAB is pressed and slides back out on the next TAB. One graph instance per mineral type is placed side by side within the panel.

---

## Banking System

The bank is accessed from the **base scene** (via `bank.tscn`).

### Vault

Players deposit credits into the vault for safekeeping and earn compound interest.

**How interest works**:
- Every `compound_speed` seconds (default 30s), interest is calculated
- Interest = `floor(balance * interest_rate)`
- Interest is added to balance (capped at vault capacity)
- Transaction is logged

### Vault Upgrades

| Upgrade | Lv0 | Lv1 | Lv2 | Lv3 | Cost to Next |
|---------|-----|-----|-----|-----|-------------|
| Vault Capacity | 500 | 2,000 | 5,000 | 15,000 | 0/200/500/1500 |
| Interest Rate | 1% | 2% | 3% | 5% | 0/300/800/2000 |
| Compound Speed | 30s | 20s | 15s | 10s | 0/250/600/1800 |

### Key Functions

| Function | Purpose |
|----------|---------|
| `bank_deposit(amount)` | Move credits to vault (capped at capacity) |
| `bank_withdraw(amount)` | Move credits from vault to wallet |
| `get_bank_capacity()` | Current max vault size |
| `get_bank_interest_rate()` | Current interest rate |
| `get_bank_compound_interval()` | Seconds between interest calculations |
| `buy_bank_upgrade(name)` | Purchase vault/interest/speed upgrade |

### Transaction History

The last 20 transactions are stored in `bank_transaction_history`. Each entry:
```gdscript
{ "type": "deposit"|"withdraw"|"interest"|"upgrade"|"bond_buy"|"bond_mature"|"future_buy"|"future_settle",
  "amount": int,
  "balance": int }
```

---

## Bond System

Bonds are fixed-term investments. You lock credits for a set duration and receive a guaranteed payout.

### Bond Tiers

| Tier | Duration | Return Rate | Min Investment | Payout Example |
|------|----------|------------|----------------|---------------|
| Short | 60s | 8% | 50 cr | 50 -> 54 |
| Medium | 180s | 20% | 150 cr | 150 -> 180 |
| Long | 360s | 40% | 300 cr | 300 -> 420 |

### How Bonds Work

1. Player calls `buy_bond("short")` — costs `min_investment` credits
2. Bond is added to `bank_bonds` array with elapsed = 0
3. Every frame, `_bond_tick(delta)` increments elapsed time
4. When `elapsed >= duration`, the bond matures:
   - Payout is `ceil(principal * (1 + rate))`
   - Credits are added to wallet
   - Bond is removed from array
   - `bank_bond_changed` signal emits

**Risk**: None. Bonds always pay out. The only cost is opportunity — your credits are locked.

---

## Fuel Futures System

Fuel futures are **speculative contracts** that bet on fuel price movement. Unlike bonds, **you can lose money**.

### Futures Tiers

| Tier | Duration | Leverage | Cost |
|------|----------|---------|------|
| Spot | 30s | 1.0x | 25 cr |
| Standard | 90s | 2.0x | 75 cr |
| Volatile | 180s | 3.0x | 150 cr |

**Max simultaneous contracts**: 6

### How Futures Work

1. Player calls `buy_fuel_future("standard", true)` — `true` for long (betting price goes up), `false` for short (betting price goes down)
2. The **strike price** is recorded as the current fuel price at time of purchase
3. Every frame, `_fuel_futures_tick(delta)` increments elapsed time
4. When `elapsed >= duration`, the contract settles:

**Settlement formula**:
```gdscript
# For long positions (betting price goes up):
price_change = (settle_price - strike_price) / strike_price

# For short positions (betting price goes down):
price_change = (strike_price - settle_price) / strike_price

payout = floor(cost * (1.0 + price_change * leverage))
payout = max(payout, 0)  # Can lose entire investment, never goes negative
```

**Example**: Buy a Standard long at strike=50, fuel settles at 60:
```
price_change = (60 - 50) / 50 = 0.20
payout = 75 * (1.0 + 0.20 * 2.0) = 75 * 1.40 = 105 credits
Profit: 30 credits
```

**Example**: Same contract but fuel drops to 40:
```
price_change = (40 - 50) / 50 = -0.20
payout = 75 * (1.0 + (-0.20) * 2.0) = 75 * 0.60 = 45 credits
Loss: 30 credits
```

### Strategy

- **Long contracts**: Buy when fuel is below 50 (mean reversion will pull it up)
- **Short contracts**: Buy when fuel is above 50 (mean reversion will pull it down)
- **Volatile tier**: Highest risk/reward — 3x leverage amplifies both gains and losses
- Watch for **spike events** (12% chance per tick) that can swing prices 12+ points

---

## Selling Minerals

When the player sells (via the upgrade panel's "SELL ALL" button):

```gdscript
func sell_all() -> void:
    for each mineral type:
        total += price * count
        if nickel: Market.record_nickel_sale(count)  # affects nickel pricing
        minerals[type] = 0
    add_credits(total)
    emit inventory_changed
    clear encumbrance if was encumbered
```

**Key detail**: Selling nickel triggers `record_nickel_sale()` which:
- Adds the sold amount to `_nickel_recent_sales`
- Resets `_nickel_appreciation` to 0
- This causes nickel price to drop and prevents appreciation until sales pressure decays

---

## Cargo & Encumbrance

| Property | Default | Max (Upgraded) |
|----------|---------|---------------|
| Cargo Capacity | 40 | 170 |

When total minerals exceed cargo capacity:
- `is_over_encumbered()` returns true
- `get_speed_multiplier()` returns `capacity / total` (min 0.25)
- Player movement speed is reduced proportionally
- Cargo label turns red and shows speed percentage
- `over_encumbered` signal fires

This creates a strategic tension: stay and keep mining (but move slower and be more vulnerable) or sell and reset.

---

*Previous: [Part 3 - Weapons](./PART3_WEAPONS.md)*
*Next: [Part 5 - Upgrade System](./PART5_UPGRADES.md)*
