import os
import re

class LocalKnowledgeBase:
    def __init__(self, directory=None):
        if directory is None:
            _root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            directory = os.path.join(os.path.dirname(_root), "data", "manuals")
        self.directory = directory
        self.documents = {}
        self.load_manuals()

    def load_manuals(self):
        if not os.path.exists(self.directory):
            print(f"[!] Manuals directory not found: {self.directory}")
            return
        print(f"[*] Ingesting local manuals from {self.directory}...")
        for filename in os.listdir(self.directory):
            if filename.endswith(".md"):
                with open(os.path.join(self.directory, filename), 'r', encoding='utf-8') as f:
                    content = f.read()
                    sections = re.split(r'(^#+\s.*)', content, flags=re.MULTILINE)
                    self.documents[filename] = sections
        print(f"[+] Loaded {len(self.documents)} manuals.")

    def search(self, query):
        query = query.lower()
        results = []
        for doc, sections in self.documents.items():
            for i in range(len(sections)):
                if query in sections[i].lower():
                    # Return the matched header and the following content chunk
                    context = sections[i] + (sections[i+1] if i+1 < len(sections) else "")
                    results.append(context)
        return "\n---\n".join(results[:2]) if results else "No specific protocol found in offline database."

if __name__ == "__main__":
    kb = LocalKnowledgeBase()
    print(kb.search("bleeding"))
