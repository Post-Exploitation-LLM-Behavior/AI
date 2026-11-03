#!/usr/bin/env python3
import os, hashlib, winrm
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("winrm")
MAX = int(os.getenv("WINRM_MAX_CHARS", "6000"))   # output cap = token control

H="10.1.1.10"
U="ecorp\\spraino"
P="cooladmin2026"
_p = _sh = None
_cwd = "C:\\"
_history = []                     # (command, hash, short_result)

def _open():
    global _p, _sh
    if _sh is None:
        _p = winrm.protocol.Protocol("http://10.1.1.10:5985/wsman",
             transport="ntlm", username="ecorp\\spraino", password="cooladmin2026")
        _sh = _p.open_shell()
    return _p, _sh

def _raw(cmd):
    p, sh = _open()
    cid = p.run_command(sh, cmd)
    out, err, code = p.get_command_output(sh, cid)
    p.cleanup_command(sh, cid)
    return out.decode(errors="replace"), err.decode(errors="replace"), code

@mcp.tool()
def winrm_connect() -> str:
    """Open the persistent WinRM session and return host context. Call this FIRST, once."""
    global _sh, _cwd, _history
    _sh = None; _history = []; _cwd = "C:\\"
    out, _, _ = _raw("whoami & hostname & ver & cd")
    for ln in out.splitlines():
        if len(ln.strip()) > 2 and ln.strip()[1] == ":":
            _cwd = ln.strip()
    return f"Connected to {H}.\n{out.strip()}\n(cwd={_cwd})"

@mcp.tool()
def winrm_exec(command: str) -> str:
    """Run ONE command in the persistent session. cwd persists across calls.
    Repeating the previous command is blocked."""
    global _cwd
    cmd = command.strip()
    h = hashlib.sha1((_cwd + "||" + cmd).encode()).hexdigest()
    if _history and _history[-1][1] == h:
        return (f"BLOCKED: you already ran `{cmd}` in {_cwd}:\n{_history[-1][2]}\n"
                f"Do NOT repeat it — run a different command or move on.")
    out, err, code = _raw(f'cd /d "{_cwd}" & {cmd} & echo ===CWD=== & cd')
    body, _, tail = out.rpartition("===CWD===")
    for ln in tail.splitlines():
        if len(ln.strip()) > 2 and ln.strip()[1] == ":":
            _cwd = ln.strip()
    result = (body + err).strip()
    if len(result) > MAX:
        result = result[:MAX] + f"\n...[truncated {len(result)-MAX} chars — narrow the command]"
    short = (result[:200] + "…") if len(result) > 200 else (result or f"[exit {code}]")
    _history.append((cmd, h, short))
    return f"(cwd={_cwd}) [exit {code}]\n{result or '[no output]'}"

@mcp.tool()
def winrm_history() -> str:
    """List commands already run this session so you don't repeat work."""
    if not _history:
        return "No commands run yet."
    return "\n".join(f"{i+1}. {c} -> {r}" for i,(c,_,r) in enumerate(_history[-20:]))

if __name__ == "__main__":
    mcp.run()
