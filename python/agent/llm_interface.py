import abc
import inspect
import json
from typing import Any, Callable, Dict, List, Optional, Union


class LLMInterface(abc.ABC):
    """Abstract interface for LLM backends (Gemma 4 LiteRT, llama.cpp)."""

    @abc.abstractmethod
    def generate(self, prompt: str, system_instruction: Optional[str] = None) -> str:
        """Generates a response for a given prompt."""
        pass

    @abc.abstractmethod
    def register_tool(self, tool_fn: Callable) -> None:
        """Registers a function as a tool for the LLM."""
        pass

    @abc.abstractmethod
    def call_tools(self, message: str) -> Optional[List[Dict[str, Any]]]:
        """Detects and returns tool calls from a message."""
        pass


class Gemma4Interface(LLMInterface):
    """Gemma 4 LiteRT implementation using litert-lm."""

    def __init__(self, model_path: str):
        self.tools = []
        self.engine = None
        try:
            import litert_lm
            self.engine = litert_lm.Engine(model_path)
        except ImportError:
            print("Warning: litert-lm not installed. Gemma4Interface will be unavailable.")

    def generate(self, prompt: str, system_instruction: Optional[str] = None, image_path: Optional[str] = None) -> str:
        if not self.engine:
            return "Error: Gemma 4 Engine not initialized."

        config = {"system_instruction": system_instruction, "tools": self.tools} if self.tools else {"system_instruction": system_instruction}
        
        with self.engine.create_conversation(**config) as conversation:
            response_text = ""
            # In a real multimodal Gemma 4 implementation, the prompt can include images
            actual_prompt = prompt if not image_path else f"[Image: {image_path}] {prompt}"
            
            for chunk in conversation.send_message_async(actual_prompt):
                content = chunk["content"][0]
                if "text" in content:
                    response_text += content["text"]
            return response_text

    def multimodal_analyze(self, image_path: str, task: str = "describe") -> str:
        """Analyzes an image using Gemma 4's native multimodal capabilities."""
        if not self.engine:
            return "Error: Gemma 4 Engine not initialized."
            
        prompt = f"Analyze this image and perform the task: {task}"
        return self.generate(prompt, image_path=image_path)

    def register_tool(self, tool_fn: Callable) -> None:
        sig = inspect.signature(tool_fn)
        properties = {}
        required = []
        for name, param in sig.parameters.items():
            if name == 'self':
                continue
            param_type = "string"
            if param.annotation != inspect.Parameter.empty:
                type_map = {str: "string", int: "integer", float: "number", bool: "boolean", list: "array", dict: "object"}
                param_type = type_map.get(param.annotation, "string")
            properties[name] = {"type": param_type, "description": f"Parameter: {name}"}
            if param.default == inspect.Parameter.empty:
                required.append(name)
        self.tools.append({
            "name": tool_fn.__name__,
            "description": tool_fn.__doc__ or "No description provided.",
            "parameters": {
                "type": "object",
                "properties": properties,
                "required": required
            }
        })

    def call_tools(self, message: str) -> Optional[List[Dict[str, Any]]]:
        # Gemma 4 handles tool calls automatically in the send_message_async stream.
        # This method is for manual parsing if needed, but litert-lm is high-level.
        return None


class LlamaCppInterface(LLMInterface):
    """llama.cpp implementation using llama-cpp-python."""

    def __init__(self, model_path: str, chat_format: str = "chatml-function-calling"):
        self.tools_schema = []
        self.llm = None
        try:
            from llama_cpp import Llama
            self.llm = Llama(
                model_path=model_path,
                chat_format=chat_format,
                n_gpu_layers=-1,
                verbose=False
            )
        except ImportError:
            print("Warning: llama-cpp-python not installed. LlamaCppInterface will be unavailable.")

    def generate(self, prompt: str, system_instruction: Optional[str] = None) -> str:
        if not self.llm:
            return "Error: llama.cpp not initialized."

        messages = []
        if system_instruction:
            messages.append({"role": "system", "content": system_instruction})
        messages.append({"role": "user", "content": prompt})

        response = self.llm.create_chat_completion(
            messages=messages,
            tools=self.tools_schema,
            tool_choice="auto"
        )
        
        message = response["choices"][0]["message"]
        if "tool_calls" in message:
            # Handle tool calls here or return them for the orchestrator
            return json.dumps(message["tool_calls"])
        return message["content"]

    def register_tool(self, tool_fn: Callable) -> None:
        sig = inspect.signature(tool_fn)
        properties = {}
        required = []
        for name, param in sig.parameters.items():
            if name == 'self':
                continue
            param_type = "string"
            if param.annotation != inspect.Parameter.empty:
                type_map = {str: "string", int: "integer", float: "number", bool: "boolean", list: "array", dict: "object"}
                param_type = type_map.get(param.annotation, "string")
            properties[name] = {"type": param_type, "description": f"Parameter: {name}"}
            if param.default == inspect.Parameter.empty:
                required.append(name)
        schema = {
            "type": "function",
            "function": {
                "name": tool_fn.__name__,
                "description": tool_fn.__doc__ or "No description provided.",
                "parameters": {
                    "type": "object",
                    "properties": properties,
                    "required": required
                }
            }
        }
        self.tools_schema.append(schema)

    def call_tools(self, message: str) -> Optional[List[Dict[str, Any]]]:
        try:
            return json.loads(message)
        except (ValueError, TypeError):
            return None
