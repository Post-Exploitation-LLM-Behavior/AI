#!/usr/bin/env python3
# test_tool_pickup.py
"""
Verifies that the GenAI gateway accepts a `tools` parameter and that the
configured model actually selects a tool in response to a matching prompt.

Run from anywhere:
    python3 test_tool_pickup.py
"""

import asyncio
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from openai import AsyncOpenAI


# ------------------------------------------------------------------
# Load .env from the same directory as this script (works regardless
# of the current working directory).
# ------------------------------------------------------------------
ENV_PATH = Path(__file__).resolve().parent / ".env"

print(f"[debug] Script directory: {Path(__file__).resolve().parent}")
print(f"[debug] Looking for .env at: {ENV_PATH}")
print(f"[debug] .env exists: {ENV_PATH.is_file()}")

if ENV_PATH.is_file():
    load_dotenv(dotenv_path=ENV_PATH)
else:
    # Fall back to default search (CWD and upward)
    print("[debug] .env not next to script; falling back to default load_dotenv()")
    load_dotenv()

base_url = os.getenv("GENAI_BASE_URL")
api_key = os.getenv("GENAI_API_KEY")

print(f"[debug] GENAI_BASE_URL = {base_url!r}")
print(f"[debug] GENAI_API_KEY is set: {bool(api_key)}")

if not base_url or not api_key:
    print()
    print("[FAIL] Missing GENAI_BASE_URL or GENAI_API_KEY.")
    print("       Check that .env exists next to this script and contains:")
    print("         GENAI_BASE_URL=https://...")
    print("         GENAI_API_KEY=sk-...")
    sys.exit(1)


# ------------------------------------------------------------------
# Main test
# ------------------------------------------------------------------
async def main():
    client = AsyncOpenAI(base_url=base_url, api_key=api_key)

    # A single dummy tool the model should recognize and call.
    tools = [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get the current weather for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "The name of the city"
                    }
                },
                "required": ["city"]
            }
        }
    }]

    print()
    print("[+] Sending tool-enabled request to the gateway...")

    response = await client.chat.completions.create(
        model="llama3.1:70b",
        messages=[
            {"role": "user", "content": "What's the weather in Boston?"}
        ],
        tools=tools,
        tool_choice="auto",
    )

    msg = response.choices[0].message

    print()
    print("=== Response ===")
    print(f"Content:    {msg.content!r}")
    print(f"Tool calls: {msg.tool_calls}")

    if msg.tool_calls:
        print()
        print("[OK] Gateway recognized the tool and the model selected it.")
        for tc in msg.tool_calls:
            print(f"  Tool:      {tc.function.name}")
            print(f"  Arguments: {tc.function.arguments}")
        return 0
    else:
        print()
        print("[FAIL] Model returned text without selecting a tool.")
        print("       Possible causes:")
        print("       - The gateway strips the `tools` parameter.")
        print("       - The model name doesn't support function calling on this gateway.")
        print("       - The prompt didn't strongly trigger the tool.")
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))