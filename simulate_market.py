#!/usr/bin/env python3
"""Simulate the Asteroid Farmer market price system"""

import math
import random

class MarketSimulation:
    def __init__(self):
        self.market_prices = {"iron": 1, "nickel": 4, "silica": 4}
        self.market_cycle = 0.0
        self.nickel_recent_sales = 0.0
        self.NICKEL_SALES_DECAY_RATE = 0.15

    def update_market_prices(self):
        # Iron: Random walk with bounds (1-7 credits)
        iron_change = random.randint(-1, 1)  # -1, 0, or +1
        new_iron_price = self.market_prices["iron"] + iron_change
        self.market_prices["iron"] = max(1, min(7, new_iron_price))

        # Nickel: Supply and demand based on recent sales (1-7 credits)
        # Decay recent sales pressure over time
        self.nickel_recent_sales = max(0.0, self.nickel_recent_sales - self.NICKEL_SALES_DECAY_RATE)

        # Price decreases with recent sales
        sales_pressure = 1.0 - (self.nickel_recent_sales * 0.05)  # 5% reduction per unit
        sales_pressure = max(0.14, min(1.71, sales_pressure))
        base_price = 4
        self.market_prices["nickel"] = max(1, min(7, int(base_price * sales_pressure)))

        # Silica: Sine wave pattern (1-7 credits)
        self.market_cycle += 1.0
        wave = math.sin(self.market_cycle * 0.5) * 3.0
        center_price = 4
        self.market_prices["silica"] = max(1, min(7, int(center_price + wave)))

    def simulate(self, num_ticks, nickel_sale_at_tick=-1, nickel_sale_amount=0):
        print("\nTick | Iron | Nickel | Silica | Nickel Sales Pressure")
        print("-----|------|--------|--------|---------------------")

        for tick in range(num_ticks):
            # Simulate nickel sale if requested
            if tick == nickel_sale_at_tick and nickel_sale_amount > 0:
                self.nickel_recent_sales += nickel_sale_amount
                print(f">>> SELLING {nickel_sale_amount} NICKEL AT TICK {tick} <<<")

            self.update_market_prices()
            print(f"{tick+1:4d} | {self.market_prices['iron']:4d} | "
                  f"{self.market_prices['nickel']:6d} | "
                  f"{self.market_prices['silica']:6d} | "
                  f"{self.nickel_recent_sales:5.2f}")

if __name__ == "__main__":
    print("="*60)
    print("SCENARIO 1: Normal market fluctuation (30 ticks, no sales)")
    print("="*60)
    sim1 = MarketSimulation()
    sim1.simulate(30)

    print("\n" + "="*60)
    print("SCENARIO 2: Selling 10 nickel at tick 5")
    print("="*60)
    sim2 = MarketSimulation()
    sim2.simulate(30, 5, 10)

    print("\n" + "="*60)
    print("SCENARIO 3: Selling 20 nickel at tick 10")
    print("="*60)
    sim3 = MarketSimulation()
    sim3.simulate(30, 10, 20)
