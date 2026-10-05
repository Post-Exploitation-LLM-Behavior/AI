#!/bin/bash
set -e

echo "=== Metasploit MCP Setup ==="

# 1. Install Metasploit Framework if missing
if ! command -v msfconsole &> /dev/null; then
    echo "[+] Installing Metasploit via official Rapid7 installer..."
    curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod 755 /tmp/msfinstall
    sudo /tmp/msfinstall
else
    echo "[OK] Metasploit already installed."
fi

# 2. Install the Python MCP wrapper
echo "[+] Installing mcp-pymetasploit3..."
pip install mcp-pymetasploit3

# 3. Reminder
echo ""
echo "=== Setup Complete ==="
echo "Start the RPC daemon before running the agent:"
echo "    msfrpcd -P yourpassword -p 55553 -n"