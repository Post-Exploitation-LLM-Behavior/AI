import asyncio
import json
import os
import time
from contextlib import AsyncExitStack
from dotenv import load_dotenv
from openai import AsyncOpenAI

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from prompts import AUTONOMOUS_PROMPT

load_dotenv()

genai_client = AsyncOpenAI(
    base_url=os.getenv("GENAI_BASE_URL"),
    api_key=os.getenv("GENAI_API_KEY"),
)


async def run_autonomous_agent(
    user_input: str,
    model_name: str,
    config_path: str = "mcp_config.json",
    max_runtime_hours: float = 3.0,
):
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Configuration file '{config_path}' not found.")

    with open(config_path, "r") as f:
        config = json.load(f)

    all_tools = []
    sessions = {}
    log_files = []

    async with AsyncExitStack() as stack:
        # Connect to each configured MCP server
        for server_name, server_cfg in config.get("mcpServers", {}).items():
            print(f"[+] Spawning MCP server: {server_name}")

            server_params = StdioServerParameters(
                command=server_cfg["command"],
                args=server_cfg.get("args", []),
                env={**os.environ, **server_cfg.get("env", {})},
            )

            # Redirect this server's stderr to a log file
            log_path = f"{server_name}_stderr.log"
            server_log = open(log_path, "a")
            log_files.append(server_log)
            print(f"    stderr -> {log_path}")

            read, write = await stack.enter_async_context(
                stdio_client(server_params, errlog=server_log)
            )
            session = await stack.enter_async_context(ClientSession(read, write))
            await session.initialize()

            sessions[server_name] = session

            # Aggregate tools from this server
            mcp_tools = await session.list_tools()
            for tool in mcp_tools.tools:
                all_tools.append({
                    "type": "function",
                    "function": {
                        "name": f"{server_name}__{tool.name}",
                        "description": tool.description,
                        "parameters": tool.inputSchema,
                    },
                })

        print(f"[+] Total aggregated tools: {len(all_tools)}")

        messages = [
            {"role": "system", "content": AUTONOMOUS_PROMPT},
            {"role": "user", "content": user_input},
        ]

        start_time = time.monotonic()
        deadline = start_time + (max_runtime_hours * 3600)

        while True:
            # 3-hour deadline check
            if time.monotonic() > deadline:
                elapsed_min = (time.monotonic() - start_time) / 60
                print(f"[!] Max runtime ({max_runtime_hours}h) exceeded after {elapsed_min:.1f} min.")
                return "Agent stopped: maximum runtime reached."

            response = await genai_client.chat.completions.create(
                model=model_name,
                messages=messages,
                tools=all_tools if all_tools else None,
                tool_choice="auto",
                parallel_tool_calls=False,
            )

            msg = response.choices[0].message
            messages.append(msg)

            # No tool calls -> model produced text
            if not msg.tool_calls:
                content = (msg.content or "").strip()

                # Early exit if model signals completion
                if "DONE" in content.upper():
                    elapsed_min = (time.monotonic() - start_time) / 60
                    print(f"[+] Agent signaled DONE after {elapsed_min:.1f} min.")
                    return content

                # Otherwise nudge it to continue
                messages.append({
                    "role": "user",
                    "content": (
                        "Continue with the next objective. "
                        "If all tasks are complete, respond with 'DONE'."
                    ),
                })
                continue

            # Process each requested tool call
            for tool_call in msg.tool_calls:
                full_tool_name = tool_call.function.name
                server_prefix, original_tool_name = full_tool_name.split("__", 1)

                try:
                    args = json.loads(tool_call.function.arguments)
                except json.JSONDecodeError as e:
                    output_text = f"ERROR: invalid JSON arguments: {e}"
                    print(f"[!] {output_text}")
                else:
                    print(f"-> [{server_prefix}] {original_tool_name}")
                    target_session = sessions[server_prefix]
                    try:
                        result = await target_session.call_tool(original_tool_name, args)
                        output_text = "".join(
                            c.text for c in result.content if hasattr(c, "text")
                        )
                    except Exception as e:
                        output_text = f"ERROR executing tool: {e}"
                        print(f"[!] {output_text}")

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": output_text,
                })

    # AsyncExitStack closes here; close log files
    for lf in log_files:
        try:
            lf.close()
        except Exception:
            pass


if __name__ == "__main__":
    # Options: "llama3.1:70b", "qwen3:latest", "devstral:latest", "gpt-oss:120b"
    MODEL = "llama3.1:70b"
    INPUT = "Initialize system status check using connected MCP tools."

    print(f"=== Starting MCP Session using {MODEL} ===")
    summary = asyncio.run(run_autonomous_agent(INPUT, model_name=MODEL))
    print("\n--- Output ---\n", summary)