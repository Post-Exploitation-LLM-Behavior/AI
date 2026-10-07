#!/usr/bin/env python3
# test_mcp.py — Direct MCP server test (no LLM involved)
"""
Connects to the PentestGPT MCP server, lists its tools and their schemas,
then calls nmap_scan against localhost to verify the tool works.
"""

import asyncio
import os
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


# ------------------------------------------------------------------
# Locate the PentestGPT MCP server script.
# Adjust this path if your repo layout is different.
# ------------------------------------------------------------------
PENTESTGPT_SERVER = Path.home() / "Desktop" / "AI" / "PentestGPT-MCP" / "mcp_servers" / "pentest_tools_server.py"
PENTESTGPT_VENV_PYTHON = Path.home() / "Desktop" / "AI" / "PentestGPT-MCP" / "venv" / "bin" / "python3"


async def main():
    print(f"[debug] Server script:  {PENTESTGPT_SERVER}")
    print(f"[debug] Server exists:  {PENTESTGPT_SERVER.is_file()}")
    print(f"[debug] Venv python:    {PENTESTGPT_VENV_PYTHON}")
    print(f"[debug] Venv exists:    {PENTESTGPT_VENV_PYTHON.is_file()}")

    if not PENTESTGPT_SERVER.is_file():
        print("[FAIL] PentestGPT server script not found.")
        sys.exit(1)

    # Use the venv python if it exists; otherwise fall back to system python3
    server_command = str(PENTESTGPT_VENV_PYTHON) if PENTESTGPT_VENV_PYTHON.is_file() else "python3"

    server_params = StdioServerParameters(
        command=server_command,
        args=[str(PENTESTGPT_SERVER)],
        env={**os.environ},
    )

    print()
    print("[+] Spawning PentestGPT MCP server...")

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("[OK] Session initialized.")

            # List available tools and print each one's schema
            tools_response = await session.list_tools()
            tool_names = [t.name for t in tools_response.tools]
            print(f"[OK] Available tools: {tool_names}")

            print()
            print("=== Tool schemas ===")
            for t in tools_response.tools:
                print(f"\n{t.name}")
                print(f"  description: {t.description}")
                print(f"  input schema: {t.input_schema}")
            print("=== end of schemas ===")

            if "nmap_scan" not in tool_names:
                print("[FAIL] nmap_scan not found in the tool list.")
                sys.exit(1)

            # Call nmap_scan against localhost (harmless).
            # Argument name is `targets` (plural), and it must be a list.
            print()
            print("[+] Calling nmap_scan on 127.0.0.1...")
            result = await session.call_tool(
                "nmap_scan",
                {"targets": "127.0.0.1"},
            )

            # Print the tool's output
            output_text = "".join(
                c.text for c in result.content if hasattr(c, "text")
            )

            print()
            print("=== nmap_scan result ===")
            print(output_text[:2000])  # truncate for readability
            print("=== end of result ===")
            print()
            print("[OK] nmap_scan call succeeded.")


if __name__ == "__main__":
    asyncio.run(main())