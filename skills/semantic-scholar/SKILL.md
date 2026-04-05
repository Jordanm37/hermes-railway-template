---
name: semantic-scholar
description: Search academic papers, get citation graphs, and explore author profiles via Semantic Scholar API.
---

# Semantic Scholar

Search papers, get details, citations, references, and author info. No API key needed (100 req/5 min rate limit).

## Commands

```bash
# Search papers by keyword
python /app/skills/semantic-scholar/search_semantic.py search "transformer attention mechanism"

# Get paper details by ID
python /app/skills/semantic-scholar/search_semantic.py paper "ArXiv:2005.14165"
python /app/skills/semantic-scholar/search_semantic.py paper "CorpusId:49313245"
python /app/skills/semantic-scholar/search_semantic.py paper "DOI:10.1234/example"

# Get citations (papers that cite this one)
python /app/skills/semantic-scholar/search_semantic.py citations "CorpusId:13756489"

# Get references (papers this one cites)
python /app/skills/semantic-scholar/search_semantic.py references "ArXiv:2005.14165"

# Search authors
python /app/skills/semantic-scholar/search_semantic.py author "Geoffrey Hinton"

# Get author's papers
python /app/skills/semantic-scholar/search_semantic.py author-papers <author_id>
```

## Paper ID Formats

- `CorpusId:12345` — Semantic Scholar corpus ID
- `DOI:10.1234/example` — Digital Object Identifier
- `ArXiv:2301.12345` — ArXiv paper ID
- `PMID:12345678` — PubMed ID

## When to Use

- User asks about a paper, author, or research topic
- User sends an arXiv link — look up the paper for full details
- Building a literature review or finding related work
- Checking citation counts or impact
