"""DAP/Delve output parser — friendly streaming formatter."""

from __future__ import annotations
import json
import re
from dataclasses import dataclass
from typing import Optional, Dict

_TIMESTAMP_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+\-]\d{2}:\d{2}\s+debug\s+layer=dap\s+(.*)$"
)

_NOISY_REQ = frozenset(
    [
        "configurationDone",
        "continue",
        "initialize",
        "scopes",
        "setBreakpoints",
        "setExceptionBreakpoints",
        "stackTrace",
        "variables",
    ]
)
_NOISY_RESP = frozenset(
    [
        "configurationDone",
        "continue",
        "initialize",
        "scopes",
        "setExceptionBreakpoints",
        "variables",
    ]
)


@dataclass
class OutputItem:
    kind: str  # status|event|error|warn|program|protocol|detail|raw
    text: str
    raw: str


def _entry(kind: str, text: str, raw: str) -> OutputItem:
    return OutputItem(kind=kind, text=text, raw=raw)


def _short_path(path: str) -> str:
    if not path:
        return "?"
    path = path.replace("\\", "/")
    # Simplify: just take last 2 path components
    parts = path.rstrip("/").split("/")
    return "/".join(parts[-2:]) if len(parts) > 2 else path


def _brace_delta(text: str) -> int:
    return text.count("{") - text.count("}")


