# test_tool_pickup.py
import asyncio
import json
import os
from dotenv import load_dotenv
from openai import AsyncOpenAI

load_dotenv()

async def main():
    client = AsyncOpenAI(
        base_url=os.getenv("GENAI_BASE_URL"),
        api_key=os.getenv("GENAI_API_KEY"),
    )

    # A single dummy tool the model should recognize
    tools = [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather for a city",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City name"}
                },
                "required": ["city"]
            }
        }
    }]

    response = await client.chat.completions.create(
        model="llama3.1:70b",  # same model as run_agent.py
        messages=[{"role": "user", "content": "What's the weather in Boston?"}],
        tools=tools,
        tool_choice="auto",
    )

    msg = response.choices[0].message
    print("Content:", msg.content)
    print("Tool calls:", msg.tool_calls)

    if msg.tool_calls:
        print("\n[OK] Gateway recognized the tool and selected it.")
        print("Tool name:", msg.tool_calls[0].function.name)
        print("Arguments:", msg.tool_calls[0].function.arguments)
    else:
        print("\n[FAIL] Gateway did not select a tool.")

asyncio.run(main())