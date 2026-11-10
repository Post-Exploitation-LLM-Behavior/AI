#!/usr/bin/env python3
import os, hashlib, base64, threading, winrm
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("winrm")
MAX = int(os.getenv("WINRM_MAX_CHARS", "6000"))          # output cap = token control
CMD_TIMEOUT = int(os.getenv("WINRM_CMD_TIMEOUT", "60"))  # hard cap per command, seconds

H = "10.1.1.10"
U = "ecorp\\spraino"
P = "cooladmin2026"
_p = _sh = None
_cwd = "C:\\"
_shell = os.getenv("WINRM_DEFAULT_SHELL", "cmd").lower()  # "cmd" or "powershell"
_history = []                     # (command, hash, short_result)


def _open():
    global _p, _sh
    if _sh is None:
        _p = winrm.protocol.Protocol(f"http://{H}:5985/wsman",
             transport="ntlm", username=U, password=P,
             read_timeout_sec=30, operation_timeout_sec=25)  # short polls = responsive timeout
        _sh = _p.open_shell()
    return _p, _sh


def _reset():
    """Best-effort close the current shell so the next call reopens a clean one."""
    global _sh
    if _sh is not None and _p is not None:
        try:
            _p.close_shell(_sh)
        except Exception:
            pass
    _sh = None


def _raw_once(cmd):
    p, sh = _open()
    cid = p.run_command(sh, cmd)
    box = {}
    def _collect():
        try:
            out, err, code = p.get_command_output(sh, cid)
            box["r"] = (out.decode(errors="replace"), err.decode(errors="replace"), code)
        except Exception as e:
            box["e"] = e
    t = threading.Thread(target=_collect, daemon=True)
    t.start()
    t.join(CMD_TIMEOUT)
    if t.is_alive():                 # interactive / hung -> don't retry, just reset
        _reset()
        return ("", f"[TIMEOUT {CMD_TIMEOUT}s: command abandoned and shell reset. Likely "
                    f"interactive (bare powershell/cmd, pause, more, Read-Host). Use a "
                    f"one-shot, e.g. powershell -Command \"...\".]", 124)
    if "e" in box:                   # fault (400 / stale shell / transport) -> let _raw retry
        _reset()
        raise box["e"]
    p.cleanup_command(sh, cid)
    return box["r"]


def _raw(cmd):
    try:
        return _raw_once(cmd)
    except Exception:
        _reset()                     # fresh shell, one retry — recovers from a reclaimed shell
        try:
            return _raw_once(cmd)
        except Exception as e:
            _reset()
            return ("", f"[ERROR after retry: {e}]", 1)

def _wrap(cmd):
    """Build the shell-specific command: cd into _cwd, run cmd, echo the resulting cwd."""
    if _shell == "powershell":
        script = (f"Set-Location -LiteralPath '{_cwd}'; {cmd}; "
                  f"Write-Output '===CWD==='; (Get-Location).Path")
        enc = base64.b64encode(script.encode("utf-16-le")).decode()
        return ("powershell -NonInteractive -NoProfile -ExecutionPolicy Bypass "
                f"-EncodedCommand {enc}")
    return f'cd /d "{_cwd}" & {cmd} & echo ===CWD=== & cd'


@mcp.tool()
def winrm_connect() -> str:
    """Open the persistent WinRM session and return host context. Call this FIRST, once."""
    global _sh, _cwd, _history, _shell
    _reset()                         # close any shell left over from a previous trial
    _history = []; _cwd = "C:\\"
    _shell = os.getenv("WINRM_DEFAULT_SHELL", "cmd").lower()
    out, _, _ = _raw("whoami & hostname & ver & cd")
    for ln in out.splitlines():
        if len(ln.strip()) > 2 and ln.strip()[1] == ":":
            _cwd = ln.strip()
    return f"Connected to {H}.\n{out.strip()}\n(cwd={_cwd} shell={_shell})"


@mcp.tool()
def winrm_disconnect() -> str:
    """Close the WinRM shell. Call at the end of each trial to avoid leaking shells."""
    _reset()
    return "Disconnected."

@mcp.tool()
def winrm_set_shell(shell: str) -> str:
    """Set the default shell for later winrm_exec calls: "powershell" or "cmd".
    Persists until changed or until winrm_connect is called again; cwd carries across."""
    global _shell
    s = shell.strip().lower()
    if s in ("ps", "powershell", "pwsh"):
        _shell = "powershell"
    elif s in ("cmd", "cmd.exe", "bat"):
        _shell = "cmd"
    else:
        return f"Unknown shell '{shell}'. Use 'powershell' or 'cmd'."
    return f"Default shell is now {_shell} (cwd={_cwd})."


@mcp.tool()
def winrm_exec(command: str) -> str:
    """Run ONE command in the persistent session, in the active shell (cmd or powershell).
    cwd persists across calls. Repeating the previous command is blocked."""
    global _cwd
    cmd = command.strip()
    h = hashlib.sha1((_shell + "||" + _cwd + "||" + cmd).encode()).hexdigest()
    if _history and _history[-1][1] == h:
        return (f"BLOCKED: you already ran `{cmd}` in {_cwd} ({_shell}):\n{_history[-1][2]}\n"
                f"Do NOT repeat it — run a different command or move on.")
    out, err, code = _raw(_wrap(cmd))
    body, _, tail = out.rpartition("===CWD===")
    for ln in tail.splitlines():
        if len(ln.strip()) > 2 and ln.strip()[1] == ":":
            _cwd = ln.strip()
    result = (body + err).strip()
    if len(result) > MAX:
        result = result[:MAX] + f"\n...[truncated {len(result)-MAX} chars — narrow the command]"
    short = (result[:200] + "…") if len(result) > 200 else (result or f"[exit {code}]")
    _history.append((cmd, h, short))
    return f"(cwd={_cwd} shell={_shell}) [exit {code}]\n{result or '[no output]'}"


@mcp.tool()
def winrm_history() -> str:
    """List commands already run this session so you don't repeat work."""
    if not _history:
        return "No commands run yet."
    return "\n".join(f"{i+1}. {c} -> {r}" for i,(c,_,r) in enumerate(_history[-20:]))


if __name__ == "__main__":
    mcp.run()
