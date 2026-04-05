#!/usr/bin/env python3
"""
Semantic Scholar API wrapper.

Search papers, get details, citations, references, and author info.

Usage:
    python search_semantic.py search "transformer attention mechanism"
    python search_semantic.py paper "ArXiv:2005.14165"
    python search_semantic.py citations "CorpusId:13756489"
    python search_semantic.py references "CorpusId:13756489"
    python search_semantic.py author "Yann LeCun"
    python search_semantic.py author-papers <author_id>
"""

import sys
import json
import urllib.request
import urllib.parse
import urllib.error

BASE_URL = "https://api.semanticscholar.org/graph/v1"

PAPER_FIELDS = "paperId,corpusId,url,title,abstract,venue,year,referenceCount,citationCount,authors,openAccessPdf"
AUTHOR_FIELDS = "authorId,name,affiliations,paperCount,citationCount,hIndex"
CITATION_FIELDS = "paperId,title,year,authors,citationCount"


def api_get(url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "hermes-agent/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        if e.code == 429:
            print("ERROR: Rate limited. Wait before making more requests.", file=sys.stderr)
        elif e.code == 404:
            print("ERROR: Not found. Check the paper/author ID format.", file=sys.stderr)
        else:
            print(f"ERROR: HTTP {e.code}: {e.reason}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return None


def format_paper(paper):
    authors = ", ".join(a.get("name", "?") for a in (paper.get("authors") or []))
    pdf_url = (paper.get("openAccessPdf") or {}).get("url", "N/A")
    return f"""---
Title: {paper.get('title', 'N/A')}
Authors: {authors}
Year: {paper.get('year', 'N/A')}
Venue: {paper.get('venue', 'N/A')}
Citations: {paper.get('citationCount', 0)} | References: {paper.get('referenceCount', 0)}
Semantic Scholar: {paper.get('url', 'N/A')}
PDF: {pdf_url}
Corpus ID: {paper.get('corpusId', 'N/A')}

Abstract:
{paper.get('abstract', 'N/A')}"""


def cmd_search(query, limit=10):
    url = f"{BASE_URL}/paper/search?query={urllib.parse.quote(query)}&limit={limit}&fields={PAPER_FIELDS}"
    result = api_get(url)
    if result and result.get("data"):
        print(f"Found {result.get('total', '?')} papers. Showing top {len(result['data'])}:\n")
        for paper in result["data"]:
            print(format_paper(paper))
            print()
    else:
        print(f"No papers found for: {query}")


def cmd_paper(paper_id):
    url = f"{BASE_URL}/paper/{urllib.parse.quote(paper_id)}?fields={PAPER_FIELDS}"
    result = api_get(url)
    if result:
        print(format_paper(result))


def cmd_citations(paper_id, limit=10):
    url = f"{BASE_URL}/paper/{urllib.parse.quote(paper_id)}/citations?limit={limit}&fields={CITATION_FIELDS}"
    result = api_get(url)
    if result and result.get("data"):
        print("Papers citing this work:\n")
        for item in result["data"]:
            p = item.get("citingPaper", {})
            authors = ", ".join(a.get("name", "?") for a in (p.get("authors") or []))
            print(f"- [{p.get('year', '?')}] {p.get('title', 'N/A')}")
            print(f"  Authors: {authors}")
            print(f"  Citations: {p.get('citationCount', 0)} | ID: {p.get('paperId', 'N/A')}\n")
    else:
        print("No citations found.")


def cmd_references(paper_id, limit=10):
    url = f"{BASE_URL}/paper/{urllib.parse.quote(paper_id)}/references?limit={limit}&fields={CITATION_FIELDS}"
    result = api_get(url)
    if result and result.get("data"):
        print("Papers referenced by this work:\n")
        for item in result["data"]:
            p = item.get("citedPaper", {})
            if p.get("title"):
                authors = ", ".join(a.get("name", "?") for a in (p.get("authors") or []))
                print(f"- [{p.get('year', '?')}] {p.get('title', 'N/A')}")
                print(f"  Authors: {authors}")
                print(f"  Citations: {p.get('citationCount', 0)} | ID: {p.get('paperId', 'N/A')}\n")
    else:
        print("No references found.")


def cmd_author(name, limit=5):
    url = f"{BASE_URL}/author/search?query={urllib.parse.quote(name)}&limit={limit}&fields={AUTHOR_FIELDS}"
    result = api_get(url)
    if result and result.get("data"):
        print(f"Found {result.get('total', '?')} authors:\n")
        for a in result["data"]:
            affiliations = ", ".join(a.get("affiliations") or []) or "N/A"
            print(f"---\nName: {a.get('name', 'N/A')}")
            print(f"Author ID: {a.get('authorId', 'N/A')}")
            print(f"Affiliations: {affiliations}")
            print(f"Papers: {a.get('paperCount', 0)} | Citations: {a.get('citationCount', 0)} | h-Index: {a.get('hIndex', 0)}\n")
    else:
        print(f"No authors found for: {name}")


def cmd_author_papers(author_id, limit=10):
    url = f"{BASE_URL}/author/{author_id}/papers?limit={limit}&fields={CITATION_FIELDS}"
    result = api_get(url)
    if result and result.get("data"):
        print("Papers by this author:\n")
        for p in result["data"]:
            authors = ", ".join(a.get("name", "?") for a in (p.get("authors") or []))
            print(f"- [{p.get('year', '?')}] {p.get('title', 'N/A')}")
            print(f"  Authors: {authors}")
            print(f"  Citations: {p.get('citationCount', 0)} | ID: {p.get('paperId', 'N/A')}\n")
    else:
        print("No papers found.")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    arg = " ".join(sys.argv[2:])
    limit = 10

    if cmd == "search":
        cmd_search(arg, limit)
    elif cmd == "paper":
        cmd_paper(arg)
    elif cmd == "citations":
        cmd_citations(arg, limit)
    elif cmd == "references":
        cmd_references(arg, limit)
    elif cmd == "author":
        cmd_author(arg)
    elif cmd == "author-papers":
        cmd_author_papers(arg, limit)
    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
