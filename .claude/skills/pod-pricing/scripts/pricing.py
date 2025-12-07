#!/usr/bin/env python3
"""
Deterministic POD pricing calculator for Etsy.
Calculates recommended prices with fee structure and margin targets.

Business Logic Source: CLAUDE_CODE_2.0_POD_BUSINESS_SETUP_GUIDE.md
- Etsy fee structure: 22.5% total (lines 338-345, 1429-1435)
- Product base costs (lines 1380-1384, 1437-1448)
- Margin targets: 25% min, 35% ideal, 50% max (lines 1450-1453)
"""

import sys
import json
import math
from typing import Dict

# Etsy fee structure (per business guide)
ETSY_FEES = {
    "listing": 0.20,           # $0.20 per listing (flat fee, not percentage)
    "transaction": 0.065,      # 6.5%
    "payment": 0.03,           # 3% + $0.25
    "payment_fixed": 0.25,     # $0.25 per transaction
    "offsite_ads": 0.15,       # 15% (worst case for shops under $10K)
    "total_percent": 0.225     # 22.5% total percentage fees
}

# Base product costs (industry standard POD pricing)
PRODUCT_COSTS = {
    "t-shirt": 12.00,
    "hoodie": 25.00,
    "mug": 8.00,
    "poster": 10.00,
    "sticker": 3.00,
    "tote-bag": 15.00
}

# Recommended markup multipliers
MARKUP_MULTIPLIERS = {
    "t-shirt": 2.0,
    "hoodie": 1.8,
    "mug": 2.5,
    "poster": 2.2,
    "sticker": 3.0,
    "tote-bag": 2.0
}

# Minimum profit margins
MIN_MARGINS = {
    "t-shirt": 0.40,
    "hoodie": 0.35,
    "mug": 0.50,
    "poster": 0.45,
    "sticker": 0.60,
    "tote-bag": 0.40
}


def calculate_price(product_type: str) -> Dict:
    """
    Calculate recommended price for a POD product.
    
    Args:
        product_type: One of the supported product types
    
    Returns:
        Dictionary with pricing breakdown
    
    Formula:
        recommended_price = base_cost * markup_multiplier
        minimum_price = base_cost / (1 - min_margin - fee_percent)
        platform_fees_estimate = recommended_price * fee_percent
        profit = recommended_price - base_cost - platform_fees
    """
    
    # Validate product type
    if product_type not in PRODUCT_COSTS:
        valid_types = list(PRODUCT_COSTS.keys())
        return {
            "error": f"Invalid product_type: '{product_type}'",
            "valid_options": valid_types,
            "example": f"python pricing.py '{{\"product_type\": \"{valid_types[0]}\"}}'"
        }
    
    # Get base values
    base_cost = PRODUCT_COSTS[product_type]
    markup = MARKUP_MULTIPLIERS[product_type]
    min_margin = MIN_MARGINS[product_type]
    
    # Calculate recommended price
    recommended_price = base_cost * markup
    
    # Calculate minimum price (to maintain minimum margin)
    # Formula: price = cost / (1 - margin - fees)
    minimum_price = base_cost / (1 - min_margin - ETSY_FEES["total_percent"])
    
    # Round to .99 pricing
    recommended_price = math.floor(recommended_price) + 0.99
    minimum_price = math.floor(minimum_price) + 0.99
    
    # Calculate fee breakdown at recommended price
    platform_fees_estimate = recommended_price * ETSY_FEES["total_percent"]
    production_cost = base_cost
    profit_at_recommended = recommended_price - production_cost - platform_fees_estimate
    
    # Calculate actual margin percentage
    profit_margin_percent = (profit_at_recommended / recommended_price) * 100
    
    return {
        "product_type": product_type,
        "base_cost": round(base_cost, 2),
        "recommended_price": round(recommended_price, 2),
        "minimum_price": round(minimum_price, 2),
        "profit_margin_percent": round(profit_margin_percent, 1),
        "cost_breakdown": {
            "production": round(production_cost, 2),
            "platform_fees_estimate": round(platform_fees_estimate, 2),
            "profit_at_recommended": round(profit_at_recommended, 2)
        }
    }


if __name__ == "__main__":
    # Accept JSON input from command line
    if len(sys.argv) != 2:
        print(json.dumps({
            "error": "Usage: python pricing.py '{\"product_type\": \"t-shirt\"}'",
            "valid_options": list(PRODUCT_COSTS.keys())
        }))
        sys.exit(1)
    
    try:
        input_data = json.loads(sys.argv[1])
        
        # Validate required field
        if "product_type" not in input_data:
            print(json.dumps({
                "error": "Missing required field: product_type",
                "valid_options": list(PRODUCT_COSTS.keys())
            }))
            sys.exit(1)
        
        # Run pricing calculation
        result = calculate_price(input_data["product_type"])
        print(json.dumps(result, indent=2))
        
        # Exit with error code if invalid product type
        if "error" in result:
            sys.exit(1)
        
    except json.JSONDecodeError as e:
        print(json.dumps({
            "error": f"Invalid JSON input: {str(e)}",
            "example": "python pricing.py '{\"product_type\": \"t-shirt\"}'"
        }))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({
            "error": f"Unexpected error: {str(e)}"
        }))
        sys.exit(1)
