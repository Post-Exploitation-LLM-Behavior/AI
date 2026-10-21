#!/usr/bin/env python3

import asyncio
import os
import json
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    print("[+] Loading config from mcp_config.json...")
    with open("mcp_config.json") as f:
        config = json.load(f)
    
    server_cfg = config["mcpServers"]["sliver-c2"]
    
    print("[+] Spawning Sliver C2 MCP...")
    server_params = StdioServerParameters(
        command=server_cfg["command"],
        args=server_cfg["args"],
        env={**os.environ},
    )

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            print("[+] Initializing session...")
            await session.initialize()
            print("[OK] Session initialized.")

            tools_response = await session.list_tools()
            tool_names = [t.name for t in tools_response.tools]
            
            print(f"[OK] {len(tool_names)} tools exposed:")
            for name in tool_names:
                print(f"     - {name}")

            if "sliver_version" in tool_names:
                print()
                print("[+] Calling sliver_version (tests connection to C2)...")
                try:
                    result = await session.call_tool("sliver_version", {})
                    output = "".join(
                        c.text for c in result.content if hasattr(c, "text")
                    )
                    print("=== Result ===")
                    print(output[:1500])
                    print("=== End ===")
                    print("[OK] Tool call succeeded. Connection to Sliver works!")
                except Exception as e:
                    print(f"[FAIL] Tool call failed: {e}")
                    print("Check your operator config and ensure the Sliver server is reachable.")
            else:
                print("[WARN] sliver_version not found.")

if __name__ == "__main__":
    asyncio.run(main())