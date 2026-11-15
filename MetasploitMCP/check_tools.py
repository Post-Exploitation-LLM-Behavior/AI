"""
Run with: source venv/bin/activate && python3 check_tools.py
Prints every tool name exposed by mcp-pymetasploit3 so we know
exactly what the LLM can call.
"""
import asyncio, json, os, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    with open("mcp_config.json") as f:
        config = json.load(f)

    for server_name, server_cfg in config["mcpServers"].items():
        params = StdioServerParameters(
            command=server_cfg["command"],
            args=server_cfg.get("args", []),
            env={**os.environ, **server_cfg.get("env", {})},
        )
        with open(os.devnull, "w") as devnull:
            async with stdio_client(params, errlog=devnull) as (r, w):
                async with ClientSession(r, w) as session:
                    await session.initialize()
                    tools = await session.list_tools()
                    print(f"\n=== {server_name} — {len(tools.tools)} tools ===")
                    for t in sorted(tools.tools, key=lambda x: x.name):
                        # Print name + first line of description
                        desc = (t.description or "").split("\n")[0][:60]
                        print(f"  {t.name:<35} {desc}")

asyncio.run(main())