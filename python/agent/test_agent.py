import unittest
from unittest.mock import MagicMock
import json
import os
import sys

# Ensure the parent directory is in the path for imports to work
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from agent.llm_interface import LLMInterface
from agent.orchestrator import DisasterResponseOrchestrator
from agent.tools.sensors import get_gps_location
from agent.tools.maps import query_offline_map
from agent.retrieval.local_retriever import LocalRetriever


class MockLLM(LLMInterface):
    def __init__(self):
        self.tools = []
        self.mock_response = "I will check your location."
        self.mock_tool_calls = None

    def generate(self, prompt, system_instruction=None):
        return self.mock_response

    def register_tool(self, tool_fn):
        self.tools.append(tool_fn.__name__)

    def call_tools(self, message):
        return self.mock_tool_calls


class TestDisasterResponseAgent(unittest.TestCase):
    def setUp(self):
        self.mock_llm = MockLLM()
        self.orchestrator = DisasterResponseOrchestrator(self.mock_llm)

    def test_sensor_gps(self):
        location = get_gps_location()
        data = json.loads(location)
        self.assertIn("latitude", data)
        self.assertIn("longitude", data)

    def test_map_query(self):
        result = query_offline_map("San Francisco", "shelter")
        data = json.loads(result)
        self.assertEqual(data["category"], "shelter")
        self.assertTrue(len(data["found"]) > 0)

    def test_retrieval(self):
        retriever = LocalRetriever("test_protocols.db")
        result = retriever.retrieve_info("earthquake")
        self.assertIn("Earthquake", result)
        # Clean up
        if os.path.exists("test_protocols.db"):
            os.remove("test_protocols.db")

    def test_orchestrator_tool_calling_logic(self):
        # Setup mock for tool call
        self.mock_llm.mock_tool_calls = [
            {
                "function": {
                    "name": "get_gps_location",
                    "arguments": "{}"
                }
            }
        ]
        
        # We need to mock the second generate call too
        original_generate = self.mock_llm.generate
        def side_effect(prompt, system_instruction=None):
            if "Tool results" in prompt:
                return "Your location is 37.7749, -122.4194."
            return "Checking location."
        
        self.mock_llm.generate = side_effect
        
        response = self.orchestrator.run("Where am I?")
        self.assertIn("37.7749", response)


if __name__ == '__main__':
    unittest.main()
