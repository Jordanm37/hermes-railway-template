"""Bootstrap gcalcli OAuth credentials from Gmail MCP credential files.

Reads the GCP OAuth keys and credentials JSON files (already written by
entrypoint.sh) and creates a gcalcli-compatible OAuth token file.

Usage: python bootstrap_gcalcli.py <gmail_mcp_dir> <gcalcli_config_dir>
"""

import json
import os
import sys
import pickle
from pathlib import Path

from google.oauth2.credentials import Credentials

def main():
    gmail_mcp_dir = Path(sys.argv[1])
    gcalcli_dir = Path(sys.argv[2])

    oauth_path = gmail_mcp_dir / "gcp-oauth.keys.json"
    creds_path = gmail_mcp_dir / "credentials.json"

    if not oauth_path.exists() or not creds_path.exists():
        print("[gcalcli-bootstrap] No Gmail MCP credentials found, skipping")
        return

    with open(oauth_path) as f:
        oauth = json.load(f)["installed"]
    with open(creds_path) as f:
        creds_data = json.load(f)

    # Check that calendar scope is present
    scopes = creds_data.get("scope", "").split()
    if "https://www.googleapis.com/auth/calendar" not in scopes:
        print("[gcalcli-bootstrap] Calendar scope not present in credentials, skipping")
        return

    creds = Credentials(
        token=creds_data.get("access_token"),
        refresh_token=creds_data.get("refresh_token"),
        token_uri=oauth["token_uri"],
        client_id=oauth["client_id"],
        client_secret=oauth["client_secret"],
        scopes=["https://www.googleapis.com/auth/calendar"],
    )

    gcalcli_dir.mkdir(parents=True, exist_ok=True)
    token_path = gcalcli_dir / "oauth"

    with open(token_path, "wb") as f:
        pickle.dump(creds, f)

    print(f"[gcalcli-bootstrap] Wrote gcalcli OAuth token to {token_path}")


if __name__ == "__main__":
    main()
