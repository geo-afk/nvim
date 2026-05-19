"""Output panel renderer.

Renders a ring-buffer of debug output with per-kind icons and colours.
Uses BufWriter for diff-only updates; never flickers.
"""

from __future__ import annotations
import pynvim
from .highlights import ICON
from .render import BufWriter, LineBuilder

MAX_ITEMS = 800
MAX_VIEW = 250
_NS = "go_dbg_output"

_KIND_MAP: dict[str, tuple[str, str]] = {
    "error": (ICON["error"] + " ", "GoDbgOutErr"),
    "warn": (ICON["warn"] + " ", "GoDbgOutWarn"),
    "event": (ICON["event"] + " ", "GoDbgOutEvent"),
    "program": (ICON["program"] + " ", "GoDbgOutProgram"),
    "protocol": (ICON["protocol"] + " ", "GoDbgOutProtocol"),
    "raw": (ICON["raw"] + " ", "GoDbgOutRaw"),
    "detail": ("   ", "GoDbgOutProtocol"),
    "status": (ICON["event"] + " ", "GoDbgOutEvent"),
}


def _fmt(item) -> tuple[str, str, str | None]:
    if isinstance(item, str):
        return "  " + item, "GoDbgOutLog", None
    if isinstance(item, dict):
        kind, text, ts = item.get("kind", "log"), item.get("text", ""), item.get("ts")
    else:
        kind, text, ts = (
            getattr(item, "kind", "log"),
            getattr(item, "text", ""),
            getattr(item, "ts", None),
        )
    pfx, hl = _KIND_MAP.get(kind, ("  ", "GoDbgOutLog"))
    return "  " + pfx + text, hl, ts


def render_output(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    buf = ui.output_buf
    if not buf or not nvim.api.buf_is_valid(buf):
        return

    if not hasattr(ui, "_out_writer") or ui._out_writer is None:
        ns = nvim.api.create_namespace(_NS)
        ui._out_writer = BufWriter(nvim, buf, ns)

    writer = ui._out_writer
    items = ui.output_items
    start = max(0, len(items) - MAX_VIEW)

    lb = LineBuilder()
    if not items:
        lb.add("  (no output)", "GoDbgEmpty")
    else:
        for idx, item in enumerate(items[start:]):
            text, grp, ts = _fmt(item)
            row = lb.add(text, grp)
            if ts:
                lb.marks.append(
                    {
                        "key": f"ts:{start + idx}",
                        "row": row,
                        "col": 0,
                        "opts": {
                            "virt_text": [[ts, "GoDbgOutTs"]],
                            "virt_text_pos": "right_align",
                            "priority": 3,
                        },
                    }
                )

    changed = writer.set_lines(lb.lines)
    writer.set_marks(lb.marks)

    _set_winbar(nvim, state)

    if changed:
        _auto_scroll(nvim, state, len(lb.lines))


def _auto_scroll(nvim: pynvim.Nvim, state, line_count: int) -> None:
    win = state.ui.output_win
    if not win or not nvim.api.win_is_valid(win):
        return
    try:
        cur = nvim.api.win_get_cursor(win)[0]
        if cur >= max(1, line_count - 2):
            nvim.api.win_set_cursor(win, [line_count, 0])
    except Exception:
        pass


def _set_winbar(nvim: pynvim.Nvim, state) -> None:
    win = state.ui.output_win
    if not win or not nvim.api.win_is_valid(win):
        return
    status = (state.ui.last_status or "").replace("\n", " ")[:64]
    wb = (
        f" %#GoDbgSectionIcon#{ICON['output']}"
        f"%#GoDbgSectionHdr# Output"
        f"%#Normal# %="
        f"%#GoDbgAccent#{ICON['stopped']}"
        f"%#Comment# {status} "
    )
    try:
        nvim.api.set_option_value("winbar", wb, {"win": win})
    except Exception:
        pass
