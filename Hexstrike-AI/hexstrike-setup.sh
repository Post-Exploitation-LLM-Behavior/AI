#!/bin/bash
set -e

ROOT="$(pwd)"

echo "=== Setting up: HexStrike MCP ==="

# ---- System build deps ----
echo "[+] Installing build dependencies..."
sudo apt update
sudo apt install -y python3-dev libffi-dev build-essential git curl

# ---- Ensure Python 3.11 (needed for wheels) ----
if ! command -v python3.11 &> /dev/null; then
    echo "[+] Installing python3.11 via deadsnakes PPA..."
    if ! command -v add-apt-repository &> /dev/null; then
        sudo apt install -y software-properties-common
    fi
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-dev
else
    echo "[OK] python3.11 already installed."
fi

# ============================================================
# Part A: MCP bridge (runs on system python3)
# ============================================================
echo ""
echo "--- Part A: MCP bridge ---"

if [ ! -f "$ROOT/hexstrike_mcp_server.py" ]; then
    echo "[+] Cloning HexStrike MCP server..."
    TMPDIR=$(mktemp -d)
    git clone https://github.com/b-bogus/hexstrike-ai_mcp_server.git "$TMPDIR"
    cp "$TMPDIR/hexstrike_mcp_server.py" "$ROOT/"
    rm -rf "$TMPDIR"
else
    echo "[OK] hexstrike_mcp_server.py already present."
fi

echo "[+] Installing MCP bridge deps (fastmcp, requests)..."
python3 -m pip install --break-system-packages requests fastmcp

if ! python3 -c "import fastmcp, requests" 2>/dev/null; then
    echo "[!] fastmcp or requests failed to import."
    exit 1
fi
echo "[OK] MCP bridge deps importable."

# ============================================================
# Part B: Flask API backend (runs in Python 3.11 venv)
# ============================================================
echo ""
echo "--- Part B: Flask API backend ---"

HEXSTRIKE_API_REPO="$ROOT/hexstrike-ai"
HEXSTRIKE_VENV="$HEXSTRIKE_API_REPO/venv"

if [ ! -d "$HEXSTRIKE_API_REPO" ]; then
    echo "[+] Cloning HexStrike Flask API backend..."
    git clone https://github.com/0x4m4/hexstrike-ai.git "$HEXSTRIKE_API_REPO"
else
    echo "[OK] HexStrike Flask API repo already present."
fi

if [ ! -f "$HEXSTRIKE_API_REPO/hexstrike_server.py" ]; then
    echo "[!] WARNING: hexstrike_server.py not found in $HEXSTRIKE_API_REPO"
fi

if [ ! -d "$HEXSTRIKE_VENV" ]; then
    echo "[+] Creating Flask API venv with Python 3.11..."
    python3.11 -m venv "$HEXSTRIKE_VENV"
fi

echo "[+] Installing Flask API deps (upgrading pip first)..."
"$HEXSTRIKE_VENV/bin/pip" install --upgrade pip setuptools wheel

if [ -f "$HEXSTRIKE_API_REPO/requirements.txt" ]; then
    echo "[+] Installing requirements.txt (this may take a while)..."
    "$HEXSTRIKE_VENV/bin/pip" install -r "$HEXSTRIKE_API_REPO/requirements.txt"
else
    echo "[!] No requirements.txt found. Skipping."
fi

echo ""
echo "=== HexStrike MCP Setup Complete ==="
echo ""
echo "mcp_config.json entry:"
echo '  "hexstrike": {'
echo '    "command": "python3",'
echo "    \"args\": [\"$ROOT/hexstrike_mcp_server.py\", \"--host\", \"0.0.0.0\", \"--port\", \"8889\", \"--api-url\", \"http://localhost:8888\"],"
echo '    "env": {}'
echo '  }'
echo ""
echo "Manual step (in a separate terminal, before running the agent):"
echo "  $HEXSTRIKE_VENV/bin/python3 $HEXSTRIKE_API_REPO/hexstrike_server.py"