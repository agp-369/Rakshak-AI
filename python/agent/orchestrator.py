import json
from typing import Any, Dict, List, Optional, Callable
from .llm_interface import LLMInterface
from .tools.sensors import get_gps_location, capture_camera_image, record_microphone_audio
from .tools.maps import query_offline_map, calculate_offline_route
from .retrieval.local_retriever import search_local_protocols


class DisasterResponseOrchestrator:
    """Orchestrates the offline-first disaster response workflow.
    
    Manages the loop of reasoning, tool execution (sensors, maps), and local retrieval
    to assist users in emergency situations.
    """

    def __init__(self, llm: LLMInterface):
        self.llm = llm
        self.tools: Dict[str, Callable] = {
            "get_gps_location": get_gps_location,
            "capture_camera_image": capture_camera_image,
            "record_microphone_audio": record_microphone_audio,
            "query_offline_map": query_offline_map,
            "calculate_offline_route": calculate_offline_route,
            "search_local_protocols": search_local_protocols,
        }
        self._register_tools_to_llm()

    def _register_tools_to_llm(self):
        for tool_name, tool_fn in self.tools.items():
            self.llm.register_tool(tool_fn)

    def run(self, user_input: str) -> str:
        """Main orchestrator loop for handling user requests in a disaster context."""
        system_prompt = (
            "You are an offline-first Disaster Response AI assistant. "
            "You have access to local device sensors, offline maps, and survival protocols. "
            "Your goal is to provide actionable, safe, and accurate advice. "
            "If asked to perform an action (like checking location or finding a shelter), use the tools provided."
        )

        # Initial LLM generation
        response = self.llm.generate(user_input, system_instruction=system_prompt)
        
        # Check for tool calls
        tool_calls = self.llm.call_tools(response)
        
        if tool_calls:
            results = []
            for tool_call in tool_calls:
                # Handle tool calls for llama.cpp / Gemma 4
                # Note: litert-lm may handle this automatically, but for LlamaCppInterface we parse manually
                fn_name = tool_call.get("function", {}).get("name")
                fn_args = json.loads(tool_call.get("function", {}).get("arguments", "{}"))
                
                if fn_name in self.tools:
                    print(f"[*] Orchestrator executing tool: {fn_name} with args: {fn_args}")
                    tool_result = self.tools[fn_name](**fn_args)
                    results.append({"tool": fn_name, "result": tool_result})
                else:
                    results.append({"tool": fn_name, "error": "Tool not found."})
            
            # Feed the results back for a final reasoning step
            follow_up_prompt = f"Tool results for context: {json.dumps(results)}\n\nBased on these results, provide your final assessment or instructions to the user."
            final_response = self.llm.generate(follow_up_prompt, system_instruction=system_prompt)
            return final_response
            
        return response
