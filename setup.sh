#!/bin/bash
set -e

ROOT="$(pwd)"

echo "=== Setting up all three MCPs ==="

# ============================================================
# 0. System build dependencies
# ============================================================
echo ""
echo "----------------------------------------"
echo " Installing system build dependencies"
echo "----------------------------------------"

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
# 2. HexStrike MCP bridge — system-wide (light deps)
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: HexStrike MCP bridge"
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

echo "[+] Installing HexStrike MCP bridge deps system-wide..."
python3 -m pip install --break-system-packages requests fastmcp

if ! python3 -c "import fastmcp, requests" 2>/dev/null; then
    echo "[!] fastmcp or requests failed to import."
    exit 1
fi
echo "[OK] fastmcp and requests importable."

# ============================================================
# 3. HexStrike Flask API backend — venv on Python 3.11, in background
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: HexStrike Flask API backend"
echo "----------------------------------------"

HEXSTRIKE_API_REPO="$ROOT/hexstrike-ai"
HEXSTRIKE_VENV="$HEXSTRIKE_API_REPO/venv"
HEXSTRIKE_INSTALL_LOG="$ROOT/hexstrike-install.log"

if [ ! -d "$HEXSTRIKE_API_REPO" ]; then
    echo "[+] Cloning HexStrike Flask API backend..."
    git clone https://github.com/0x4m4/hexstrike-ai.git "$HEXSTRIKE_API_REPO"
else
    echo "[OK] HexStrike Flask API repo already present."
fi

if [ ! -f "$HEXSTRIKE_API_REPO/hexstrike_server.py" ]; then
    echo "[!] WARNING: hexstrike_server.py not found in $HEXSTRIKE_API_REPO"
fi

# Ensure Python 3.11 exists (needed for HexStrike API wheels)
PY311_FOR_HS=1
if ! command -v python3.11 &> /dev/null; then
    echo "[+] Installing python3.11 for HexStrike venv..."
    if ! command -v add-apt-repository &> /dev/null; then
        sudo apt install -y software-properties-common
    fi
    if sudo add-apt-repository -y ppa:deadsnakes/ppa && \
       sudo apt update && \
       sudo apt install -y python3.11 python3.11-venv python3.11-dev; then
        echo "[OK] python3.11 installed."
    else
        echo "[!] python3.11 install failed. HexStrike API setup will be SKIPPED."
        PY311_FOR_HS=0
    fi
fi

if [ "$PY311_FOR_HS" -eq 1 ]; then
    if [ ! -d "$HEXSTRIKE_VENV" ]; then
        echo "[+] Creating HexStrike API venv with Python 3.11..."
        python3.11 -m venv "$HEXSTRIKE_VENV"
    else
        echo "[OK] HexStrike API venv already exists."
    fi

    if [ -f "$HEXSTRIKE_API_REPO/requirements.txt" ]; then
        echo "[+] Launching HexStrike API dependency install in background..."
        echo "    Log: $HEXSTRIKE_INSTALL_LOG"

        # Sequential: upgrade pip first, then install requirements
        nohup bash -c "
            '$HEXSTRIKE_VENV/bin/pip' install --upgrade pip setuptools wheel && \
            '$HEXSTRIKE_VENV/bin/pip' install -r '$HEXSTRIKE_API_REPO/requirements.txt'
        " > "$HEXSTRIKE_INSTALL_LOG" 2>&1 &

        echo $! > "$ROOT/.hexstrike-install.pid"
        echo "[OK] Background install started (PID $!)."
        echo "    Monitor with: tail -f $HEXSTRIKE_INSTALL_LOG"
    else
        echo "[!] No requirements.txt in $HEXSTRIKE_API_REPO"
    fi
fi

# ============================================================
# 4. PentestGPT MCP — Python 3.11 venv, gpt4all filtered out
# ============================================================
echo ""
echo "----------------------------------------"
echo " Setting up: PentestGPT MCP"
echo "----------------------------------------"

PENTESTGPT_REPO="$ROOT/PentestGPT-MCP"
PENTEST_TOOLS_SCRIPT="$PENTESTGPT_REPO/mcp_servers/pentest_tools_server.py"

if ! command -v nmap &> /dev/null || ! command -v dirb &> /dev/null; then
    echo "[+] Installing nmap and dirb..."
    sudo apt install -y nmap dirb
else
    echo "[OK] nmap and dirb already installed."
fi

if [ ! -d "$PENTESTGPT_REPO" ]; then
    echo "[+] Cloning PentestGPT-MCP..."
    git clone https://github.com/yuhano/PentestGPT-MCP.git "$PENTESTGPT_REPO"
else
    echo "[OK] PentestGPT-MCP already cloned."
fi

PY311_READY=1

if ! command -v python3.11 &> /dev/null; then
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
        PY311_READY=0
    fi
else
    echo "[OK] python3.11 already installed."
fi

if [ "$PY311_READY" -eq 1 ]; then
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

    echo "[+] Installing PentestGPT-MCP deps (skipping gpt4all)..."
    REQS="$PENTESTGPT_REPO/requirements.txt"
    FILTERED_REQS="$(mktemp)"
    grep -v -E '^\s*gpt4all' "$REQS" > "$FILTERED_REQS"

    "$PENTESTGPT_REPO/venv/bin/pip" install --upgrade pip setuptools wheel
    "$PENTESTGPT_REPO/venv/bin/pip" install -r "$FILTERED_REQS"

    rm -f "$FILTERED_REQS"

    if [ ! -f "$PENTEST_TOOLS_SCRIPT" ]; then
        echo "[!] ERROR: pentest_tools_server.py not found."
    else
        echo "[OK] PentestGPT server script found."
    fi
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Setup Complete ==="
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
echo "HexStrike Flask API install status:"
echo "--------------------------------------------------------"
echo "  The API backend deps are installing in the background."
echo "  Log:        $HEXSTRIKE_INSTALL_LOG"
echo "  Monitor:    tail -f $HEXSTRIKE_INSTALL_LOG"
echo "  Check done: grep -q 'Successfully installed' $HEXSTRIKE_INSTALL_LOG && echo done"
echo ""
echo "  Once the log shows completion, start the API with:"
echo "    $HEXSTRIKE_VENV/bin/python3 $HEXSTRIKE_API_REPO/hexstrike_server.py"
echo ""
echo "--------------------------------------------------------"
echo "Shell PATH check"
echo "--------------------------------------------------------"
if echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo "[OK] ~/.local/bin is already on PATH."
else
    echo "[!] ~/.local/bin is NOT on PATH. Run:"
    echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "    source ~/.bashrc"
fi
echo ""
echo "--------------------------------------------------------"
echo "MANUAL STEPS each session:"
echo "--------------------------------------------------------"
echo ""
echo "  1. msfrpcd -P yourpassword -p 55553 -n"
echo ""
echo "  2. $HEXSTRIKE_VENV/bin/python3 $HEXSTRIKE_API_REPO/hexstrike_server.py"
echo ""
echo "  3. Then: python3 verify_mcp.py && python3 run_agent.py"