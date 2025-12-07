#!/usr/bin/env python3
"""
POD Niche Validation Script
Version: 1.0.0
Last Updated: 2025-12-07
MCP Spec: 2.0
Author: LWF Designs

Deterministic niche validation logic for pod-research.
No LLM calls; outputs JSON with confidence-driven GO/SKIP decision.
"""
import argparse
import json
import sys
from typing import Dict, List, Optional, Tuple, Literal


# === Business Rule Thresholds ===
ETSY_THRESHOLDS: Dict[str, int] = {
    "green_light": 50_000,
    "red_flag": 100_000,
    "ideal_min": 5_000,
    "ideal_max": 30_000,
}

TREND_THRESHOLDS: Dict[str, int] = {
    "minimum": 40,
    "excellent": 60,
}

BRAND_KEYWORDS: Dict[str, List[str]] = {
    "touge": [
        "jdm", "drift", "touge", "ae86", "s13", "s14", "ek9", "dc2",
        "rx7", "gt86", "brz", "miata", "mx5", "silvia", "skyline",
        "supra", "nsx", "integra", "car", "auto", "racing", "track"
    ],
    "lwf": [
        "plant", "sustainable", "eco", "wellness", "mindful", "organic",
        "nature", "minimalist", "lifestyle", "health", "yoga", "meditation",
        "botanical", "green living"
    ]
}

SUB_NICHE_MODIFIERS: List[str] = [
    "beginner", "advanced", "eco-friendly", "affordable", "luxury", "DIY"
]


def calculate_brand_assignment(
    niche: str, hint: Optional[str], decision: str, warnings: List[str]
) -> Optional[str]:
    if decision != "GO":
        return None

    if hint in {"LWF", "Touge"}:
        return hint

    lower_niche = niche.lower()
    touge_matches = sum(1 for kw in BRAND_KEYWORDS["touge"] if kw in lower_niche)
    lwf_matches = sum(1 for kw in BRAND_KEYWORDS["lwf"] if kw in lower_niche)

    if touge_matches > lwf_matches:
        return "Touge"
    if lwf_matches > touge_matches:
        return "LWF"

    warnings.append("Brand ambiguous - defaulted to LWF")
    return "LWF"


def build_sub_niches(niche: str, decision: str) -> Optional[List[str]]:
    if decision != "GO":
        return None

    suggestions = []
    base = niche.strip()
    if len(base) <= 3:
        return None

    for mod in SUB_NICHE_MODIFIERS:
        suggestions.append(f"{base} + {mod}")

    return suggestions[:3]


def validate_niche(
    niche: str,
    etsy_count: int,
    trend_score: int,
    trend_direction: Literal["rising", "stable", "declining"] = "stable",
    brand_hint: Optional[str] = None,
) -> Dict[str, object]:
    reasoning: List[str] = []
    warnings: List[str] = []
    confidence = 0.5

    if etsy_count >= ETSY_THRESHOLDS["red_flag"]:
        return {
            "niche": niche,
            "decision": "SKIP",
            "confidence": 0.95,
            "etsy_count": etsy_count,
            "trend_score": trend_score,
            "trend_direction": trend_direction,
            "reasoning": [
                f"🔴 OVER-SATURATED: {etsy_count:,} listings exceeds 100K threshold"
            ],
            "brand_assignment": None,
            "sub_niches": None,
            "warnings": ["Market dominated by established sellers - very risky"],
        }

    if trend_direction == "declining" and trend_score < 30:
        return {
            "niche": niche,
            "decision": "SKIP",
            "confidence": 0.9,
            "etsy_count": etsy_count,
            "trend_score": trend_score,
            "trend_direction": trend_direction,
            "reasoning": [
                f"🔴 DECLINING TREND: Score {trend_score}/100 with downward trajectory"
            ],
            "brand_assignment": None,
            "sub_niches": None,
            "warnings": ["Avoid investing in declining niches"],
        }

    etsy_pass = etsy_count < ETSY_THRESHOLDS["green_light"]
    trend_pass = trend_score >= TREND_THRESHOLDS["minimum"]

    if etsy_pass:
        if ETSY_THRESHOLDS["ideal_min"] <= etsy_count <= ETSY_THRESHOLDS["ideal_max"]:
            reasoning.append(
                f"✅ Etsy: {etsy_count:,} listings (ideal range 5K-30K)"
            )
            confidence += 0.3
        elif etsy_count < ETSY_THRESHOLDS["ideal_min"]:
            reasoning.append(
                f"✅ Etsy: {etsy_count:,} listings (low competition - verify demand)"
            )
            warnings.append("Low competition may indicate weaker demand - validate sub-niche")
            confidence += 0.2
        else:
            reasoning.append(
                f"✅ Etsy: {etsy_count:,} listings (acceptable, near threshold)"
            )
            confidence += 0.25
    else:
        reasoning.append(
            f"❌ Etsy: {etsy_count:,} exceeds {ETSY_THRESHOLDS['green_light']:,} threshold"
        )

    if trend_pass:
        if trend_score >= TREND_THRESHOLDS["excellent"]:
            reasoning.append(
                f"🔥 Trends: {trend_score}/100 (excellent/stable to rising)"
            )
            confidence += 0.25
        else:
            reasoning.append(
                f"✅ Trends: {trend_score}/100 (stable)"
            )
            confidence += 0.15

        if trend_direction == "rising":
            reasoning.append("📈 Trend direction: rising (bonus confidence)")
            confidence += 0.05
    else:
        reasoning.append(
            f"❌ Trends: {trend_score}/100 below minimum {TREND_THRESHOLDS['minimum']}"
        )

    decision = "GO" if (etsy_pass and trend_pass) else "SKIP"
    confidence = round(min(0.95, max(0.1, confidence)), 2)

    brand_assignment = calculate_brand_assignment(niche, brand_hint, decision, warnings)
    sub_niches = build_sub_niches(niche, decision)

    return {
        "niche": niche,
        "decision": decision,
        "confidence": confidence,
        "etsy_count": etsy_count,
        "trend_score": trend_score,
        "trend_direction": trend_direction,
        "reasoning": reasoning or [],
        "brand_assignment": brand_assignment,
        "sub_niches": sub_niches,
        "warnings": warnings or None,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Deterministic POD niche validation.")
    parser.add_argument("niche", type=str, help="Niche name to validate.")
    parser.add_argument("etsy_count", type=int, help="Etsy listing count.")
    parser.add_argument("trend_score", type=int, help="Google Trends 12-month score (0-100).")
    parser.add_argument(
        "--trend-direction",
        choices=["rising", "stable", "declining"],
        default="stable",
        help="Trends direction indicator (default: stable).",
    )
    parser.add_argument(
        "--brand-hint",
        choices=["LWF", "Touge"],
        help="Optional brand assignment hint.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = validate_niche(
        niche=args.niche,
        etsy_count=args.etsy_count,
        trend_score=args.trend_score,
        trend_direction=args.trend_direction,
        brand_hint=args.brand_hint,
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
