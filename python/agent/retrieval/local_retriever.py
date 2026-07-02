import sqlite3
import os
import glob
from typing import List, Optional

class LocalRetriever:
    """Hybrid retriever: keyword (SQLite) + vector search (ChromaDB + sentence-transformers).
    
    Provides specialized knowledge for disaster response scenarios.
    Falls back gracefully if vector dependencies are missing.
    """

    def __init__(self, db_path: str = "disaster_protocols.db"):
        self.db_path = db_path
        self._vector_store = None
        self._encoder = None
        self._initialize_db()
        self._try_init_vector_store()

    def _initialize_db(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS protocols (
                id INTEGER PRIMARY KEY,
                topic TEXT,
                content TEXT,
                tags TEXT,
                source_file TEXT
            )
        ''')
        cursor.execute("SELECT COUNT(*) FROM protocols")
        if cursor.fetchone()[0] == 0:
            self._populate_from_manuals(conn, cursor)
        conn.close()

    def _populate_from_manuals(self, conn, cursor):
        manuals_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "data", "manuals"
        )
        if not os.path.exists(manuals_dir):
            self._insert_defaults(cursor)
            conn.commit()
            return

        md_files = glob.glob(os.path.join(manuals_dir, "*.md"))
        if not md_files:
            self._insert_defaults(cursor)
            conn.commit()
            return

        protocols = []
        for md_path in md_files:
            source = os.path.basename(md_path)
            with open(md_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Parse markdown sections
            lines = content.split('\n')
            current_topic = source.replace('.md', '').replace('_', ' ').title()
            current_section = ""
            current_content = []

            for line in lines:
                if line.startswith('# '):
                    current_topic = line.lstrip('# ').strip()
                elif line.startswith('## '):
                    if current_content:
                        protocols.append((
                            f"{current_topic}: {current_section}",
                            '\n'.join(current_content).strip(),
                            source,
                        ))
                    current_section = line.lstrip('## ').strip()
                    current_content = []
                else:
                    current_content.append(line)

            # Last section
            if current_content:
                protocols.append((
                    f"{current_topic}: {current_section}",
                    '\n'.join(current_content).strip(),
                    source,
                ))

            # Also store whole document
            protocols.append((
                current_topic,
                content,
                source,
            ))

        # Deduplicate
        seen = set()
        unique = []
        for t, c, s in protocols:
            key = (t.strip(), c[:50])
            if key not in seen:
                seen.add(key)
                unique.append((t, c, s))

        cursor.executemany(
            "INSERT INTO protocols (topic, content, source_file) VALUES (?, ?, ?)",
            unique
        )
        conn.commit()
        print(f"[+] Loaded {len(unique)} protocol entries from {len(md_files)} manuals")

    def _insert_defaults(self, cursor):
        protocols = [
            ("First Aid: Bleeding", "Apply direct pressure with a clean cloth. If severe, apply tourniquet 2-3 inches above wound.", "medical, emergency"),
            ("Earthquake: Indoors", "Drop, Cover, and Hold On. Stay away from windows and heavy furniture.", "earthquake, safety"),
            ("Water Purification", "Boil water for at least 1 minute. If boiling not possible, use 8 drops of unscented bleach per gallon.", "water, survival"),
            ("START Triage", "Walking = GREEN. Not breathing = BLACK. RR>30 or <10 = RED. No radial pulse = RED. Unresponsive = RED.", "triage, medical"),
            ("Burn Treatment", "Cool with running water 10-20 min. Do NOT use ice/butter. Cover loosely with sterile dressing.", "medical, fire"),
        ]
        cursor.executemany(
            "INSERT INTO protocols (topic, content, tags) VALUES (?, ?, ?)", protocols
        )

    def _try_init_vector_store(self):
        """Attempt to initialize ChromaDB + sentence-transformers for semantic search."""
        try:
            from sentence_transformers import SentenceTransformer
            import chromadb
            from chromadb.config import Settings

            self._encoder = SentenceTransformer('all-MiniLM-L6-v2', device='cpu')
            self._vector_store = chromadb.Client(Settings(
                anonymized_telemetry=False,
                is_persistent=True,
                persist_directory='chromadb_data'
            ))

            collection_name = 'disaster_protocols'
            try:
                self._collection = self._vector_store.get_collection(collection_name)
                # Check if empty
                if self._collection.count() == 0:
                    self._index_vectors()
            except Exception:
                self._collection = self._vector_store.create_collection(collection_name)
                self._index_vectors()

            print("[+] Vector search enabled (ChromaDB + sentence-transformers)")
        except ImportError:
            self._vector_store = None
            print("[*] Vector search unavailable (install: pip install sentence-transformers chromadb)")

    def _index_vectors(self):
        """Index all protocol content as vectors."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT id, topic, content FROM protocols")
        rows = cursor.fetchall()
        conn.close()

        if not rows or self._encoder is None:
            return

        texts = [f"{topic}: {content}" for tid, topic, content in rows]
        ids = [str(tid) for tid, _, _ in rows]
        embeddings = self._encoder.encode(texts, show_progress_bar=False).tolist()

        self._collection.add(
            embeddings=embeddings,
            documents=texts,
            ids=ids,
        )
        print(f"[+] Indexed {len(rows)} protocol vectors")

    def retrieve_info(self, query: str, top_k: int = 3) -> str:
        """Hybrid retrieval: vector search (when available) + keyword fallback."""
        vector_results = []

        # Vector search
        if self._vector_store is not None and self._encoder is not None:
            try:
                q_embed = self._encoder.encode(query).tolist()
                results = self._collection.query(
                    query_embeddings=[q_embed],
                    n_results=top_k
                )
                if results and results['documents']:
                    vector_results = results['documents'][0]
            except Exception:
                pass

        # Keyword fallback (always available)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "SELECT topic, content FROM protocols WHERE topic LIKE ? OR content LIKE ? OR tags LIKE ?",
            (f"%{query}%", f"%{query}%", f"%{query}%")
        )
        keyword_results = cursor.fetchall()
        conn.close()

        # Merge results
        seen = set()
        merged = []

        for text in vector_results:
            if text not in seen:
                seen.add(text)
                merged.append(text)

        for topic, content in keyword_results:
            text = f"### {topic}\n{content}"
            if text not in seen:
                seen.add(text)
                merged.append(text)

        if not merged:
            return f"No local protocols found for: '{query}'. Try broader terms like 'first aid', 'earthquake', or 'flood'."

        return "\n\n---\n\n".join(merged[:top_k])


def search_local_protocols(query: str) -> str:
    """LLM-callable tool: search offline disaster protocols."""
    retriever = LocalRetriever()
    return retriever.retrieve_info(query)
