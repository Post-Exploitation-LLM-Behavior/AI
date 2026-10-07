#!/bin/bash
set -e

ROOT="$(pwd)"

echo "=== Setting up: Metasploit MCP ==="

# ---- Build deps ----
if ! command -v pipx &> /dev/null; then
    echo "[+] Installing pipx..."
    sudo apt update
    sudo apt install -y pipx
    pipx ensurepath
fi

# ---- Metasploit Framework ----
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

# ---- MCP wrapper ----
echo "[+] Installing mcp-pymetasploit3 via pipx..."
pipx install mcp-pymetasploit3 --force

echo ""
echo "=== Metasploit MCP Setup Complete ==="
echo ""
echo "mcp_config.json entry:"
echo '  "metasploit": {'
echo '    "command": "mcp-pymetasploit3",'
echo '    "env": {}'
echo '  }'
echo ""
echo "Manual step (in a separate terminal, before running the agent):"
echo "  msfrpcd -P yourpassword -p 55553 -n"