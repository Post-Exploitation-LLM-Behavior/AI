#!/bin/bash
set -e

ROOT="$(pwd)"

echo "=== Setting up all three MCPs (no manual venvs) ==="

# ============================================================
# Metasploit MCP — via pipx
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: Metasploit MCP (pipx)"
echo "----------------------------------------"

if ! command -v pipx &> /dev/null; then
    echo "[+] Installing pipx..."
    sudo apt update && sudo apt install -y pipx
    pipx ensurepath
fi

if ! command -v msfconsole &> /dev/null; then
    echo "[+] Installing Metasploit via Rapid7 installer..."
    if ! command -v curl &> /dev/null; then
        echo "[!] curl missing. Run: sudo apt install curl"
        exit 1
    fi
    curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod 755 /tmp/msfinstall
    sudo /tmp/msfinstall
else
    echo "[OK] Metasploit already installed."
fi

echo "[+] Installing mcp-pymetasploit3 via pipx..."
pipx install mcp-pymetasploit3 --force

# ============================================================
# HexStrike MCP — system pip with --break-system-packages
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: HexStrike MCP"
echo "----------------------------------------"

if [ ! -f "$ROOT/hexstrike_mcp_server.py" ]; then
    echo "[+] Cloning HexStrike MCP server..."
    if ! command -v git &> /dev/null; then
        echo "[!] git missing. Run: sudo apt install git"
        exit 1
    fi
    TMPDIR=$(mktemp -d)
    git clone https://github.com/b-bogus/hexstrike-ai_mcp_server.git "$TMPDIR"
    cp "$TMPDIR/hexstrike_mcp_server.py" "$ROOT/"
    rm -rf "$TMPDIR"
else
    echo "[OK] hexstrike_mcp_server.py already present."
fi

echo "[+] Installing HexStrike Python deps system-wide..."
pip3 install --break-system-packages requests fastmcp

# ============================================================
# PentestGPT MCP — keeps its own venv (repo default)
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: PentestGPT MCP"
echo "----------------------------------------"

PENTESTGPT_REPO="$ROOT/PentestGPT-MCP"
PENTEST_TOOLS_SCRIPT="$PENTESTGPT_REPO/mcp_servers/pentest_tools_server.py"

if ! command -v nmap &> /dev/null || ! command -v dirb &> /dev/null; then
    echo "[+] Installing nmap and dirb..."
    sudo apt update && sudo apt install -y nmap dirb
else
    echo "[OK] nmap and dirb already installed."
fi

if [ ! -d "$PENTESTGPT_REPO" ]; then
    echo "[+] Cloning PentestGPT-MCP..."
    git clone https://github.com/yuhano/PentestGPT-MCP.git "$PENTESTGPT_REPO"
else
    echo "[OK] PentestGPT-MCP already cloned."
fi

if [ ! -d "$PENTESTGPT_REPO/venv" ]; then
    echo "[+] Creating venv for PentestGPT-MCP (repo default)..."
    python3 -m venv "$PENTESTGPT_REPO/venv"
else
    echo "[OK] PentestGPT-MCP venv exists."
fi

echo "[+] Installing PentestGPT-MCP deps into its venv..."
"$PENTESTGPT_REPO/venv/bin/pip" install -r "$PENTESTGPT_REPO/requirements.txt"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== All setups complete ==="
echo ""
echo "mcp_config.json settings:"
echo ""
echo "  metasploit -> command:"
echo "    mcp-pymetasploit3"
echo ""
echo "  hexstrike -> command:"
echo "    python3"
echo "  hexstrike -> args (first item):"
echo "    $ROOT/hexstrike_mcp_server.py"
echo ""
echo "  pentestgpt -> command:"
echo "    $PENTESTGPT_REPO/venv/bin/python3"
echo "  pentestgpt -> args (first item):"
echo "    $PENTEST_TOOLS_SCRIPT"
echo ""
echo "Start services manually before running each agent:"
echo "  Metasploit:  msfrpcd -P yourpassword -p 55553 -n"
echo "  HexStrike:   python3 hexstrike_server.py   (Flask API)"
echo "  PentestGPT:  (none — nmap/dirb are on PATH)"