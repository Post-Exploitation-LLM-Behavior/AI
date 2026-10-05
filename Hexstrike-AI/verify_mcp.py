#!/usr/bin/env python3
"""Verify the HexStrike MCP environment."""

import json
import os
import socket
import sys
from pathlib import Path


def ok(msg):    print(f"[OK] {msg}")
def fail(msg):  print(f"[FAIL] {msg}")
def warn(msg):  print(f"[WARN] {msg}")


def check_file(path: str) -> bool:
    if Path(path).is_file():
        ok(f"File found: {path}")
        return True
    fail(f"File NOT found: {path}")
    return False


def check_port(host: str, port: int, label: str) -> bool:
    try:
        with socket.create_connection((host, port), timeout=3):
            ok(f"Port open: {label}")
            return True
    except (ConnectionRefusedError, socket.timeout, OSError) as e:
        fail(f"Port closed: {label} ({e})")
        return False


def load_config(path="mcp_config.json") -> dict:
    if not os.path.exists(path):
        fail(f"Config not found: {path}")
        sys.exit(1)
    with open(path) as f:
        cfg = json.load(f)
    ok(f"Config loaded: {path}")
    return cfg


def verify():
    print("=" * 60)
    print(" HexStrike MCP Verification")
    print("=" * 60)

    results = []

    config = load_config()
    servers = config.get("mcpServers", {})
    ok(f"Configured servers: {', '.join(servers.keys())}")

    if "hexstrike" not in servers:
        fail("'hexstrike' not in mcp_config.json")
        results.append(("config entry", False))
    else:
        results.append(("config entry", True))

    cfg = servers.get("hexstrike", {})
    args = cfg.get("args", [])
    script = next((a for a in args if isinstance(a, str) and a.endswith(".py")), None)

    if script:
        results.append(("hexstrike_mcp_server.py", check_file(script)))
    else:
        warn("No .py script found in hexstrike args")
        results.append(("hexstrike_mcp_server.py", False))

    # MCP bridge port and Flask backend port
    results.append(("HexStrike MCP bridge :8889", check_port("127.0.0.1", 8889, "hexstrike MCP bridge")))
    results.append(("HexStrike Flask API :8888", check_port("127.0.0.1", 8888, "hexstrike Flask API")))

    print("=" * 60)
    passed = sum(1 for _, v in results if v)
    total = len(results)
    print(f" Summary: {passed}/{total} checks passed")
    print("=" * 60)

    if passed < total:
        sys.exit(1)
    print("[OK] Ready.")


if __name__ == "__main__":
    verify()