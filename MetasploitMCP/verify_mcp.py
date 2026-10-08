#!/usr/bin/env python3
"""
verify_mcp.py — Standalone verification for all configured MCP servers.

Run this BEFORE run_agent.py to catch configuration issues early.
"""

import json
import os
import shutil
import socket
import sys
from pathlib import Path


def ok(msg):    print(f"[OK] {msg}")
def fail(msg):  print(f"[FAIL] {msg}")
def warn(msg):  print(f"[WARN] {msg}")


def check_file(path: str) -> bool:
    """Check that a file exists and is readable."""
    p = Path(path)
    if p.is_file():
        ok(f"File found: {path}")
        return True
    fail(f"File NOT found: {path}")
    return False


def check_command(cmd: str) -> bool:
    """Check that a command is available on PATH."""
    path = shutil.which(cmd)
    if path:
        ok(f"Command found: {cmd} -> {path}")
        return True
    fail(f"Command NOT found on PATH: {cmd}")
    return False


def check_port(host: str, port: int, label: str = "") -> bool:
    """Check that a TCP port is accepting connections."""
    label = label or f"{host}:{port}"
    try:
        with socket.create_connection((host, port), timeout=3):
            ok(f"Port open: {label}")
            return True
    except (ConnectionRefusedError, socket.timeout, OSError) as e:
        fail(f"Port closed or unreachable: {label} ({e})")
        return False

def load_config(path: str = "mcp_config.json") -> dict:
    """Load mcp_config.json."""
    if not os.path.exists(path):
        fail(f"Config file not found: {path}")
        sys.exit(1)
    with open(path, "r") as f:
        cfg = json.load(f)
    ok(f"Config loaded: {path}")
    return cfg


def verify():
    print("=" * 60)
    print(" MCP Environment Verification")
    print("=" * 60)
    print()

    results = []

    # ---- Config file ----
    print("[ Config ]")
    config = load_config()
    servers = config.get("mcpServers", {})
    ok(f"Configured MCP servers: {', '.join(servers.keys())}")

    # ---- Metasploit ----
    if "mcp-pymetasploit3" in servers:
        print("[ Metasploit MCP ]")
        results.append(("msfconsole", check_command("msfconsole")))
        results.append(("mcp-pymetasploit3", check_command("mcp-pymetasploit3")))
        results.append(("msfrpcd port 55553", check_port("127.0.0.1", 55553, "msfrpcd RPC")))
        print()

    # ---- Gateway ----
    base_url = os.getenv("GENAI_BASE_URL")
    api_key = os.getenv("GENAI_API_KEY")
    if base_url:
        print("[ Gateway ]")
        ok(f"GENAI_BASE_URL = {base_url}")
        if api_key:
            ok("GENAI_API_KEY is set (value hidden)")
        else:
            fail("GENAI_API_KEY is NOT set")
        print()

    # ---- Summary ----
    print("=" * 60)
    passed = sum(1 for _, v in results if v)
    total = len(results)
    print(f" Summary: {passed}/{total} checks passed")
    print("=" * 60)

    if passed < total:
        print()
        fail("Some checks failed. Fix them before running run_agent.py.")
        sys.exit(1)
    else:
        print()
        ok("All checks passed. You're ready to run run_agent.py.")


if __name__ == "__main__":
    verify()