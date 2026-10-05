#!/usr/bin/env python3
"""Verify the Metasploit MCP environment."""

import json
import os
import shutil
import socket
import sys


def ok(msg):    print(f"[OK] {msg}")
def fail(msg):  print(f"[FAIL] {msg}")


def check_command(cmd: str) -> bool:
    path = shutil.which(cmd)
    if path:
        ok(f"Command found: {cmd} -> {path}")
        return True
    fail(f"Command NOT found: {cmd}")
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
    print(" Metasploit MCP Verification")
    print("=" * 60)

    results = []

    config = load_config()
    servers = config.get("mcpServers", {})
    ok(f"Configured servers: {', '.join(servers.keys())}")

    if "mcp-pymetasploit3" not in servers:
        fail("'mcp-pymetasploit3' not in mcp_config.json")
        results.append(("config entry", False))
    else:
        results.append(("config entry", True))

    results.append(("msfconsole", check_command("msfconsole")))
    results.append(("mcp-pymetasploit3", check_command("mcp-pymetasploit3")))
    results.append(("msfrpcd :55553", check_port("127.0.0.1", 55553, "msfrpcd RPC")))

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