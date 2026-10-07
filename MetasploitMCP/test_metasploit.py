#!/usr/bin/env python3
# test_metasploit.py — Direct Metasploit MCP server test (no LLM involved)
"""
Spawns the mcp-pymetasploit3 MCP server, lists its tools,
and calls a harmless version/status tool to verify the connection works.
"""

import asyncio
import os
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


# ------------------------------------------------------------------
# Command to launch the Metasploit MCP server.
# mcp-pymetasploit3 is installed via pipx, so it lives in ~/.local/bin
# (or a pipx venv). We try the PATH lookup first; the shell command
# "command -v" fallback below handles pipx installs.
# ------------------------------------------------------------------
METASPLOIT_COMMAND = "mcp-pymetasploit3"


async def main():
    print(f"[debug] Launch command: {METASPLOIT_COMMAND}")

    server_params = StdioServerParameters(
        command=METASPLOIT_COMMAND,
        args=[],
        env={**os.environ},
    )

    print()
    print("[+] Spawning Metasploit MCP server...")

    try:
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

                # Pick a harmless tool to call.
                # mcp-pymetasploit3 typically exposes a "get_version" or
                # "list_sessions" tool that doesn't require a target.
                # We pick the first tool whose name contains 'version'.
                version_tool = None
                for name in tool_names:
                    if "version" in name.lower():
                        version_tool = name
                        break

                if version_tool is None:
                    print()
                    print("[WARN] No 'version' tool found. Available tools:")
                    for name in tool_names:
                        print(f"  - {name}")
                    print("Edit this script to call one of them manually.")
                    sys.exit(0)

                print()
                print(f"[+] Calling {version_tool}...")
                result = await session.call_tool(version_tool, {})

                output_text = "".join(
                    c.text for c in result.content if hasattr(c, "text")
                )

                print()
                print(f"=== {version_tool} result ===")
                print(output_text[:2000])
                print("=== end of result ===")
                print()
                print(f"[OK] {version_tool} call succeeded.")

    except FileNotFoundError:
        print()
        print(f"[FAIL] Command not found: {METASPLOIT_COMMAND}")
        print("       Check that mcp-pymetasploit3 is installed via pipx:")
        print("         pipx list | grep mcp-pymetasploit3")
        print("       And that ~/.local/bin is on your PATH:")
        print("         echo $PATH")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())