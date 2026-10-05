#!/bin/bash
set -e

ROOT="$(pwd)"

echo "=== Setting up all three MCPs ==="

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
# PentestGPT MCP — needs Python 3.11
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
    sudo apt update && sudo apt install -y nmap dirb
else
    echo "[OK] nmap and dirb already installed."
fi

# ---- Clone the repo ----
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

# ---- Ensure Python 3.11 is available ----
ensure_python311() {
    # Already available?
    if command -v python3.11 &> /dev/null; then
        echo "[OK] python3.11 already installed."
        return 0
    fi

    echo "[+] python3.11 not found. Installing via deadsnakes PPA..."

    # software-properties-common provides add-apt-repository
    if ! command -v add-apt-repository &> /dev/null; then
        echo "[+] Installing software-properties-common..."
        sudo apt update && sudo apt install -y software-properties-common
    fi

    echo "[+] Adding deadsnakes PPA..."
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update

    echo "[+] Installing python3.11, python3.11-venv, python3.11-dev..."
    if ! sudo apt install -y python3.11 python3.11-venv python3.11-dev; then
        echo "[!] deadsnakes install failed."
        echo "    Your Ubuntu release may not be supported by deadsnakes yet."
        echo "    Alternative: install pyenv and its build dependencies, then:"
        echo "      sudo apt install -y make build-essential libssl-dev zlib1g-dev \\"
        echo "        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \\"
        echo "        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \\"
        echo "        libffi-dev liblzma-dev"
        echo "      curl https://pyenv.run | bash"
        echo "      pyenv install 3.11.9"
        exit 1
    fi

    if ! command -v python3.11 &> /dev/null; then
        echo "[!] python3.11 still not on PATH after install."
        exit 1
    fi
    echo "[OK] python3.11 installed."
}

ensure_python311

# ---- Clean up any failed pyenv build artifacts ----
if [ -d /tmp ] && ls /tmp/python-build.* 1> /dev/null 2>&1; then
    echo "[+] Removing stale pyenv build artifacts..."
    rm -rf /tmp/python-build.*
fi

# ---- Create or recreate the venv with Python 3.11 ----
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
    python3.11 -m venv "$PENTESTGPT_REPO/venv"
else
    echo "[OK] PentestGPT-MCP venv already uses Python 3.11."
fi

# ---- Install requirements (gpt4all now installable on 3.11) ----
echo "[+] Installing PentestGPT-MCP deps..."
"$PENTESTGPT_REPO/venv/bin/pip" install --upgrade pip
"$PENTESTGPT_REPO/venv/bin/pip" install -r "$PENTESTGPT_REPO/requirements.txt"

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