class OutputParser:
    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self._skip_block: Optional[str] = None
        self._block_depth: int = 0
        self._last_sig: Optional[str] = None
        self._repeat: int = 0

    # ── DAP payload ─────────────────────────────────────────────────────────────

    def _parse_dap(self, payload: str, raw: str) -> list[OutputItem]:
        try:
            msg: Dict = json.loads(payload)
        except json.JSONDecodeError:
            return [_entry("protocol", "DAP message (parse error)", raw)]

        t = msg.get("type")

        if t == "request":
            cmd = msg.get("command", "request")
            return (
                []
                if cmd in _NOISY_REQ
                else [_entry("protocol", f"DAP request: {cmd}", raw)]
            )

        if t == "response":
            cmd = msg.get("command", "response")
            if not msg.get("success"):
                text = msg.get("message") or f"DAP response failed: {cmd}"
                body = msg.get("body") or {}
                err = body.get("error") or {}
                if err.get("format"):
                    text = err["format"]
                return [_entry("error", text, raw)]
            if cmd in _NOISY_RESP:
                return []
            if cmd == "setBreakpoints":
                body = msg.get("body") or {}
                bps = body.get("breakpoints") or []
                verified = sum(1 for b in bps if b.get("verified"))
                return [
                    _entry("event", f"breakpoints accepted: {verified}/{len(bps)}", raw)
                ]
            return [_entry("protocol", f"DAP response: {cmd}", raw)]

        if t == "event":
            ev = msg.get("event", "event")
            body = msg.get("body") or {}
            if ev == "stopped":
                return [
                    _entry("event", f"stopped: {body.get('reason', 'stopped')}", raw)
                ]
            if ev == "process":
                name = _short_path(body.get("name", "?"))
                pid = body.get("systemProcessId", "?")
                return [_entry("event", f"process started: {name} (pid {pid})", raw)]
            if ev == "output":
                text = (body.get("output") or "").strip()
                return [_entry("program", text, raw)] if text else []
            return [_entry("protocol", f"DAP event: {ev}", raw)]

        return [_entry("raw", "unclassified DAP message", raw)]

    # ── dla log line ─────────────────────────────────────────────────────────────
    # require("custom.lazygit").setup()

    def _parse_dlv(self, message: str, raw: str) -> list[OutputItem]:
        # from client
        m = re.match(r"^\[<- from client\](.*)$", message)
        if m:
            return self._parse_dap(m.group(1), raw)

        m = re.match(r"^\[->\s*to client\](.*)$", message)
        if m:
            return self._parse_dap(m.group(1), raw)

        m = re.match(r"^DAP server listening at:\s*([\d.]+):(\d+)", message)
        if m:
            return [
                _entry("status", f"dlv listening on {m.group(1)}:{m.group(2)}", raw)
            ]

        m = re.match(r"^DAP server pid = (\d+)", message)
        if m:
            return [_entry("status", f"dlv server pid: {m.group(1)}", raw)]

        if re.match(r"^DAP connection \d+ started", message):
            return [_entry("status", "DAP client connected", raw)]

        if re.match(r"^parsed launch config:\s*\{", message):
            self._skip_block = "launch config"
            self._block_depth = max(1, _brace_delta(message))
            return [_entry("status", "launch config parsed", raw)]

        m = re.match(r'^building from "([^"]+)": \[(.*)\]$', message)
        if m:
            return [
                _entry(
                    "status", f"building debug binary in {_short_path(m.group(1))}", raw
                ),
                _entry("detail", m.group(2), raw),
            ]

        m = re.match(r"^launching binary '([^']+)' with config:\s*\{", message)
        if m:
            self._skip_block = "launch"
            self._block_depth = max(1, _brace_delta(message))
            return [
                _entry(
                    "status", f"launching debug binary: {_short_path(m.group(1))}", raw
                )
            ]

        m = re.match(
            r'"continue" command stopped - reason "([^"]+)", location (.+):(\d+)$',
            message,
        )
        if m:
            return [
                _entry(
                    "event",
                    f"stopped at {_short_path(m.group(2))}:{m.group(3)} ({m.group(1)})",
                    raw,
                )
            ]

        if message.startswith("Unable to produce stack trace:"):
            return [_entry("warn", message, raw)]

        if "error" in message.lower() or "failed" in message.lower():
            return [_entry("error", message, raw)]

        return [_entry("raw", message, raw)]

    # ── coalescing ───────────────────────────────────────────────────────────────

    def _coalesce(self, items: list[OutputItem]) -> list[OutputItem]:
        out: list[OutputItem] = []
        for item in items:
            sig = f"{item.kind}\n{item.text}"
            if sig == self._last_sig and out:
                self._repeat += 1
                out[-1].text = item.text + f" (x{self._repeat + 1})"
            else:
                self._last_sig = sig
                self._repeat = 0
                out.append(item)
        return out

    # ── public API ──────────────────────────────────────────────────────────────

    def parse_line(self, line: str) -> list[OutputItem]:
        raw = line
        text = line.strip()
        if not text:
            return []

        if self._skip_block:
            self._block_depth += _brace_delta(text)
            if self._block_depth <= 0:
                self._skip_block = None
                self._block_depth = 0
            return []

        m = _TIMESTAMP_RE.match(text)
        if m:
            return self._parse_dlv(m.group(1), raw)

        if text == "debug UI ready":
            return [_entry("status", "debug UI ready", raw)]
        if text.startswith("starting dlv dap in:"):
            d = text[len("starting dlv dap in:") :].strip()
            return [_entry("status", f"starting Delve in {_short_path(d)}", raw)]
        if text.startswith("connecting to dlv at"):
            return [_entry("status", text, raw)]
        if text == "connected":
            return [_entry("status", "connected to Delve", raw)]
        if re.match(r"^process .+ \(pid \d+\)$", text):
            return [_entry("event", text, raw)]
        if re.match(r"^\d+/\d+ BP verified", text):
            return [_entry("event", text.replace("BP", "breakpoint"), raw)]
        if text.startswith("[error]") or text.startswith("[DAP error]"):
            return [_entry("error", text, raw)]
        if text.startswith("[warn]"):
            return [_entry("warn", text, raw)]
        if text[:1] in ("●", "▶", "⏸", "■"):
            return [_entry("event", text, raw)]

        return [_entry("program", text, raw)]

    def parse(self, raw: str) -> list[OutputItem]:
        items: list[OutputItem] = []
        for line in raw.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
            items.extend(self.parse_line(line))
        return self._coalesce(items)
