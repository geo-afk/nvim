"""Async DAP session over TCP."""
from __future__ import annotations
import asyncio
import json
import logging
from typing import Callable, Optional, Any

log = logging.getLogger(__name__)

_CRLF = b"\r\n\r\n"


class DAPSession:
    def __init__(self, on_event: Callable, on_output: Callable, on_close: Callable) -> None:
        self._on_event = on_event    # (event_name, body) → None  [called in asyncio thread]
        self._on_output = on_output  # (text) → None
        self._on_close = on_close    # () → None
        self.seq: int = 1
        self._callbacks: dict[int, Callable] = {}
        self._buf: bytes = b""
        self._reader: Optional[asyncio.StreamReader] = None
        self._writer: Optional[asyncio.StreamWriter] = None
        self.closed: bool = False
        self.initialized: bool = False
        self.configured: bool = False
        self.connected: bool = False
        self.stopped_tid: Optional[int] = None
        self.current_fid: Optional[int] = None
        self.last_scope_ref: Optional[int] = None
        self.capabilities: dict = {}
        self._loop: Optional[asyncio.AbstractEventLoop] = None

    # ── connection ─────────────────────────────────────────────────────────────

    async def connect(self, host: str, port: int) -> None:
        self._reader, self._writer = await asyncio.open_connection(host, port)
        self.connected = True
        asyncio.ensure_future(self._read_loop())

    async def _read_loop(self) -> None:
        assert self._reader
        try:
            while not self.closed:
                data = await self._reader.read(8192)
                if not data:
                    break
                self._consume(data)
        except (asyncio.CancelledError, ConnectionResetError, BrokenPipeError):
            pass
        finally:
            if not self.closed:
                self._on_close()

    def _consume(self, data: bytes) -> None:
        self._buf += data
        while True:
            idx = self._buf.find(_CRLF)
            if idx < 0:
                break
            header = self._buf[:idx].decode(errors="replace")
            # find Content-Length
            cl: Optional[int] = None
            for part in header.split("\r\n"):
                k, _, v = part.partition(":")
                if k.strip().lower() == "content-length":
                    try:
                        cl = int(v.strip())
                    except ValueError:
                        pass
                    break
            if cl is None:
                self._buf = self._buf[idx + 4:]
                continue
            body_start = idx + 4
            if len(self._buf) < body_start + cl:
                break
            body = self._buf[body_start: body_start + cl]
            self._buf = self._buf[body_start + cl:]
            try:
                msg = json.loads(body.decode())
                self._dispatch(msg)
            except json.JSONDecodeError as e:
                self._on_output(f"[DAP parse error] {e}")

    # ── send / request ─────────────────────────────────────────────────────────

    def send(self, msg: dict) -> None:
        if self.closed or not self._writer:
            return
        encoded = json.dumps(msg).encode()
        header = f"Content-Length: {len(encoded)}\r\n\r\n".encode()
        self._writer.write(header + encoded)

    def request(self, command: str, args: Optional[dict] = None,
                callback: Optional[Callable] = None) -> int:
        if self.closed:
            return -1
        seq = self.seq
        self.seq += 1
        if callback:
            self._callbacks[seq] = callback
        self.send({"seq": seq, "type": "request", "command": command,
                   "arguments": args or {}})
        return seq

    # ── dispatch ───────────────────────────────────────────────────────────────

    def _dispatch(self, msg: dict) -> None:
        t = msg.get("type")
        if t == "response":
            seq = msg.get("request_seq")
            cb = self._callbacks.pop(seq, None)
            if cb:
                cb(msg)
            elif not msg.get("success"):
                text = msg.get("message") or "DAP error"
                body = msg.get("body") or {}
                err = (body.get("error") or {}).get("format")
                self._on_output(f"[DAP error] {text}" + (f": {err}" if err else ""))
        elif t == "event":
            self._on_event(msg.get("event", ""), msg.get("body") or {})

    # ── close ──────────────────────────────────────────────────────────────────

    def close(self) -> None:
        if self.closed:
            return
        self.closed = True
        # cancel pending callbacks
        for cb in self._callbacks.values():
            try:
                cb({"success": False, "message": "session closed"})
            except Exception:
                pass
        self._callbacks.clear()
        if self._writer:
            try:
                self._writer.close()
            except Exception:
                pass
