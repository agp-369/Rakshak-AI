import argparse
import sys
from .llm_interface import Gemma4Interface, LlamaCppInterface
from .orchestrator import DisasterResponseOrchestrator


def main():
    parser = argparse.ArgumentParser(description="Gemma 4 & llama.cpp Offline-First Disaster Response Orchestrator")
    parser.add_argument("--backend", choices=["gemma", "llama"], default="llama", help="LLM backend to use.")
    parser.add_argument("--model-path", type=str, required=True, help="Path to the .litertlm or .gguf model file.")
    parser.add_argument("--interactive", action="store_true", help="Run in interactive CLI mode.")
    parser.add_argument("--prompt", type=str, help="Initial prompt to send to the orchestrator.")

    args = parser.parse_args()

    # 1. Initialize the LLM backend
    if args.backend == "gemma":
        llm = Gemma4Interface(args.model_path)
    else:
        llm = LlamaCppInterface(args.model_path)

    # 2. Setup the orchestrator
    orchestrator = DisasterResponseOrchestrator(llm)

    # 3. Handle prompt or interactive loop
    if args.interactive:
        print("\n--- Offline Disaster Response Agent CLI ---")
        print("Type 'exit' to quit. Use prompts like 'Where am I?' or 'Find nearest shelter'.")
        while True:
            try:
                user_input = input("\n[User]: ")
                if user_input.lower() in ["exit", "quit"]:
                    break
                
                response = orchestrator.run(user_input)
                print(f"\n[Agent]: {response}")
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"Error: {str(e)}")
    elif args.prompt:
        response = orchestrator.run(args.prompt)
        print(f"\n[Agent]: {response}")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
