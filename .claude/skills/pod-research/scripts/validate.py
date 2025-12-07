#!/usr/bin/env python3
"""
Deterministic POD niche validation logic.
Returns JSON with valid/invalid decision, confidence score, reasoning.

Business Logic Source: CLAUDE_CODE_2.0_POD_BUSINESS_SETUP_GUIDE.md
- Etsy competition thresholds (lines 1008-1026)
- Trend score requirements (lines 1028-1042)
- Brand assignment keywords (lines 1079-1103)
"""

import sys
import json
from typing import Dict, List

def validate_niche(niche: str, etsy_count: int, trend_score: float) -> Dict:
    """
    Validate POD niche using industry-standard thresholds.
    
    Args:
        niche: The niche name to validate
        etsy_count: Number of active Etsy listings
        trend_score: Google Trends normalized score (0.0-1.0)
    
    Returns:
        Dictionary with validation results
    
    Business Rules:
        - Etsy count < 1000: Low competition, high opportunity if trend > 0.3
        - Etsy count 1000-10000: Moderate competition, proceed if trend > 0.5
        - Etsy count > 10000: High competition, only proceed if trend > 0.7
        - Trend score < 0.2: Declining/dead market (reject)
        - Trend score 0.2-0.5: Stable market (caution)
        - Trend score > 0.5: Growing market (proceed with appropriate competition)
    """
    
    valid = False
    confidence = "low"
    concerns = []
    recommendation = "reject"
    reasoning_parts = []
    
    # Validate input ranges
    if etsy_count < 0:
        concerns.append("Invalid Etsy count (negative value)")
    if not 0.0 <= trend_score <= 1.0:
        concerns.append("Trend score must be between 0.0 and 1.0")
    
    if concerns:
        return {
            "valid": False,
            "confidence": "low",
            "concerns": concerns,
            "recommendation": "reject",
            "reasoning": "Input validation failed"
        }
    
    # Analyze Etsy competition
    if etsy_count < 1000:
        if trend_score > 0.3:
            reasoning_parts.append(f"Low competition ({etsy_count} listings) with decent trend ({trend_score:.1%})")
            competition_score = 3  # Best case
        else:
            reasoning_parts.append(f"Low competition ({etsy_count} listings) but weak trend ({trend_score:.1%})")
            concerns.append("Low competition may indicate insufficient demand")
            competition_score = 1
    elif 1000 <= etsy_count <= 10000:
        if trend_score > 0.5:
            reasoning_parts.append(f"Moderate competition ({etsy_count} listings) with strong trend ({trend_score:.1%})")
            competition_score = 3
        else:
            reasoning_parts.append(f"Moderate competition ({etsy_count} listings) with moderate trend ({trend_score:.1%})")
            competition_score = 2
    else:  # > 10000
        if trend_score > 0.7:
            reasoning_parts.append(f"High competition ({etsy_count} listings) but very strong trend ({trend_score:.1%})")
            concerns.append("High competition requires unique angle to succeed")
            competition_score = 2
        else:
            reasoning_parts.append(f"High competition ({etsy_count} listings) with insufficient trend ({trend_score:.1%})")
            concerns.append("Oversaturated market")
            competition_score = 0
    
    # Analyze trend strength
    if trend_score < 0.2:
        reasoning_parts.append("Declining/dead market - insufficient interest")
        concerns.append("Trend score indicates dying market")
        trend_score_value = 0
    elif 0.2 <= trend_score < 0.5:
        reasoning_parts.append("Stable but not growing market")
        trend_score_value = 1
    else:  # >= 0.5
        reasoning_parts.append("Growing market with strong interest")
        trend_score_value = 2
    
    # Calculate final recommendation
    total_score = competition_score + trend_score_value
    
    if total_score >= 4:
        valid = True
        confidence = "high"
        recommendation = "proceed"
        reasoning = f"Strong opportunity: {'; '.join(reasoning_parts)}"
    elif total_score == 3:
        valid = True
        confidence = "medium"
        recommendation = "caution"
        reasoning = f"Viable with caution: {'; '.join(reasoning_parts)}"
    elif total_score == 2:
        valid = False
        confidence = "medium"
        recommendation = "caution"
        reasoning = f"Borderline case: {'; '.join(reasoning_parts)}"
        concerns.append("Consider additional research before proceeding")
    else:
        valid = False
        confidence = "high"
        recommendation = "reject"
        reasoning = f"Poor opportunity: {'; '.join(reasoning_parts)}"
    
    return {
        "valid": valid,
        "confidence": confidence,
        "concerns": concerns,
        "recommendation": recommendation,
        "reasoning": reasoning
    }


if __name__ == "__main__":
    # Accept JSON input from command line
    if len(sys.argv) != 2:
        print(json.dumps({
            "error": "Usage: python validate.py '{\"niche\": \"...\", \"etsy_count\": ..., \"trend_score\": ...}'",
            "valid": False
        }))
        sys.exit(1)
    
    try:
        input_data = json.loads(sys.argv[1])
        
        # Validate required fields
        required_fields = ["niche", "etsy_count", "trend_score"]
        missing_fields = [field for field in required_fields if field not in input_data]
        
        if missing_fields:
            print(json.dumps({
                "error": f"Missing required fields: {', '.join(missing_fields)}",
                "valid": False
            }))
            sys.exit(1)
        
        # Extract and validate data types
        niche = str(input_data["niche"])
        
        try:
            etsy_count = int(input_data["etsy_count"])
        except (ValueError, TypeError):
            print(json.dumps({
                "error": "etsy_count must be an integer",
                "valid": False
            }))
            sys.exit(1)
        
        try:
            trend_score = float(input_data["trend_score"])
        except (ValueError, TypeError):
            print(json.dumps({
                "error": "trend_score must be a number between 0.0 and 1.0",
                "valid": False
            }))
            sys.exit(1)
        
        # Run validation
        result = validate_niche(niche, etsy_count, trend_score)
        print(json.dumps(result, indent=2))
        
    except json.JSONDecodeError as e:
        print(json.dumps({
            "error": f"Invalid JSON input: {str(e)}",
            "valid": False
        }))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({
            "error": f"Unexpected error: {str(e)}",
            "valid": False
        }))
        sys.exit(1)
