"""High-level debugger operations."""

from __future__ import annotations
import asyncio
import json
import logging
import os
import re
import subprocess
import threading
from pathlib import Path
from typing import Optional

import pynvim

from .state import DebuggerState, Breakpoint, VarNode
from .session import DAPSession
from ..ui.sidebar import (
    build_goroutine_items,
    build_variable_items,
    build_stack_items,
    build_bp_items,
    build_watch_items,
    sb_width,
    render_sidebar,
)
from ..ui.output import render_output, MAX_OUTPUT, _set_winbar
from ..ui.layout import open_ui
from ..ui.virt import apply_virt, clear_virt
from ..ui.hover import show_hover
from ..ui.highlights import SIGN_BP, SIGN_BP_COND, SIGN_BP_LOG, SIGN_PC
from ..dap.parser import OutputParser

log = logging.getLogger(__name__)


class Debugger:
    def __init__(self, nvim: pynvim.Nvim) -> None:
        self.nvim = nvim
        self.state = DebuggerState()
        self._parser = OutputParser()
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._thread: Optional[threading.Thread] = None
        self._session: Optional[DAPSession] = None
        self._dlv_proc: Optional[subprocess.Popen] = None

    # ── asyncio thread ─────────────────────────────────────────────────────────

    def _ensure_loop(self) -> asyncio.AbstractEventLoop:
        if self._loop is None or not self._loop.is_running():
            self._loop = asyncio.new_event_loop()
            self._thread = threading.Thread(target=self._loop.run_forever, daemon=True)
            self._thread.start()
        return self._loop

    def _run(self, coro):
        loop = self._ensure_loop()
        return asyncio.run_coroutine_threadsafe(coro, loop)

    # ── render scheduling ──────────────────────────────────────────────────────

    def _schedule_render(self, key: str) -> None:
        """Coalesced, thread-safe render scheduling.

        Multiple calls with the same *key* before the scheduled callback
        fires are deduplicated – only one render is dispatched per event-loop
        tick.  Safe to call from both the asyncio thread and the Neovim main
        thread.
        """
        if self.state.ui.pending.get(key):
            return
        self.state.ui.pending[key] = True
        if key == "output":
            self.nvim.async_call(self._do_render_output)
        elif key == "sidebar":
            self.nvim.async_call(self._do_render_sidebar)

    def _do_render_output(self) -> None:
        self.state.ui.pending["output"] = False
        render_output(self.nvim, self.state)

    def _do_render_sidebar(self) -> None:
        self.state.ui.pending["sidebar"] = False
        render_sidebar(self.nvim, self.state)

    # ── notify ─────────────────────────────────────────────────────────────────

    def _notify(self, msg: str, level: int = 2) -> None:
        self.nvim.async_call(self.nvim.api.notify, f"[go-debug] {msg}", level, {})

    # ── output ─────────────────────────────────────────────────────────────────

    def append_output(self, raw: str) -> None:
        """Append raw text to the output panel (main-thread call)."""
        self._append_output_internal(raw)

    def _append_output_threadsafe(self, raw: str) -> None:
        """Append output from the asyncio thread."""
        self._append_output_internal(raw)

    def _append_output_internal(self, raw: str) -> None:
        if not raw:
            return
        items = self._parser.parse(raw)
        ui = self.state.ui
        for item in items:
            ui.output_items.append(item)
            if item.kind not in ("detail", "protocol"):
                ui.last_status = item.text
        while len(ui.output_items) > MAX_OUTPUT:
            ui.output_items.pop(0)
        self._schedule_render("output")

    # ── path helpers ───────────────────────────────────────────────────────────

    def _focus_main_win(self) -> int:
        """Ensure an editor window is focused (avoiding panels).
        Returns the window ID of the focused window.
        """
        ui = self.state.ui
        cur = self.nvim.api.get_current_win()
        panels = (ui.sidebar_win, ui.output_win, ui.controls_win, ui.help_win)
        if cur not in panels:
            return cur

        for win in self.nvim.api.list_wins():
            if win not in panels and self.nvim.api.win_is_valid(win):
                self.nvim.api.set_current_win(win)
                return win

        # Fallback: jump to next window
        self.nvim.command("wincmd w")
        return self.nvim.api.get_current_win()

    def _norm(self, path: str) -> str:
        if not path:
            return ""
        try:
            return os.path.abspath(path).replace("\\", "/")
        except Exception:
            return path.replace("\\", "/")

    def _project_root(self, start: str | None = None) -> str:
        if start is None:
            start = os.getcwd()
        p = Path(start)
        try:
            for parent in [p, *p.parents]:
                for marker in ("go.work", "go.mod", ".git"):
                    if (parent / marker).exists():
                        return str(parent).replace("\\", "/")
        except Exception:
            pass
        return os.getcwd().replace("\\", "/")

    def _go_package_dir(self, file_path: str | None = None) -> str:
        f = file_path or os.getcwd()
        if f.endswith(".go"):
            return str(Path(f).parent).replace("\\", "/")
        return os.getcwd().replace("\\", "/")

    def _find_main_package(self) -> str:
        try:
            f = str(self.nvim.funcs.expand("%:p"))
        except Exception:
            f = ""

        fdir = str(Path(f).parent) if f and f.endswith(".go") else os.getcwd()
        root = self._project_root(fdir)

        if f and f.endswith(".go"):
            try:
                buf = self.nvim.api.get_current_buf()
                lines = self.nvim.api.buf_get_lines(buf, 0, 80, False)
                for line in lines:
                    m = re.match(r"^\s*package\s+(\w+)", line)
                    if m and m.group(1) == "main":
                        return fdir
            except Exception:
                pass

        for candidate in [f"{root}/main.go", f"{root}/cmd/main.go"]:
            if Path(candidate).exists():
                return str(Path(candidate).parent).replace("\\", "/")

        try:
            cmd_dir = Path(root) / "cmd"
            if cmd_dir.is_dir():
                for child in sorted(cmd_dir.iterdir()):
                    if (child / "main.go").exists():
                        return str(child).replace("\\", "/")
        except Exception:
            pass

        return fdir.replace("\\", "/")

    def _current_file_line(self) -> tuple[str | None, int | None]:
        try:
            f = str(self.nvim.funcs.expand("%:p"))
            if not f or not f.endswith(".go"):
                self._notify("not a Go file", 2)
                return None, None
            line = self.nvim.api.win_get_cursor(self.nvim.api.get_current_win())[0]
            return self._norm(f), line
        except Exception:
            return None, None

    # ── breakpoints ────────────────────────────────────────────────────────────

    def _bp_key(self, file: str, line: int) -> str:
        return f"{self._norm(file)}:{line}"

    def _sorted_bps(self) -> list[Breakpoint]:
        bps = [bp for bp in self.state.breakpoints.values() if not bp.tmp]
        bps.sort(key=lambda b: (b.file, b.line))
        return bps

    def _grouped_bps(self) -> dict[str, list[Breakpoint]]:
        g: dict[str, list[Breakpoint]] = {}
        for bp in self.state.breakpoints.values():
            g.setdefault(bp.file, []).append(bp)
        return g

    def _bp_changed(self) -> None:
        self._refresh_bp_signs()
        self._update_sidebar_bps()
        self._save_breakpoints()
        if self._session and self._session.initialized:
            self._run(self._sync_breakpoints_async())

    def _update_sidebar_bps(self) -> None:
        bps = self._sorted_bps()
        items, count = build_bp_items(bps)
        self.state.ui.sections["breakpoints"].items = items
        self.state.ui.sections["breakpoints"].count = count or None
        self._schedule_render("sidebar")

    def _refresh_bp_signs(self) -> None:
        ui = self.state.ui
        for bufnr, ids in ui.bp_sign_ids.items():
            if self.nvim.api.buf_is_valid(bufnr):
                for sid in ids:
                    try:
                        self.nvim.funcs.sign_unplace(
                            "go_dbg_bp", {"buffer": bufnr, "id": sid}
                        )
                    except Exception:
                        pass
        ui.bp_sign_ids = {}

        for bp in self._sorted_bps():
            bufnr = self._buf_for_file(bp.file)
            sign = (
                SIGN_BP_LOG
                if bp.log_message
                else SIGN_BP_COND
                if bp.condition
                else SIGN_BP
            )
            ui.sign_ctr += 1
            try:
                self.nvim.funcs.sign_place(
                    ui.sign_ctr,
                    "go_dbg_bp",
                    sign,
                    bufnr,
                    {"lnum": bp.line, "priority": 50},
                )
                ui.bp_sign_ids.setdefault(bufnr, []).append(ui.sign_ctr)
            except Exception:
                pass

    def _save_breakpoints(self) -> None:
        path = self._project_root() + "/.nvim-debug-bps.json"
        try:
            data = [
                {
                    "file": bp.file,
                    "line": bp.line,
                    "condition": bp.condition,
                    "hitCondition": bp.hit_condition,
                    "logMessage": bp.log_message,
                }
                for bp in self._sorted_bps()
            ]
            with open(path, "w") as f:
                json.dump(data, f)
        except Exception:
            pass

    def load_breakpoints(self) -> None:
        path = self._project_root() + "/.nvim-debug-bps.json"
        try:
            with open(path) as f:
                items = json.load(f)
            self.state.breakpoints = {}
            for item in items:
                if item.get("file") and item.get("line"):
                    bp = Breakpoint(
                        file=self._norm(item["file"]),
                        line=item["line"],
                        condition=item.get("condition"),
                        hit_condition=item.get("hitCondition"),
                        log_message=item.get("logMessage"),
                    )
                    self.state.breakpoints[bp.bp_key()] = bp
            self._refresh_bp_signs()
            self._update_sidebar_bps()
            if items:
                self.append_output(f"● loaded {len(items)} breakpoints")
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    def toggle_breakpoint(self) -> None:
        file, line = self._current_file_line()
        if file is None or line is None:
            return
        key = self._bp_key(file, line)
        if key in self.state.breakpoints:
            del self.state.breakpoints[key]
        else:
            self.state.breakpoints[key] = Breakpoint(file=file, line=line)
        self._bp_changed()

    def conditional_breakpoint(self) -> None:
        file, line = self._current_file_line()
        if file is None or line is None:
            return
        key = self._bp_key(file, line)
        existing = self.state.breakpoints.get(key)
        cond = (
            self.nvim.funcs.input(
                "Condition: ", existing.condition or "" if existing else ""
            )
            or ""
        ).strip()
        self.state.breakpoints[key] = Breakpoint(
            file=file, line=line, condition=cond or None
        )
        self._bp_changed()

    def logpoint(self) -> None:
        file, line = self._current_file_line()
        if file is None or line is None:
            return
        msg = (self.nvim.funcs.input("Log message ({expr}): ") or "").strip()
        if not msg:
            return
        key = self._bp_key(file, line)
        self.state.breakpoints[key] = Breakpoint(file=file, line=line, log_message=msg)
        self._bp_changed()

    def hit_breakpoint(self) -> None:
        file, line = self._current_file_line()
        if file is None or line is None:
            return
        hit = (self.nvim.funcs.input("Hit count (e.g. >=5, %3): ") or "").strip()
        if not hit:
            return
        key = self._bp_key(file, line)
        self.state.breakpoints[key] = Breakpoint(
            file=file, line=line, hit_condition=hit
        )
        self._bp_changed()

    def remove_breakpoint(self) -> None:
        file, line = self._current_file_line()
        if file is None or line is None:
            return
        self.state.breakpoints.pop(self._bp_key(file, line), None)
        self._bp_changed()

    def clear_breakpoints(self) -> None:
        self.state.breakpoints = {}
        self._bp_changed()

    # ── DAP sync ───────────────────────────────────────────────────────────────

    async def _sync_breakpoints_async(self) -> None:
        session = self._session
        if not session or session.closed:
            return
        grouped = self._grouped_bps()
        all_files = set(grouped.keys()) | self.state.synced_bp_files
        root = self._project_root()

        for file in list(all_files):
            bps = grouped.get(file, [])
            dap_bps = []
            for bp in bps:
                entry: dict = {"line": bp.line}
                if bp.condition:
                    entry["condition"] = bp.condition
                if bp.hit_condition:
                    entry["hitCondition"] = bp.hit_condition
                if bp.log_message:
                    entry["logMessage"] = bp.log_message
                dap_bps.append(entry)

            try:
                rel_path = str(Path(file).relative_to(root)).replace("\\", "/")
            except Exception:
                rel_path = os.path.basename(file)

            ev = asyncio.Event()

            def _cb(resp, f=file, dbps=dap_bps, e=ev, short=rel_path):
                if resp.get("success"):
                    if not dbps:
                        self.state.synced_bp_files.discard(f)
                    else:
                        self.state.synced_bp_files.add(f)
                        body = resp.get("body") or {}
                        verified = sum(
                            1
                            for b in (body.get("breakpoints") or [])
                            if b.get("verified")
                        )
                        self._append_output_threadsafe(
                            f"  {verified}/{len(dbps)} BP verified in {short}"
                        )
                e.set()

            session.request(
                "setBreakpoints",
                {
                    "source": {"path": file, "name": os.path.basename(file)},
                    "breakpoints": dap_bps,
                    "lines": [bp.line for bp in bps],
                    "sourceModified": False,
                },
                _cb,
            )
            await asyncio.wait_for(ev.wait(), timeout=5.0)

    # ── DAP initialize sequence ────────────────────────────────────────────────

    async def _on_initialized(self) -> None:
        session = self._session
        if not session:
            return
        session.initialized = True
        self._append_output_threadsafe("● dlv initialized")

        ev = asyncio.Event()
        session.request(
            "setExceptionBreakpoints",
            {"filters": ["unrecovered-panic", "runtime-fatal-throw"]},
            lambda r: ev.set(),
        )
        try:
            await asyncio.wait_for(ev.wait(), 5.0)
        except asyncio.TimeoutError:
            pass

        await self._sync_breakpoints_async()

        ev2 = asyncio.Event()
        session.request("configurationDone", {}, lambda r: ev2.set())
        try:
            await asyncio.wait_for(ev2.wait(), 5.0)
            session.configured = True
            self._append_output_threadsafe("● configuration done")
        except asyncio.TimeoutError:
            pass

    # ── DAP event handling ─────────────────────────────────────────────────────

    def _on_dap_event(self, event: str, body: dict) -> None:
        """Dispatched from the asyncio thread."""
        if event == "initialized":
            self._run(self._on_initialized())
        elif event == "stopped":
            reason = body.get("reason", "stopped")
            self._append_output_threadsafe(f"⏸  {reason}")
            self._run(self._refresh_stopped(body))
        elif event == "continued":
            self._append_output_threadsafe("▶ running")
            self.nvim.async_call(self._clear_stopped_ui)
        elif event == "output":
            text = (body.get("output") or "").strip()
            if text:
                self._append_output_threadsafe(text)
        elif event == "terminated":
            self._append_output_threadsafe("■ process terminated")
            self.nvim.async_call(self._clear_stopped_ui)
        elif event == "exited":
            code = body.get("exitCode")
            self._append_output_threadsafe(
                "■ exited" + (f" (code {code})" if code is not None else "")
            )
            self.nvim.async_call(self._clear_stopped_ui)
        elif event == "process":
            name = body.get("name", "?")
            pid = body.get("systemProcessId", "?")
            self._append_output_threadsafe(f"process {name} (pid {pid})")

    def _clear_stopped_ui(self) -> None:
        clear_virt(self.nvim)
        self._clear_execution_line()
        self.state.ui.sections["stack"].items = []
        self.state.ui.sections["stack"].count = None
        self.state.ui.sections["variables"].items = []
        self.state.ui.sections["variables"].count = None
        self._schedule_render("sidebar")

    # ── refresh on stop ────────────────────────────────────────────────────────

    async def _refresh_stopped(self, event_body: dict) -> None:
        session = self._session
        if not session:
            return
        tid = event_body.get("threadId") or session.stopped_tid or 1
        session.stopped_tid = tid

        # clean up run-to-cursor temp BP
        if self.state.run_to_cursor_key:
            self.state.breakpoints.pop(self.state.run_to_cursor_key, None)
            self.state.run_to_cursor_key = None
            self.nvim.async_call(self._refresh_bp_signs)
            await self._sync_breakpoints_async()

        # goroutines / threads
        ev = asyncio.Event()
        threads_resp: list = [{}]
        session.request(
            "threads", {}, lambda r: (threads_resp.__setitem__(0, r), ev.set())
        )
        try:
            await asyncio.wait_for(ev.wait(), 5.0)
        except asyncio.TimeoutError:
            pass
        threads = (threads_resp[0].get("body") or {}).get("threads") or []
        g_items, gc = build_goroutine_items(threads, tid)

        def _set_goroutines():
            self.state.ui.sections["goroutines"].items = g_items
            self.state.ui.sections["goroutines"].count = gc or None

        self.nvim.async_call(_set_goroutines)

        # call stack
        ev2 = asyncio.Event()
        stack_resp: list = [{}]
        session.request(
            "stackTrace",
            {"threadId": tid, "startFrame": 0, "levels": 20},
            lambda r: (stack_resp.__setitem__(0, r), ev2.set()),
        )
        try:
            await asyncio.wait_for(ev2.wait(), 5.0)
        except asyncio.TimeoutError:
            pass
        frames = (stack_resp[0].get("body") or {}).get("stackFrames") or []
        s_items, sc = build_stack_items(frames)

        def _set_stack():
            self.state.ui.sections["stack"].items = s_items
            self.state.ui.sections["stack"].count = sc or None

        self.nvim.async_call(_set_stack)

        top = frames[0] if frames else None
        session.current_fid = top["id"] if top else None

        if top:
            src = (top.get("source") or {}).get("path")
            lnum = top.get("line")
            if src and lnum:
                self.nvim.async_call(
                    self._show_execution_line,
                    src,
                    lnum,
                    event_body.get("reason", "stopped"),
                )

        if not top:
            self._schedule_render("sidebar")
            return

        # scopes + variables
        ev3 = asyncio.Event()
        scope_resp: list = [{}]
        session.request(
            "scopes",
            {"frameId": top["id"]},
            lambda r: (scope_resp.__setitem__(0, r), ev3.set()),
        )
        try:
            await asyncio.wait_for(ev3.wait(), 5.0)
        except asyncio.TimeoutError:
            pass
        scopes = (scope_resp[0].get("body") or {}).get("scopes") or []
        if not scopes:
            self._schedule_render("sidebar")
            return

        session.last_scope_ref = scopes[0].get("variablesReference") if scopes else None
        vars_by_scope: dict = {}

        var_evts = []
        for scope in scopes:
            ref = scope.get("variablesReference", 0)
            ev_v = asyncio.Event()
            var_evts.append(ev_v)

            def _v(r, s_ref=ref, e=ev_v):
                vars_by_scope[s_ref] = (r.get("body") or {}).get("variables") or []
                e.set()

            session.request("variables", {"variablesReference": ref, "count": 200}, _v)

        try:
            await asyncio.wait_for(
                asyncio.gather(*[asyncio.ensure_future(e.wait()) for e in var_evts]),
                timeout=3.0,
            )
        except asyncio.TimeoutError:
            pass

        await self._refresh_expanded_variables(session)

        def _set_vars():
            items, count = build_variable_items(
                scopes,
                vars_by_scope,
                self.state.ui.var_nodes,
                sb_width(self.nvim),
            )
            self.state.ui.sections["variables"].items = items
            self.state.ui.sections["variables"].count = count or None
            self._schedule_render("sidebar")
            if top and (top.get("source") or {}).get("path"):
                all_vars = [v for vlist in vars_by_scope.values() for v in vlist]
                apply_virt(self.nvim, top["source"]["path"], all_vars)

        self.nvim.async_call(_set_vars)

        await self._eval_watches_async()

    # ── watches ────────────────────────────────────────────────────────────────

    async def _eval_watches_async(self) -> None:
        session = self._session
        if not session or not self.state.watches:
            return
        fid = session.current_fid
        for w in self.state.watches:
            ev = asyncio.Event()

            def _cb(resp, watch=w, e=ev):
                if resp.get("success") and resp.get("body"):
                    watch["value"] = str(resp["body"].get("result") or "")
                    watch["error"] = False
                else:
                    watch["value"] = resp.get("message") or "error"
                    watch["error"] = True
                e.set()

            session.request(
                "evaluate",
                {"expression": w["expr"], "context": "watch", "frameId": fid},
                _cb,
            )
            try:
                await asyncio.wait_for(ev.wait(), 3.0)
            except asyncio.TimeoutError:
                pass

        def _set():
            items, count = build_watch_items(self.state.watches, sb_width(self.nvim))
            self.state.ui.sections["watches"].items = items
            self.state.ui.sections["watches"].count = count or None
            self._schedule_render("sidebar")

        self.nvim.async_call(_set)

    async def _refresh_expanded_variables(self, session: DAPSession) -> None:
        refs = [
            ref
            for ref, node in self.state.ui.var_nodes.items()
            if ref > 0 and node.expanded
        ]
        if not refs:
            return

        pending: dict[int, list] = {}
        evts = []
        for ref in refs:
            ev = asyncio.Event()
            evts.append(ev)

            def _cb(resp, vref=ref, e=ev):
                if resp.get("success"):
                    pending[vref] = (resp.get("body") or {}).get("variables") or []
                e.set()

            session.request("variables", {"variablesReference": ref, "count": 200}, _cb)

        try:
            await asyncio.wait_for(
                asyncio.gather(*(e.wait() for e in evts)),
                timeout=3.0,
            )
        except asyncio.TimeoutError:
            pass

        for ref, children in pending.items():
            node = self.state.ui.var_nodes.get(ref)
            if node:
                node.children = children

    def watch_add(self, expr: str | None = None) -> None:
        if expr is None:
            expr = (
                self.nvim.funcs.input(
                    "Watch expression: ", self.nvim.funcs.expand("<cword>")
                )
                or ""
            ).strip()
        if not expr:
            return
        if any(w["expr"] == expr for w in self.state.watches):
            return
        self.state.watches.append({"expr": expr, "value": "…", "error": False})
        self._save_watches()
        items, count = build_watch_items(self.state.watches, sb_width(self.nvim))
        self.state.ui.sections["watches"].items = items
        self.state.ui.sections["watches"].count = count or None
        self._schedule_render("sidebar")

    def watch_remove(self) -> None:
        if not self.state.watches:
            self._notify("no watches", 2)
            return
        choices = [f"{w['expr']} = {w.get('value', '?')}" for w in self.state.watches]
        idx = self.nvim.funcs.inputlist(["Remove watch:"] + choices)
        if 1 <= idx <= len(self.state.watches):
            self.state.watches.pop(idx - 1)
            self._save_watches()
            items, count = build_watch_items(self.state.watches, sb_width(self.nvim))
            self.state.ui.sections["watches"].items = items
            self.state.ui.sections["watches"].count = count or None
            self._schedule_render("sidebar")

    def _save_watches(self) -> None:
        path = self._project_root() + "/.nvim-debug-watches.json"
        try:
            with open(path, "w") as f:
                json.dump([w["expr"] for w in self.state.watches], f)
        except Exception:
            pass

    def load_watches(self) -> None:
        path = self._project_root() + "/.nvim-debug-watches.json"
        try:
            with open(path) as f:
                exprs = json.load(f)
            self.state.watches = [
                {"expr": e, "value": "…", "error": False} for e in exprs
            ]
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    # ── execution line ─────────────────────────────────────────────────────────

    def _buf_for_file(self, file: str) -> int:
        norm = self._norm(file)
        for b in self.nvim.api.list_bufs():
            if self.nvim.api.buf_is_loaded(b):
                try:
                    if self._norm(self.nvim.api.buf_get_name(b)) == norm:
                        return b
                except Exception:
                    pass
        return self.nvim.funcs.bufadd(file)

    def _clear_execution_line(self) -> None:
        ui = self.state.ui
        if ui.current_file:
            b = self._buf_for_file(ui.current_file)
            if self.nvim.api.buf_is_valid(b):
                ns = self.nvim.api.create_namespace("go_dbg_src")
                self.nvim.api.buf_clear_namespace(b, ns, 0, -1)
                try:
                    self.nvim.funcs.sign_unplace("go_dbg_pc", {"buffer": b})
                except Exception:
                    pass
        ui.current_file = None
        ui.current_line = None

    def _show_execution_line(self, file: str, line: int, reason: str) -> None:
        from ..ui.highlights import ICON as _ICON  # local import avoids circular

        self._clear_execution_line()
        ui = self.state.ui
        b = self._buf_for_file(file)
        ns = self.nvim.api.create_namespace("go_dbg_src")
        ui.current_file = self._norm(file)
        ui.current_line = line

        lc = self.nvim.api.buf_line_count(b)
        safe = max(1, min(line, lc))

        try:
            self.nvim.funcs.sign_place(
                1, "go_dbg_pc", SIGN_PC, b, {"lnum": safe, "priority": 90}
            )
        except Exception:
            pass

        virt = f" {_ICON['stopped']} {reason} "
        try:
            self.nvim.api.buf_set_extmark(
                b,
                ns,
                safe - 1,
                0,
                {
                    "virt_text": [[virt, "GoDbgExecVirt"]],
                    "virt_text_pos": "eol",
                    "hl_mode": "combine",
                    "priority": 100,
                },
            )
            self.nvim.api.buf_set_extmark(
                b,
                ns,
                safe - 1,
                0,
                {
                    "line_hl_group": "GoDbgExecLine",
                    "priority": 90,
                },
            )
        except Exception:
            pass

        try:
            short = self.nvim.funcs.fnamemodify(file, ":~:.")
            ui.last_status = f"{_ICON['stopped']} {reason}  {short}:{line}"
        except Exception:
            pass
        _set_winbar(self.nvim, self.state)

        # Navigate editor to the stopped line.
        try:
            target = self.nvim.funcs.bufwinid(b)
            origin = self.nvim.api.get_current_win()
            panels = (ui.sidebar_win, ui.output_win, ui.controls_win, ui.help_win)
            in_panel = origin in panels

            if target == -1:
                target = self._focus_main_win()
                self.nvim.command(f"edit {self.nvim.funcs.fnameescape(file)}")
                # If we were in a panel, jump back to keep focus "sticky"
                if in_panel and reason != "frame":
                    self.nvim.api.set_current_win(origin)
            
            if self.nvim.api.win_is_valid(target):
                self.nvim.api.win_set_cursor(target, [safe, 0])
                # Only move focus to the target window if:
                # 1. It was an explicit navigation (reason == "frame")
                # 2. Or we were already in a main window context
                if reason == "frame" or not in_panel:
                    self.nvim.api.set_current_win(target)
        except Exception:
            pass

    # ── session lifecycle ──────────────────────────────────────────────────────

    def _close_session(self) -> None:
        if self._session:
            self._session.close()
            self._session = None
        if self._dlv_proc:
            try:
                self._dlv_proc.terminate()
            except Exception:
                pass
            self._dlv_proc = None

    async def _spawn_dlv_and_connect(self, config: dict, dap_cwd: str) -> None:
        session = DAPSession(
            on_event=self._on_dap_event,
            on_output=self._append_output_threadsafe,
            on_close=lambda: self.nvim.async_call(self._on_session_close),
        )
        self._session = session
        self._append_output_threadsafe(f"starting dlv dap in: {dap_cwd}")

        proc = await asyncio.create_subprocess_exec(
            "dlv",
            "dap",
            "--listen",
            "127.0.0.1:0",
            "--log-output",
            "dap",
            "--log",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=dap_cwd,
        )

        host_ref: list = [None]
        port_ref: list = [None]
        listen_ev = asyncio.Event()

        async def _watch_stream(stream):
            async for line_bytes in stream:
                line = line_bytes.decode(errors="replace").rstrip()
                self._append_output_threadsafe(line)
                if not listen_ev.is_set():
                    m = re.search(r"DAP server listening at:\s*([\d.]+):(\d+)", line)
                    if not m:
                        m2 = re.search(r"DAP server listening at:\s*:(\d+)", line)
                        if m2:
                            host_ref[0] = "127.0.0.1"
                            port_ref[0] = int(m2.group(1))
                            listen_ev.set()
                    else:
                        host_ref[0] = m.group(1)
                        port_ref[0] = int(m.group(2))
                        listen_ev.set()

        asyncio.ensure_future(_watch_stream(proc.stdout))
        asyncio.ensure_future(_watch_stream(proc.stderr))

        try:
            await asyncio.wait_for(listen_ev.wait(), 15.0)
        except asyncio.TimeoutError:
            self._append_output_threadsafe("[error] dlv failed to start in time")
            return

        self._append_output_threadsafe(
            f"connecting to dlv at {host_ref[0]}:{port_ref[0]}"
        )
        try:
            await session.connect(host_ref[0], port_ref[0])
        except Exception as e:
            self._append_output_threadsafe(f"[error] connect failed: {e}")
            return

        self._append_output_threadsafe("connected")
        await self._initialize_and_launch(session, config)

    async def _connect_existing(self, h: str, p: int) -> None:
        session = DAPSession(
            on_event=self._on_dap_event,
            on_output=self._append_output_threadsafe,
            on_close=lambda: self.nvim.async_call(self._on_session_close),
        )
        self._session = session
        try:
            await session.connect(h, p)
        except Exception as e:
            self._append_output_threadsafe(f"[error] connect failed: {e}")
            return
        self._append_output_threadsafe(f"connected to {h}:{p}")
        await self._initialize_and_launch(
            session, {"request": "attach", "mode": "remote"}
        )

    async def _initialize_and_launch(self, session: DAPSession, config: dict) -> None:
        ev = asyncio.Event()
        init_resp: list = [{}]
        session.request(
            "initialize",
            {
                "clientID": "nvim",
                "clientName": "Neovim",
                "adapterID": "go",
                "pathFormat": "path",
                "linesStartAt1": True,
                "columnsStartAt1": True,
                "supportsVariableType": True,
                "supportsVariablePaging": True,
                "supportsRunInTerminalRequest": False,
            },
            lambda r: (init_resp.__setitem__(0, r), ev.set()),
        )
        try:
            await asyncio.wait_for(ev.wait(), 10.0)
        except asyncio.TimeoutError:
            self._append_output_threadsafe("[error] initialize timed out")
            return

        if not init_resp[0].get("success"):
            self._append_output_threadsafe(
                f"[error] initialize: {init_resp[0].get('message')}"
            )
            return
        session.capabilities = init_resp[0].get("body") or {}

        cmd = "attach" if config.get("request") == "attach" else "launch"
        ev2 = asyncio.Event()
        launch_resp: list = [{}]
        session.request(
            cmd, config, lambda r: (launch_resp.__setitem__(0, r), ev2.set())
        )
        try:
            await asyncio.wait_for(ev2.wait(), 10.0)
        except asyncio.TimeoutError:
            pass
        r = launch_resp[0]
        if r.get("success"):
            target = config.get("program") or config.get("processId") or "target"
            self._append_output_threadsafe(f"● {cmd} accepted: {target}")
        else:
            self._append_output_threadsafe(
                f"[error] {cmd}: {r.get('message') or 'failed'}"
            )

    def _on_session_close(self) -> None:
        self.append_output("● DAP connection closed")

    def _start_session(self, config: dict, dap_cwd: str | None = None) -> None:
        if self.nvim.funcs.executable("dlv") == 0:
            self._notify(
                "dlv not found. Install: go install github.com/go-delve/delve/cmd/dlv@latest",
                4,
            )
            return
        open_ui(self.nvim, self.state, self._plugin_ref)
        self._clear_execution_line()
        clear_virt(self.nvim)
        self._close_session()
        self._parser.reset()
        self.state.last_config = {"config": config, "dap_cwd": dap_cwd or ""}
        self._run(self._spawn_dlv_and_connect(config, dap_cwd or self._project_root()))

    _plugin_ref = None  # set by plugin after construction

    # ── public launch commands ─────────────────────────────────────────────────

    def debug(self) -> None:
        program = self._find_main_package()
        root = self._project_root(program)
        self._start_session(
            {
                "name": "Debug",
                "type": "go",
                "request": "launch",
                "mode": "debug",
                "program": program,
                "cwd": root,
                "stopOnEntry": True,
                "stackTraceDepth": 50,
                "hideSystemGoroutines": True,
            },
            root,
        )

    def test(self) -> None:
        program = self._go_package_dir()
        root = self._project_root(program)
        self._start_session(
            {
                "name": "Test",
                "type": "go",
                "request": "launch",
                "mode": "test",
                "program": program,
                "cwd": root,
                "stopOnEntry": True,
                "stackTraceDepth": 50,
                "hideSystemGoroutines": True,
            },
            root,
        )

    def attach_spawn(self) -> None:
        program = self._find_main_package()
        root = self._project_root(program)
        cache = self.nvim.funcs.stdpath("cache")
        out_dir = os.path.join(cache, "go-debug")
        os.makedirs(out_dir, exist_ok=True)
        name = Path(program).name or Path(root).name
        exe = os.path.join(out_dir, name)
        open_ui(self.nvim, self.state)
        self.append_output(f"building: {exe}")

        def _build():
            result = subprocess.run(
                ["go", "build", "-gcflags=all=-N -l", "-o", exe, "."],
                cwd=program,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                self.nvim.async_call(
                    self.append_output, f"build failed:\n{result.stderr.strip()}"
                )
                return
            self.nvim.async_call(self.append_output, f"build OK: {exe}")
            self.nvim.async_call(
                self._start_session,
                {
                    "name": "Exec",
                    "type": "go",
                    "request": "launch",
                    "mode": "exec",
                    "program": exe,
                    "cwd": root,
                    "stopOnEntry": True,
                    "stackTraceDepth": 50,
                    "hideSystemGoroutines": True,
                },
                root,
            )

        threading.Thread(target=_build, daemon=True).start()

    def connect(self, addr: str) -> None:
        m = re.match(r"^([^:]+):(\d+)$", addr.strip())
        if not m:
            self._notify("expected host:port", 2)
            return
        open_ui(self.nvim, self.state)
        self._close_session()
        self._run(self._connect_existing(m.group(1), int(m.group(2))))

    def attach(self, pid_str: str) -> None:
        pid_str = pid_str.strip()
        if not pid_str.isdigit():
            self._notify("attach requires a numeric PID", 2)
            return
        root = self._project_root()
        self._start_session(
            {
                "name": "Attach",
                "type": "go",
                "request": "attach",
                "mode": "local",
                "processId": int(pid_str),
                "cwd": root,
                "stopOnEntry": False,
                "stackTraceDepth": 50,
                "hideSystemGoroutines": True,
            },
            root,
        )

    def restart(self) -> None:
        lc = self.state.last_config
        if not lc:
            self._notify("no previous session to restart", 2)
            return
        self.stop()
        import time

        time.sleep(0.3)
        self._start_session(lc["config"], lc.get("dap_cwd"))

    def stop(self) -> None:
        s = self._session
        if s and not s.closed:
            s.request("disconnect", {"terminateDebuggee": True})
            s.close()
        self._session = None
        self._clear_execution_line()
        clear_virt(self.nvim)
        self.state.ui.sections["stack"].items = []
        self.state.ui.sections["stack"].count = None
        self.state.ui.sections["variables"].items = []
        self.state.ui.sections["variables"].count = None
        self._schedule_render("sidebar")

    # ── execution control ──────────────────────────────────────────────────────

    def _need_session(self) -> Optional[DAPSession]:
        if not self._session or self._session.closed:
            self._notify("no active debug session", 2)
            return None
        return self._session

    def continue_exec(self) -> None:
        s = self._need_session()
        if s:
            s.request(
                "continue", {"threadId": s.stopped_tid or 1, "singleThread": False}
            )

    def step_over(self) -> None:
        s = self._need_session()
        if s:
            s.request("next", {"threadId": s.stopped_tid or 1})

    def step_into(self) -> None:
        s = self._need_session()
        if s:
            s.request("stepIn", {"threadId": s.stopped_tid or 1})

    def step_out(self) -> None:
        s = self._need_session()
        if s:
            s.request("stepOut", {"threadId": s.stopped_tid or 1})

    def pause(self) -> None:
        s = self._need_session()
        if s:
            s.request("pause", {"threadId": s.stopped_tid or 1})

    def run_to_cursor(self) -> None:
        file, line = self._current_file_line()
        if file is None or line is None:
            return
        real_key = self._bp_key(file, line)
        if real_key not in self.state.breakpoints:
            tmp_key = real_key + ":tmp"
            self.state.breakpoints[tmp_key] = Breakpoint(file=file, line=line, tmp=True)
            self.state.run_to_cursor_key = tmp_key
            s = self._session
            if s and s.initialized:
                self._run(self._sync_breakpoints_async())
            self._refresh_bp_signs()
        self.continue_exec()

    # ── inspection ─────────────────────────────────────────────────────────────

    def hover_eval(self, expr: str | None = None) -> None:
        s = self._session
        if not s or s.closed:
            return
        if expr is None:
            expr = self.nvim.funcs.expand("<cword>")
        expr = (expr or "").strip()
        if not expr:
            return

        ev = asyncio.Event()
        resp_holder: list = [{}]

        def _cb(r):
            resp_holder[0] = r
            ev.set()

        s.request(
            "evaluate",
            {"expression": expr, "context": "hover", "frameId": s.current_fid},
            _cb,
        )

        def _after():
            r = resp_holder[0]
            if r.get("success") and r.get("body"):
                body = r["body"]
                show_hover(
                    self.nvim,
                    expr,
                    str(body.get("result") or ""),
                    str(body.get("type") or ""),
                )

        def _poll(attempts: int = 0):
            if ev.is_set():
                _after()
            elif attempts < 20:
                # Use a safe timer: nvim.async_call schedules on the main thread
                # after a short delay; simulated with call_soon chaining.
                self.nvim.async_call(
                    lambda a=attempts: _poll(a + 1) if not ev.is_set() else _after()
                )

        _poll()

    def inspect(self, expr: str | None = None) -> None:
        if expr is None:
            expr = (
                self.nvim.funcs.input("Inspect: ", self.nvim.funcs.expand("<cword>"))
                or ""
            )
        expr = (expr or "").strip()
        if not expr:
            return
        s = self._need_session()
        if not s:
            return

        def _cb(resp):
            if resp.get("success") and resp.get("body"):
                val = str(resp["body"].get("result") or "")
                self.nvim.async_call(self.append_output, f"{expr} = {val}")
            else:
                self.nvim.async_call(
                    self.append_output, f"inspect failed: {resp.get('message')}"
                )

        s.request(
            "evaluate",
            {"expression": expr, "context": "repl", "frameId": s.current_fid},
            _cb,
        )

    def set_variable(self) -> None:
        s = self._need_session()
        if not s:
            return
        if not s.last_scope_ref:
            self.append_output("[warn] no active scope — stop at a breakpoint first")
            return
        name = (
            self.nvim.funcs.input("Variable name: ", self.nvim.funcs.expand("<cword>"))
            or ""
        ).strip()
        if not name:
            return
        val = (self.nvim.funcs.input("New value: ") or "").strip()
        if not val:
            return

        def _cb(resp):
            if resp.get("success"):
                self.nvim.async_call(self.append_output, f"set {name} = {val}")
            else:
                self.nvim.async_call(
                    self.append_output, f"[error] setVariable: {resp.get('message')}"
                )

        s.request(
            "setVariable",
            {"variablesReference": s.last_scope_ref, "name": name, "value": val},
            _cb,
        )

    # ── interactive sidebar ────────────────────────────────────────────────────

    def sidebar_select(self) -> None:
        """Handle selection/click in the sidebar."""
        ui = self.state.ui
        if not ui.sidebar_win or not self.nvim.api.win_is_valid(ui.sidebar_win):
            return
        
        row = self.nvim.api.win_get_cursor(ui.sidebar_win)[0]
        meta = ui.row_map.get(row - 1)
        if not meta:
            return

        mtype = meta.get("type")

        if mtype == "section_header":
            sec_id = meta["section_id"]
            self.state.ui.sections[sec_id].collapsed = not self.state.ui.sections[sec_id].collapsed
            self._schedule_render("sidebar")

        elif mtype == "stack_frame":
            fid = meta.get("fid")
            file = meta.get("file")
            line = meta.get("line")
            if fid is not None:
                if self._session:
                    self._session.current_fid = fid
                self._run(self._refresh_variables_for_frame(fid))
            if file and line:
                self.nvim.async_call(self._show_execution_line, file, line, "frame")

        elif mtype == "breakpoint":
            file = meta.get("file")
            line = meta.get("line")
            if file and line:
                self._focus_main_win()
                self.nvim.command(f"edit {self.nvim.funcs.fnameescape(file)}")
                self.nvim.api.win_set_cursor(0, [line, 0])

        elif mtype == "variable":
            vref = meta.get("vref", 0)
            if vref > 0:
                node = ui.var_nodes.setdefault(vref, VarNode())
                node.expanded = not node.expanded
                if node.expanded and not node.children:
                    self._run(self._expand_variable(vref))
                else:
                    self._schedule_render("sidebar")

    def sidebar_inspect(self) -> None:
        """Inspect variable details in a floating window."""
        ui = self.state.ui
        if not ui.sidebar_win or not self.nvim.api.win_is_valid(ui.sidebar_win):
            return

        row = self.nvim.api.win_get_cursor(ui.sidebar_win)[0]
        meta = ui.row_map.get(row - 1)
        if not meta or meta.get("type") != "variable":
            return

        vref = meta.get("vref", 0)
        name = meta.get("name", "variable")
        val = meta.get("val", "")
        self._run(self._inspect_variable_async(vref, name, val))

    async def _inspect_variable_async(self, vref: int, name: str, val: str) -> None:
        session = self._session
        if not session:
            return

        vars_list = []
        if vref > 0:
            ev = asyncio.Event()

            def _cb(r):
                nonlocal vars_list
                vars_list = (r.get("body") or {}).get("variables") or []
                ev.set()

            session.request("variables", {"variablesReference": vref, "count": 200}, _cb)
            try:
                await asyncio.wait_for(ev.wait(), 3.0)
            except asyncio.TimeoutError:
                pass

        self.nvim.async_call(self._show_inspector, name, vars_list, vref, val)

    def _show_inspector(self, name: str, variables: list, vref: int, val: str) -> None:
        from ..ui.inspector import show_inspector

        show_inspector(self.nvim, name, variables, vref, val)

    async def _refresh_variables_for_frame(self, fid: int) -> None:
        session = self._session
        if not session:
            return
        ev = asyncio.Event()
        resp: list = [{}]
        session.request("scopes", {"frameId": fid}, lambda r: (resp.__setitem__(0, r), ev.set()))
        try:
            await asyncio.wait_for(ev.wait(), 5.0)
        except asyncio.TimeoutError:
            return
        
        scopes = (resp[0].get("body") or {}).get("scopes") or []
        if not scopes:
            return
        
        session.last_scope_ref = scopes[0].get("variablesReference")
        vars_by_scope: dict = {}
        var_evts = []

        for scope in scopes:
            ref = scope.get("variablesReference", 0)
            ev_v = asyncio.Event()
            var_evts.append(ev_v)
            def _v(r, s_ref=ref, e=ev_v):
                vars_by_scope[s_ref] = (r.get("body") or {}).get("variables") or []
                e.set()
            session.request("variables", {"variablesReference": ref, "count": 200}, _v)

        try:
            await asyncio.wait_for(asyncio.gather(*(e.wait() for e in var_evts)), timeout=3.0)
        except asyncio.TimeoutError:
            pass

        await self._refresh_expanded_variables(session)

        def _update():
            items, count = build_variable_items(
                scopes, vars_by_scope, self.state.ui.var_nodes, sb_width(self.nvim)
            )
            self.state.ui.sections["variables"].items = items
            self.state.ui.sections["variables"].count = count or None
            self._schedule_render("sidebar")

        self.nvim.async_call(_update)

    async def _expand_variable(self, vref: int) -> None:
        session = self._session
        if not session:
            return
        ev = asyncio.Event()
        resp: list = [{}]
        session.request("variables", {"variablesReference": vref, "count": 200}, 
                        lambda r: (resp.__setitem__(0, r), ev.set()))
        try:
            await asyncio.wait_for(ev.wait(), 5.0)
        except asyncio.TimeoutError:
            return
        
        children = (resp[0].get("body") or {}).get("variables") or []
        def _update():
            node = self.state.ui.var_nodes.get(vref)
            if node:
                node.children = children
                self._schedule_render("sidebar")

        self.nvim.async_call(_update)
