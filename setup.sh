#!/bin/bash
set -e

ROOT="$(pwd)"

echo "=== Setting up all three MCPs ==="

# ============================================================
# 0. System build dependencies (for Python C extensions)
# ============================================================
echo ""
echo "----------------------------------------"
echo " Installing system build dependencies"
echo "----------------------------------------"

echo "[+] Installing python3-dev, libffi-dev, build-essential..."
sudo apt update
sudo apt install -y python3-dev libffi-dev build-essential

# ============================================================
# 1. Metasploit MCP — via pipx
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: Metasploit MCP (pipx)"
echo "----------------------------------------"

if ! command -v pipx &> /dev/null; then
    echo "[+] Installing pipx..."
    sudo apt install -y pipx
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
# 2. HexStrike MCP + Flask API backend
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: HexStrike MCP"
echo "----------------------------------------"

# ---- MCP bridge script ----
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

# ---- MCP bridge Python deps ----
echo "[+] Installing HexStrike MCP Python deps system-wide..."
python3 -m pip install --break-system-packages requests fastmcp

if ! python3 -c "import fastmcp, requests" 2>/dev/null; then
    echo "[!] fastmcp or requests failed to import after install."
    exit 1
fi
echo "[OK] fastmcp and requests importable."

# ---- Flask API backend ----
HEXSTRIKE_API_REPO="$ROOT/hexstrike-ai"

if [ ! -d "$HEXSTRIKE_API_REPO" ]; then
    echo "[+] Cloning HexStrike Flask API backend..."
    git clone https://github.com/0x4m4/hexstrike-ai.git "$HEXSTRIKE_API_REPO"
else
    echo "[OK] HexStrike Flask API repo already present."
fi

if [ -f "$HEXSTRIKE_API_REPO/requirements.txt" ]; then
    echo "[+] Installing HexStrike Flask API deps..."
    python3 -m pip install --break-system-packages -r "$HEXSTRIKE_API_REPO/requirements.txt"
else
    echo "[!] No requirements.txt found in $HEXSTRIKE_API_REPO"
fi

if [ ! -f "$HEXSTRIKE_API_REPO/hexstrike_server.py" ]; then
    echo "[!] WARNING: hexstrike_server.py not found in $HEXSTRIKE_API_REPO"
fi

# ============================================================
# 3. PentestGPT MCP — needs Python 3.11
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: PentestGPT MCP"
echo "----------------------------------------"

PENTESTGPT_REPO="$ROOT/PentestGPT-MCP"
PENTEST_TOOLS_SCRIPT="$PENTESTGPT_REPO/mcp_servers/pentest_tools_server.py"

# ---- Host tools ----
if ! command -v nmap &> /dev/null || ! command -v dirb &> /dev/null; then
    echo "[+] Installing nmap and dirb..."
    sudo apt install -y nmap dirb
else
    echo "[OK] nmap and dirb already installed."
fi

# ---- Clone the repo ----
if [ ! -d "$PENTESTGPT_REPO" ]; then
    echo "[+] Cloning PentestGPT-MCP..."
    git clone https://github.com/yuhano/PentestGPT-MCP.git "$PENTESTGPT_REPO"
else
    echo "[OK] PentestGPT-MCP already cloned."
fi

# ---- Ensure Python 3.11 ----
PY311_READY=1

if command -v python3.11 &> /dev/null; then
    echo "[OK] python3.11 already installed."
else
    echo "[+] Installing python3.11 via deadsnakes PPA..."
    if ! command -v add-apt-repository &> /dev/null; then
        sudo apt install -y software-properties-common
    fi
    if sudo add-apt-repository -y ppa:deadsnakes/ppa && \
       sudo apt update && \
       sudo apt install -y python3.11 python3.11-venv python3.11-dev; then
        echo "[OK] python3.11 installed."
    else
        echo "[!] Could not install python3.11."
        echo "    PentestGPT-MCP setup will be SKIPPED."
        PY311_READY=0
    fi
fi

if [ "$PY311_READY" -eq 1 ]; then
    # Recreate venv if it used the wrong Python
    if [ -d "$PENTESTGPT_REPO/venv" ]; then
        VENV_PY_VERSION="$("$PENTESTGPT_REPO/venv/bin/python3" --version 2>/dev/null || echo "unknown")"
        if [[ "$VENV_PY_VERSION" != *"3.11"* ]]; then
            echo "[!] Existing venv uses $VENV_PY_VERSION. Recreating..."
            rm -rf "$PENTESTGPT_REPO/venv"
        fi
    fi

    if [ ! -d "$PENTESTGPT_REPO/venv" ]; then
        python3.11 -m venv "$PENTESTGPT_REPO/venv"
    fi

    echo "[+] Installing PentestGPT-MCP deps..."
    "$PENTESTGPT_REPO/venv/bin/pip" install --upgrade pip
    "$PENTESTGPT_REPO/venv/bin/pip" install -r "$PENTESTGPT_REPO/requirements.txt"

    if [ ! -f "$PENTEST_TOOLS_SCRIPT" ]; then
        echo "[!] ERROR: pentest_tools_server.py not found."
    else
        echo "[OK] PentestGPT server script found."
    fi
else
    echo "[SKIP] PentestGPT-MCP setup incomplete."
fi

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
echo "--------------------------------------------------------"
echo "Shell PATH check"
echo "--------------------------------------------------------"
if echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo "[OK] ~/.local/bin is already on PATH."
else
    echo "[!] ~/.local/bin is NOT on PATH."
    echo "    Run this once, then open a new terminal:"
    echo ""
    echo "      echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "      source ~/.bashrc"
fi
echo ""
echo "--------------------------------------------------------"
echo "MANUAL STEPS — run these in separate terminals each session:"
echo "--------------------------------------------------------"
echo ""
echo "  1. Metasploit RPC daemon:"
echo "       msfrpcd -P yourpassword -p 55553 -n"
echo ""
echo "  2. HexStrike Flask API backend:"
echo "       python3 $HEXSTRIKE_API_REPO/hexstrike_server.py"
echo ""
echo "  3. PentestGPT: nothing to start (nmap/dirb are on PATH)."
echo ""
echo "Then run:"
echo "    python3 verify_mcp.py"
echo "    python3 run_agent.py"