#!/usr/bin/env python3
"""
POD Listing SEO Validator
Version: 1.0.0
Last Updated: 2025-12-07
MCP Spec: 2.0
Author: LWF Designs

SEO compliance checker for pod-listing-seo skill.
"""
import argparse
import json
from pathlib import Path
from typing import Dict, List, Optional, cast


REQUIREMENTS: Dict[str, int] = {
    "title_max": 140,
    "description_min": 300,
    "description_keyword_window": 160,
    "tag_count": 13,
}


def validate_title(title: str, primary_keyword: str) -> List[str]:
    warnings = []
    if len(title) > REQUIREMENTS["title_max"]:
        warnings.append(f"Title exceeds {REQUIREMENTS['title_max']} characters ({len(title)}).")
    if primary_keyword.lower() not in title.lower().split():
        warnings.append("Primary keyword not front-loaded in title.")
    return warnings


def validate_tags(tags: List[str]) -> List[str]:
    warnings = []
    unique_tags = set(tags)
    if len(tags) != REQUIREMENTS["tag_count"]:
        warnings.append(f"Expected {REQUIREMENTS['tag_count']} tags, found {len(tags)}.")
    if len(unique_tags) != len(tags):
        warnings.append("Duplicate tags detected.")
    if any(len(tag) == 0 for tag in tags):
        warnings.append("Empty tag detected.")
    return warnings


def validate_description(description: str, keywords: List[str]) -> List[str]:
    warnings = []
    if len(description.split()) < REQUIREMENTS["description_min"]:
        warnings.append(f"Description under {REQUIREMENTS['description_min']} words.")
    snippet = description[:REQUIREMENTS["description_keyword_window"]]
    if not any(keyword.lower() in snippet.lower() for keyword in keywords):
        warnings.append(
            f"No primary keywords found within first {REQUIREMENTS['description_keyword_window']} characters."
        )
    return warnings


def calculate_seo_score(warnings: List[str]) -> float:
    base = 1.0
    deduction = 0.15 * len(warnings)
    return max(0.0, round(base - deduction, 2))


def validate_listing(
    title: str,
    tags: List[str],
    description: str,
    primary_keyword: str,
    keywords: Optional[List[str]] = None,
) -> Dict[str, object]:
    warnings = []
    warnings += validate_title(title, primary_keyword)
    warnings += validate_tags(tags)
    keywords = keywords or [primary_keyword]
    warnings += validate_description(description, keywords)

    return {
        "title_length": len(title),
        "tag_count": len(tags),
        "description_length_words": len(description.split()),
        "seo_score": calculate_seo_score(warnings),
        "warnings": warnings or None,
    }


def load_listing(json_path: Path) -> Dict[str, object]:
    with json_path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def parse_args() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate Etsy listing SEO compliance.")
    parser.add_argument("filepath", type=Path, help="JSON file containing listing draft.")
    return parser


def main() -> None:
    parser = parse_args()
    listing = load_listing(parser.parse_args().filepath)
    listing_data = cast(Dict[str, object], listing.get("listing", {}))
    primary_keyword = cast(str, listing_data.get("primary_keyword", ""))
    keywords = cast(List[str], listing_data.get("keywords", [primary_keyword]))
    result = validate_listing(
        title=cast(str, listing_data.get("title", "")),
        tags=cast(List[str], listing_data.get("tags", [])),
        description=cast(str, listing_data.get("description", "")),
        primary_keyword=primary_keyword,
        keywords=keywords,
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
