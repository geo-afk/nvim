"""Hover evaluation floating window.

Opens a compact float near the cursor showing the inspected expression,
its type, and its current value.  Only one hover window is shown at a time;
any previous one is closed before opening a new one.

Uses only the modern ``nvim.api.set_option_value`` API (no deprecated
``buf_set_option`` calls).
"""
from __future__ import annotations
import pynvim
from .highlights import ICON

_NS       = "go_dbg_hover"
_hover_win: list[int | None] = [None]


def close_hover(nvim: pynvim.Nvim) -> None:
    """Close the hover window if it is open."""
    w = _hover_win[0]
    if w is not None and nvim.api.win_is_valid(w):
        try:
            nvim.api.win_close(w, True)
        except Exception:
            pass
    _hover_win[0] = None


def show_hover(nvim: pynvim.Nvim, expr: str, result: str, typ: str) -> None:
    """Open the hover inspect float near the cursor."""
    close_hover(nvim)

    typ_str = typ or "unknown"
    lines = [
        f" {ICON['hover_name']}  {expr}",
        f" {ICON['hover_type']}  {typ_str}",
        f" {ICON['hover_val']}  {result}",
    ]

    # Compute width from the longest visible line.
    try:
        max_w = max(nvim.funcs.strdisplaywidth(l) for l in lines) + 4
    except Exception:
        max_w = max(len(l) for l in lines) + 4
    width = min(max_w, 80)

    # Create a throw-away buffer.
    buf = nvim.api.create_buf(False, True)
    for k, v in [
        ("bufhidden", "wipe"),
        ("buftype",   "nofile"),
        ("modifiable", True),
    ]:
        nvim.api.set_option_value(k, v, {"buf": buf})

    nvim.api.buf_set_lines(buf, 0, -1, False, lines)
    nvim.api.set_option_value("modifiable", False, {"buf": buf})

    # Highlight labels (icon column) and value spans.
    ns = nvim.api.create_namespace(_NS)
    label_end = 2  # icon + space

    _add_hl(nvim, buf, ns, 0, 0, label_end + len(ICON["hover_name"]), "GoDbgHoverLabel")
    _add_hl(nvim, buf, ns, 0, label_end + len(ICON["hover_name"]), len(lines[0]), "GoDbgHoverTitle")

    _add_hl(nvim, buf, ns, 1, 0, label_end + len(ICON["hover_type"]), "GoDbgHoverLabel")
    _add_hl(nvim, buf, ns, 1, label_end + len(ICON["hover_type"]), len(lines[1]), "GoDbgHoverType")

    _add_hl(nvim, buf, ns, 2, 0, label_end + len(ICON["hover_val"]), "GoDbgHoverLabel")
    _add_hl(nvim, buf, ns, 2, label_end + len(ICON["hover_val"]), len(lines[2]), "GoDbgHoverVal")

    cfg: dict = {
        "relative":    "cursor",
        "row":         1,
        "col":         0,
        "width":       width,
        "height":      len(lines),
        "style":       "minimal",
        "border":      "rounded",
        "title":       " Inspect ",
        "title_pos":   "center",
        "focusable":   True,
        "zindex":      50,
        "noautocmd":   True,
    }
    try:
        win = nvim.api.open_win(buf, False, cfg)
        nvim.api.set_option_value(
            "winhl",
            "Normal:NormalFloat,FloatBorder:GoDbgAccent",
            {"win": win},
        )
        _hover_win[0] = win

        # Close on next cursor move or mode change
        nvim.command("autocmd CursorMoved,CursorMovedI,InsertEnter,BufLeave <buffer> ++once GoDlvCloseHover")
    except Exception:
        pass


# ── helpers ───────────────────────────────────────────────────────────────────

def _add_hl(
    nvim: pynvim.Nvim,
    buf: int,
    ns: int,
    row: int,
    c0: int,
    c1: int,
    grp: str,
) -> None:
    if c1 <= c0:
        return
    try:
        nvim.api.buf_set_extmark(buf, ns, row, c0, {
            "end_col":  c1,
            "hl_group": grp,
            "priority": 10,
        })
    except Exception:
        pass
