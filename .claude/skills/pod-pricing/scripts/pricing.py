#!/usr/bin/env python3
"""
Deterministic pricing calculator for pod-pricing skill.
"""
import argparse
import json
import math
from typing import Dict, List, Optional


PRICING_RULES: Dict[str, float] = {
    "etsy_fee_percent": 0.225,
    "target_margin_min": 0.25,
    "target_margin_ideal": 0.35,
    "target_margin_max": 0.50,
}

BASE_COSTS: Dict[str, float] = {
    "tee_standard": 12.50,
    "tee_premium": 16.00,
    "hoodie": 28.00,
    "mug": 8.50,
    "poster_12x18": 12.00,
    "poster_18x24": 18.00,
    "sticker_3x3": 2.50,
}


def apply_pricing_formula(cost: float, margin: float) -> float:
    after_fees = 1 - PRICING_RULES["etsy_fee_percent"]
    after_margin = 1 - margin
    price = cost / (after_fees * after_margin)
    return math.floor(price * 100 - 1) / 100 + 0.99


def analyze_competitors(price: float, competitor_prices: Optional[List[float]]) -> List[str]:
    warnings = []
    if not competitor_prices:
        return warnings

    avg = sum(competitor_prices) / len(competitor_prices)
    if price > avg * 1.2:
        warnings.append(f"Price ${price:.2f} is >20% above competitor avg ${avg:.2f}.")
    elif price < avg * 0.8:
        warnings.append(f"Price ${price:.2f} is >20% below competitor avg ${avg:.2f} (low-quality signal).")
    return warnings


def calculate_price(
    product_type: str,
    custom_cost: Optional[float] = None,
    target_margin: Optional[float] = None,
    competitor_prices: Optional[List[float]] = None,
) -> Dict[str, object]:
    base_cost = custom_cost if custom_cost is not None else BASE_COSTS.get(product_type)
    if base_cost is None:
        raise ValueError(f"Unknown product type: {product_type}")

    margin = target_margin if target_margin is not None else PRICING_RULES["target_margin_ideal"]
    warnings = []
    if margin < PRICING_RULES["target_margin_min"]:
        warnings.append(
            f"Margin {margin*100:.0f}% below minimum {PRICING_RULES['target_margin_min']*100:.0f}%."
        )
    if margin > PRICING_RULES["target_margin_max"]:
        warnings.append(
            f"Margin {margin*100:.0f}% exceeds premium cap {PRICING_RULES['target_margin_max']*100:.0f}%."
        )

    recommended_price = apply_pricing_formula(base_cost, margin)
    breakdown = {
        "cost": round(base_cost, 2),
        "etsy_fees": round(recommended_price * PRICING_RULES["etsy_fee_percent"], 2),
        "profit": round(recommended_price - base_cost - round(recommended_price * PRICING_RULES["etsy_fee_percent"], 2), 2),
    }
    actual_margin = breakdown["profit"] / recommended_price if recommended_price else 0

    price_range = {
        "min": round(apply_pricing_formula(base_cost, PRICING_RULES["target_margin_min"]) - 0.01, 2),
        "max": round(apply_pricing_formula(base_cost, PRICING_RULES["target_margin_max"]) - 0.01, 2),
    }

    warnings += analyze_competitors(recommended_price, competitor_prices)

    return {
        "product_type": product_type,
        "base_cost": base_cost,
        "recommended_price": round(recommended_price, 2),
        "price_range": price_range,
        "margin_achieved": round(actual_margin, 3),
        "breakdown": breakdown,
        "warnings": warnings or None,
    }


def parse_args() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Deterministic POD pricing calculator.")
    parser.add_argument("product_type", type=str, help="Product type key.")
    parser.add_argument("--custom-cost", type=float, help="Override base cost.")
    parser.add_argument("--target-margin", type=float, help="Desired margin (0-1).")
    parser.add_argument(
        "--competitors",
        type=float,
        nargs="*",
        help="Competitor prices for comparison.",
    )
    return parser


def main() -> None:
    parser = parse_args()
    args = parser.parse_args()
    result = calculate_price(
        product_type=args.product_type,
        custom_cost=args.custom_cost,
        target_margin=args.target_margin,
        competitor_prices=args.competitors,
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()