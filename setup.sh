#!/bin/bash
set -e

echo "=== Initializing MCP Environment Setup (Ubuntu) ==="

# Get the absolute path of the project root to configure the MCP servers
PROJECT_ROOT="$(pwd)"
PENTESTGPT_DIR="$PROJECT_ROOT/tools/PentestGPT-MCP"
PENTEST_TOOLS_SCRIPT="$PENTESTGPT_DIR/mcp_servers/pentest_tools_server.py"
HEXSTRIKE_MCP_DIR="$PROJECT_ROOT/tools/hexstrike-mcp"
HEXSTRIKE_MCP_SCRIPT="$HEXSTRIKE_MCP_DIR/hexstrike_mcp_server.py"

# ============================================================
# 1. Install core system dependencies (nmap, dirb) via apt
# ============================================================
echo "[+] Checking for nmap and dirb (required for PentestGPT tools)..."
if ! command -v nmap &> /dev/null || ! command -v dirb &> /dev/null; then
    echo "[+] Installing nmap and dirb via apt..."
    sudo apt update && sudo apt install -y nmap dirb
else
    echo "[OK] nmap and dirb are already installed."
fi

# ============================================================
# 2. Install Metasploit Framework (if not present)
# ============================================================
echo "[+] Checking for Metasploit Framework..."
if ! command -v msfconsole &> /dev/null; then
    echo "[+] Installing Metasploit via official Rapid7 installer..."
    curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod 755 /tmp/msfinstall
    sudo /tmp/msfinstall
else
    echo "[OK] Metasploit already installed."
fi

# ============================================================
# 3. Setup Python dependencies (Core + mcp-pymetasploit3)
# ============================================================
echo "[+] Installing core Python dependencies..."
pip install -r requirements.txt
pip install mcp-pymetasploit3

# ============================================================
# 4. Clone and setup yuhano/PentestGPT-MCP (Idempotent)
# ============================================================
if [ ! -d "$PENTESTGPT_DIR" ]; then
    echo "[+] Cloning PentestGPT-MCP repository into tools/..."
    mkdir -p "$PROJECT_ROOT/tools"
    git clone https://github.com/yuhano/PentestGPT-MCP.git "$PENTESTGPT_DIR"
else
    echo "[OK] PentestGPT-MCP directory already exists."
fi

# Setup the virtual environment for PentestGPT-MCP if it doesn't exist
if [ ! -d "$PENTESTGPT_DIR/venv" ]; then
    echo "[+] Creating Python virtual environment for PentestGPT-MCP..."
    python3 -m venv "$PENTESTGPT_DIR/venv"
else
    echo "[OK] PentestGPT-MCP venv already exists."
fi

# Install the requirements into the venv
echo "[+] Installing PentestGPT-MCP Python dependencies..."
"$PENTESTGPT_DIR/venv/bin/pip" install -r "$PENTESTGPT_DIR/requirements.txt"

# ============================================================
# 5. Clone and setup HexStrike MCP server (Idempotent)
# ============================================================
if [ ! -d "$HEXSTRIKE_MCP_DIR" ]; then
    echo "[+] Cloning HexStrike MCP server into tools/..."
    mkdir -p "$PROJECT_ROOT/tools"
    git clone https://github.com/b-bogus/hexstrike-ai_mcp_server.git "$HEXSTRIKE_MCP_DIR"
else
    echo "[OK] HexStrike MCP directory already exists."
fi

echo "[+] Installing HexStrike MCP Python dependencies..."
pip install requests fastmcp

# ============================================================
# 6. Final Verification
# ============================================================
echo "[+] Verifying PentestGPT MCP server script..."
if [ ! -f "$PENTEST_TOOLS_SCRIPT" ]; then
    echo "[!] ERROR: pentest_tools_server.py not found at expected location."
    exit 1
fi
echo "[OK] PentestGPT MCP server script found."

echo "[+] Verifying HexStrike MCP server script..."
if [ ! -f "$HEXSTRIKE_MCP_SCRIPT" ]; then
    echo "[!] WARNING: hexstrike_mcp_server.py not found at expected location."
    echo "    Expected: $HEXSTRIKE_MCP_SCRIPT"
else
    echo "[OK] HexStrike MCP server script found."
fi

# ============================================================
# 7. Reminders for manual steps
# ============================================================
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Before running run_agent.py, complete these manual steps:"
echo ""
echo "  1. Update 'mcp_config.json' -> 'pentestgpt' -> 'args' to:"
echo "       [\"$PENTEST_TOOLS_SCRIPT\"]"
echo ""
echo "  2. Update 'mcp_config.json' -> 'hexstrike' -> 'args' to point to:"
echo "       $HEXSTRIKE_MCP_SCRIPT"
echo ""
echo "  3. Start Metasploit RPC daemon (in a separate terminal):"
echo "       msfrpcd -P yourpassword -p 55553 -n"
echo ""
echo "  4. Start HexStrike Flask API backend (in a separate terminal):"
echo "       python3 hexstrike_server.py   # from the 0x4m4/hexstrike-ai repo"
echo ""
echo "  5. Verify the environment with:"
echo "       python3 verify_mcp.py"
echo ""