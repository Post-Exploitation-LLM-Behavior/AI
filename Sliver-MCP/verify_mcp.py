#!/usr/bin/env python3
import json
import os
import shutil
import sys

def ok(msg):    print(f"[OK] {msg}")
def fail(msg):  print(f"[FAIL] {msg}")
def warn(msg):  print(f"[WARN] {msg}")

def verify():
    print("=" * 60)
    print(" Sliver C2 MCP Native Configuration Verification")
    print("=" * 60)

    path = "mcp_config.json"
    if not os.path.exists(path):
        fail(f"Config file not found: {path}")
        sys.exit(1)

    with open(path) as f:
        config = json.load(f)

    servers = config.get("mcpServers", {})
    if "sliver-c2" not in servers:
        fail("'sliver-c2' not found in mcp_config.json")
        sys.exit(1)
    ok("'sliver-c2' present in config")

    cfg = servers["sliver-c2"]
    args = cfg.get("args", [])

    # Check command
    if cfg.get("command") != "node":
        fail("Command should be 'node'")
        sys.exit(1)
    
    if shutil.which("node"):
        ok("Node.js found on PATH")
    else:
        fail("Node.js NOT found on PATH")
        sys.exit(1)

    # Check the compiled JS file
    js_file = args[0] if args else ""
    if os.path.exists(js_file):
        ok(f"Compiled MCP server found: {js_file}")
    else:
        fail(f"Compiled MCP server NOT found at: {js_file}")
        sys.exit(1)

    # Check operator config
    if "--operator-config" in args:
        idx = args.index("--operator-config")
        if idx + 1 < len(args):
            cfg_file = args[idx + 1]
            if os.path.exists(cfg_file):
                ok(f"Operator config found: {cfg_file}")
            else:
                fail(f"Operator config NOT found at: {cfg_file}")
                sys.exit(1)
        else:
            fail("--operator-config flag is missing its argument")
            sys.exit(1)
    else:
        fail("--operator-config flag not found in args")
        sys.exit(1)

    print()
    print("All checks passed. Sliver C2 MCP is configured correctly.")

if __name__ == "__main__":
    verify()