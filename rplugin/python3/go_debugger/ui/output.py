"""Output panel renderer.

Each item is rendered as:
  [HH:MM:SS]  <icon> <text>

Items older than MAX_VIEW are not rendered (but kept in the ring buffer up
to MAX_OUTPUT so the user can scroll back after opening the UI).
"""

from __future__ import annotations
import pynvim
from .highlights import ICON

MAX_OUTPUT = 800  # items kept in memory
MAX_VIEW = 250  # items rendered at once

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

# Pre-computed "no output" placeholder
_EMPTY_LINE = "  (no output)"
_EMPTY_HL = "GoDbgEmpty"


def _fmt(item) -> tuple[str, str, str | None]:
    """Return (line_text, hl_group, timestamp_str | None)."""
    if isinstance(item, str):
        return "  " + item, "GoDbgOutLog", None

    if isinstance(item, dict):
        kind = item.get("kind", "log")
        text = item.get("text", "")
        ts = item.get("ts", None)
    else:
        kind = getattr(item, "kind", "log")
        text = getattr(item, "text", "")
        ts = getattr(item, "ts", None)

    pfx, hl = _KIND_MAP.get(kind, ("  ", "GoDbgOutLog"))
    return "  " + pfx + text, hl, ts


def _apply_line_diff(nvim: pynvim.Nvim, buf: int, old: list[str], new: list[str]) -> None:
    if old == new:
        return
    if not old:
        nvim.api.buf_set_lines(buf, 0, -1, False, new)
        return

    prefix = 0
    limit = min(len(old), len(new))
    while prefix < limit and old[prefix] == new[prefix]:
        prefix += 1

    suffix = 0
    while (
        suffix < len(old) - prefix
        and suffix < len(new) - prefix
        and old[len(old) - 1 - suffix] == new[len(new) - 1 - suffix]
    ):
        suffix += 1

    nvim.api.buf_set_lines(
        buf,
        prefix,
        len(old) - suffix,
        False,
        new[prefix : len(new) - suffix],
    )


def _set_extmarks(nvim: pynvim.Nvim, state, buf: int, ns: int, marks: list[dict]) -> None:
    ui = state.ui
    next_ids: dict[str, int] = {}
    for mark in marks:
        opts = dict(mark["opts"])
        old_id = ui.output_extmarks.get(mark["key"])
        if old_id:
            opts["id"] = old_id
        try:
            next_ids[mark["key"]] = nvim.api.buf_set_extmark(
                buf, ns, mark["row"], mark["col"], opts
            )
        except Exception:
            pass

    for key, mark_id in list(ui.output_extmarks.items()):
        if key not in next_ids:
            try:
                nvim.api.buf_del_extmark(buf, ns, mark_id)
            except Exception:
                pass
    ui.output_extmarks = next_ids


def render_output(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    buf = ui.output_buf
    if not buf or not nvim.api.buf_is_valid(buf):
        return

    ns = nvim.api.create_namespace(_NS)
    items = ui.output_items
    start = max(0, len(items) - MAX_VIEW)

    lines: list[str] = []
    grps: list[str] = []
    stamps: list[str | None] = []
    marks: list[dict] = []

    for item in items[start:]:
        text, grp, ts = _fmt(item)
        lines.append(text)
        grps.append(grp)
        stamps.append(ts)

    if not lines:
        lines = [_EMPTY_LINE]
        grps = [_EMPTY_HL]
        stamps = [None]

    for i, (line, grp, ts) in enumerate(zip(lines, grps, stamps)):
        marks.append(
            {
                "key": f"line:{start + i}:hl:{grp}",
                "row": i,
                "col": 0,
                "opts": {"end_col": len(line), "hl_group": grp, "priority": 5},
            }
        )
        if ts:
            marks.append(
                {
                    "key": f"line:{start + i}:ts",
                    "row": i,
                    "col": 0,
                    "opts": {
                        "virt_text": [[ts, "GoDbgOutTs"]],
                        "virt_text_pos": "right_align",
                        "priority": 3,
                    },
                }
            )

    mark_sig = [m["key"] for m in marks]
    if lines == ui.output_lines and mark_sig == ui.output_mark_sig:
        _set_winbar(nvim, state)
        return

    try:
        try:
            nvim.api.set_option_value("modifiable", True, {"buf": buf})
            _apply_line_diff(nvim, buf, ui.output_lines, lines)
            _set_extmarks(nvim, state, buf, ns, marks)
        except Exception:
            # Catch "Buffer is not modifiable" or other NvimErrors during write
            return
    finally:
        try:
            nvim.api.set_option_value("modifiable", False, {"buf": buf})
        except Exception:
            pass

    ui.output_lines = lines
    ui.output_mark_sig = mark_sig

    # Auto-scroll only when the user is already at the bottom.
    win = ui.output_win
    if win and nvim.api.win_is_valid(win):
        try:
            row = nvim.api.win_get_cursor(win)[0]
            if row >= max(1, len(ui.output_lines) - 1):
                nvim.api.win_set_cursor(win, [len(lines), 0])
        except Exception:
            pass
        _set_winbar(nvim, state)


def _set_winbar(nvim: pynvim.Nvim, state) -> None:
    win = state.ui.output_win
    if not win or not nvim.api.win_is_valid(win):
        return

    status = (state.ui.last_status or "").replace("\n", " ")
    if len(status) > 64:
        status = status[:63] + "…"

    # e.g.:  󰆍 Output                ⏸ program stopped
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
