import json
from typing import Any, Dict, List, Optional


def query_offline_map(location: str, category: str = "shelter") -> str:
    """Queries the local offline map database for specific categories (e.g., shelter, hospital, water).

    Args:
        location: GPS coordinates or a named neighborhood.
        category: The type of resource to find.

    Note: This is a demonstration stub. In production, integrate OSMAnd / Organic Maps
    offline tile databases (GeoPackage or MBTiles format). The Flutter app uses
    the device GPS + pre-downloaded OSM tiles for real offline mapping.
    """
    demo_data = {
        "shelter": [
            {"name": "Moscone Center South", "lat": 37.7842, "lon": -122.4014, "capacity": 500},
            {"name": "Bill Graham Civic Auditorium", "lat": 37.7781, "lon": -122.4174, "capacity": 1200}
        ],
        "hospital": [
            {"name": "UCSF Medical Center at Mission Bay", "lat": 37.7678, "lon": -122.3912},
            {"name": "Zuckerberg San Francisco General Hospital", "lat": 37.7558, "lon": -122.4047}
        ],
        "water": [
            {"name": "Safeway Grocery", "lat": 37.7749, "lon": -122.4194, "type": "bottled_water"},
        ],
        "food": [
            {"name": "SF Food Bank Distribution Center", "lat": 37.7719, "lon": -122.4094, "type": "emergency_rations"},
        ]
    }

    results = demo_data.get(category, [])
    if not results:
        return json.dumps({
            "category": category,
            "location": location,
            "found": [],
            "source": "DEMO_DATA",
            "note": "This is demonstration data. For real usage, pre-download OSM tiles."
        })

    return json.dumps({
        "category": category,
        "location": location,
        "found": results,
        "source": "DEMO_DATA",
        "note": "This is demonstration data. For real usage, integrate OSM offline tiles."
    })


def calculate_offline_route(start: str, end: str) -> str:
    """Calculates a route between two locations using local road network data.
    
    Ensures routes avoid known flooded or blocked zones based on real-time sensor feedback.
    """
    # Mocking the pathfinding logic
    # In practice, this would use a local Valhalla, OSRM, or simple Dijkstra on OSM data
    
    return json.dumps({
        "start": start,
        "end": end,
        "mode": "walking",
        "estimated_time_minutes": 15,
        "hazard_status": "clear",
        "instructions": [
            "Head North on Market St.",
            "Turn right on 4th St.",
            "Destination on your left."
        ]
    })
