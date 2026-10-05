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
# PentestGPT MCP — venv using Python 3.11
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: PentestGPT MCP"
echo "----------------------------------------"

PENTESTGPT_REPO="$ROOT/PentestGPT-MCP"
PENTEST_TOOLS_SCRIPT="$PENTESTGPT_REPO/mcp_servers/pentest_tools_server.py"

# Host tools
if ! command -v nmap &> /dev/null || ! command -v dirb &> /dev/null; then
    echo "[+] Installing nmap and dirb..."
    sudo apt update && sudo apt install -y nmap dirb
else
    echo "[OK] nmap and dirb already installed."
fi

# Clone the repo
if [ ! -d "$PENTESTGPT_REPO" ]; then
    echo "[+] Cloning PentestGPT-MCP..."
    if ! command -v git &> /dev/null; then
        echo "[!] git missing. Run: sudo apt install git"
        exit 1
    fi
    git clone https://github.com/yuhano/PentestGPT-MCP.git "$PENTESTGPT_REPO"
else
    echo "[OK] PentestGPT-MCP already cloned."
fi

# ---- Determine which Python 3.11 interpreter to use ----
PY311=""

if command -v pyenv &> /dev/null; then
    # Check if pyenv has a 3.11.x installed
    if pyenv versions --bare | grep -q "^3\.11"; then
        PY311="$(pyenv root)/versions/$(pyenv versions --bare | grep '^3\.11' | head -n1)/bin/python3"
    fi
fi

if [ -z "$PY311" ] && command -v python3.11 &> /dev/null; then
    PY311="$(command -v python3.11)"
fi

if [ -z "$PY311" ]; then
    echo "[!] Python 3.11 not found."
    echo ""
    echo "    PentestGPT's requirements pin gpt4all==2.8.2, which only has"
    echo "    wheels for Python <3.12. Your system Python is too new."
    echo ""
    echo "    Install Python 3.11 first, then re-run this script:"
    echo ""
    echo "      Option A (deadsnakes PPA):"
    echo "        sudo add-apt-repository ppa:deadsnakes/ppa"
    echo "        sudo apt update"
    echo "        sudo apt install python3.11 python3.11-venv"
    echo ""
    echo "      Option B (pyenv):"
    echo "        curl https://pyenv.run | bash"
    echo "        pyenv install 3.11.9"
    echo ""
    exit 1
fi

echo "[+] Using Python 3.11 at: $PY311"

# ---- Recreate venv if it was built with the wrong Python ----
RECREATE_VENV=0
if [ -d "$PENTESTGPT_REPO/venv" ]; then
    VENV_PY_VERSION="$("$PENTESTGPT_REPO/venv/bin/python3" --version 2>/dev/null || echo "unknown")"
    if [[ "$VENV_PY_VERSION" != *"3.11"* ]]; then
        echo "[!] Existing venv uses $VENV_PY_VERSION, not 3.11. Recreating..."
        RECREATE_VENV=1
    fi
fi

if [ "$RECREATE_VENV" -eq 1 ] || [ ! -d "$PENTESTGPT_REPO/venv" ]; then
    rm -rf "$PENTESTGPT_REPO/venv"
    echo "[+] Creating venv for PentestGPT-MCP with Python 3.11..."
    "$PY311" -m venv "$PENTESTGPT_REPO/venv"
else
    echo "[OK] PentestGPT-MCP venv already uses Python 3.11."
fi

# ---- Install requirements, skipping gpt4all ----
echo "[+] Installing PentestGPT-MCP deps (skipping gpt4all)..."
REQS="$PENTESTGPT_REPO/requirements.txt"
FILTERED_REQS="$(mktemp)"
grep -v -E '^\s*gpt4all' "$REQS" > "$FILTERED_REQS"

"$PENTESTGPT_REPO/venv/bin/pip" install --upgrade pip
"$PENTESTGPT_REPO/venv/bin/pip" install -r "$FILTERED_REQS"

rm -f "$FILTERED_REQS"

# ---- Verify ----
if [ ! -f "$PENTEST_TOOLS_SCRIPT" ]; then
    echo "[!] ERROR: pentest_tools_server.py not found."
    exit 1
fi
echo "[OK] PentestGPT server script found."

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
echo ""
echo "NOTE: gpt4all was skipped during install. PentestGPT only needs it"
echo "      for local model inference. Your agent uses the GenAI gateway,"
echo "      so the PentestGPT tool server should work without it."