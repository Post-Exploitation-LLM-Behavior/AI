#!/bin/bash
set -e

echo "=== HexStrike MCP Setup ==="

HERE="$(pwd)"

# 1. Clone the HexStrike MCP server if missing
if [ ! -f "$HERE/hexstrike_mcp_server.py" ]; then
    echo "[+] Cloning HexStrike MCP server..."
    TMPDIR=$(mktemp -d)
    git clone https://github.com/b-bogus/hexstrike-ai_mcp_server.git "$TMPDIR"
    cp "$TMPDIR/hexstrike_mcp_server.py" "$HERE/"
    rm -rf "$TMPDIR"
else
    echo "[OK] hexstrike_mcp_server.py already present."
fi

# 2. Install Python dependencies for the MCP server
echo "[+] Installing HexStrike MCP Python dependencies..."
pip install requests fastmcp

# 3. Reminder
echo ""
echo "=== Setup Complete ==="
echo "Start the HexStrike Flask API backend before running the agent:"
echo "    python3 hexstrike_server.py    # from the 0x4m4/hexstrike-ai repo"