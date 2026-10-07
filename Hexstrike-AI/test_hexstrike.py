#!/usr/bin/env python3
# test_hexstrike.py — Direct HexStrike MCP server test (no LLM involved)
"""
Spawns the HexStrike MCP bridge, lists its tools,
and calls a harmless tool to verify the bridge-to-API connection works.

Requires the HexStrike Flask API to be running on localhost:8888.
"""

import asyncio
import os
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


# ------------------------------------------------------------------
# Paths. Adjust if your layout differs.
# ------------------------------------------------------------------
HEXSTRIKE_MCP_SERVER = Path.home() / "Desktop" / "AI" / "hexstrike_mcp_server.py"
HEXSTRIKE_API_URL = "http://localhost:8888"


async def main():
    print(f"[debug] MCP server script: {HEXSTRIKE_MCP_SERVER}")
    print(f"[debug] Server exists:     {HEXSTRIKE_MCP_SERVER.is_file()}")
    print(f"[debug] API URL:           {HEXSTRIKE_API_URL}")

    if not HEXSTRIKE_MCP_SERVER.is_file():
        print("[FAIL] HexStrike MCP server script not found.")
        sys.exit(1)

    # The bridge runs on system python3 (its deps are installed there).
    server_command = "python3"

    server_params = StdioServerParameters(
        command=server_command,
        args=[
            str(HEXSTRIKE_MCP_SERVER),
            "--host", "0.0.0.0",
            "--port", "8889",
            "--api-url", HEXSTRIKE_API_URL,
        ],
        env={**os.environ},
    )

    print()
    print("[+] Spawning HexStrike MCP bridge...")

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("[OK] Session initialized.")

            tools_response = await session.list_tools()
            tool_names = [t.name for t in tools_response.tools]
            print(f"[OK] Available tools: {tool_names}")

            if not tool_names:
                print("[FAIL] No tools exposed by the server.")
                sys.exit(1)

            print()
            print("=== Tool schemas ===")
            for t in tools_response.tools:
                print(f"\n{t.name}")
                print(f"  description: {t.description}")
                print(f"  input schema: {t.input_schema}")
            print("=== end of schemas ===")

            # Look for a harmless tool. HexStrike typically exposes
            # a health check or version tool. We look for names containing
            # 'health' or 'version' first, then fall back to 'nmap'.
            harmless = None
            for t in tools_response.tools:
                name_lower = t.name.lower()
                if "health" in name_lower or "version" in name_lower:
                    harmless = t.name
                    break

            if harmless is None:
                print()
                print("[WARN] No 'health' or 'version' tool found.")
                print("       Available tools:")
                for name in tool_names:
                    print(f"  - {name}")
                print()
                print("       If the API isn't running, the bridge may only")
                print("       expose a subset of tools. Start it with:")
                print("         ./hexstrike-ai/venv/bin/python3 hexstrike-ai/hexstrike_server.py")
                sys.exit(0)

            print()
            print(f"[+] Calling {harmless}...")
            try:
                result = await session.call_tool(harmless, {})
            except Exception as e:
                print()
                print(f"[FAIL] Tool call raised an exception: {e}")
                print("       If it mentions 'connection refused' or 'port 8888',")
                print("       the HexStrike Flask API isn't running.")
                sys.exit(1)

            output_text = "".join(
                c.text for c in result.content if hasattr(c, "text")
            )

            print()
            print(f"=== {harmless} result ===")
            print(output_text[:2000])
            print("=== end of result ===")
            print()
            print(f"[OK] {harmless} call succeeded.")


if __name__ == "__main__":
    asyncio.run(main())