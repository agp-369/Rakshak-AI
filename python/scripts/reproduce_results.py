"""Reproduce Gemma-SOS benchmark results.

Usage:
    python scripts/reproduce_results.py          # Run full benchmark suite
    python scripts/reproduce_results.py --quick  # Quick smoke test

This script reproduces the numbers reported in the Kaggle writeup.
"""
import argparse
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scripts.benchmark import main as run_benchmark


def run_quick_check():
    """Quick smoke test to verify the system works."""
    from agent.tools.sensors import get_gps_location
    from agent.tools.maps import query_offline_map
    from agent.retrieval.local_retriever import search_local_protocols
    from agent.orchestrator import DisasterResponseOrchestrator

    # Test tools
    print("[*] Testing GPS sensor...")
    gps = get_gps_location()
    assert "latitude" in gps, "GPS should return coordinates"
    print(f"  [+] GPS: {gps}")

    print("[*] Testing offline map query...")
    maps = query_offline_map("San Francisco", "shelter")
    assert "shelter" in maps, "Map should find shelter"
    print(f"  [+] Maps: {maps[:80]}...")

    print("[*] Testing protocol retrieval...")
    protocol = search_local_protocols("bleeding")
    assert "pressure" in protocol, "Protocol should discuss pressure"
    print(f"  [+] Protocol: {protocol[:80]}...")

    print("\n[+] All smoke tests passed!")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reproduce Gemma-SOS results")
    parser.add_argument(
        "--quick", action="store_true", help="Run quick smoke test only"
    )
    args = parser.parse_args()

    if args.quick:
        run_quick_check()
    else:
        run_benchmark()
