"""Hover evaluation and inspector floating windows.

hover    – compact 3-line float anchored to cursor (auto-closes on move)
inspector – detailed variable tree float, manually dismissed
"""

from __future__ import annotations
import pynvim
from .highlights import ICON, val_hl

_NS_HOVER = "go_dbg_hover"
_NS_INSP = "go_dbg_insp"

_hover_win: list[int | None] = [None]
_inspect_win: list[int | None] = [None]


# ── hover ─────────────────────────────────────────────────────────────────────


def close_hover(nvim: pynvim.Nvim) -> None:
    _close_win(nvim, _hover_win)


def show_hover(nvim: pynvim.Nvim, expr: str, result: str, typ: str) -> None:
    close_hover(nvim)
    typ_str = typ or "unknown"
    lines = [
        f" {ICON['hover_name']}  {expr}",
        f" {ICON['hover_type']}  {typ_str}",
        f" {ICON['hover_val']}  {result}",
    ]
    width = _display_width(nvim, lines) + 4

    buf = _scratch_buf(nvim)
    _write_lines(nvim, buf, lines)

    ns = nvim.api.create_namespace(_NS_HOVER)
    _hl(nvim, buf, ns, 0, 0, 2 + len(ICON["hover_name"]), "GoDbgHoverLabel")
    _hl(nvim, buf, ns, 0, 2 + len(ICON["hover_name"]), len(lines[0]), "GoDbgHoverTitle")
    _hl(nvim, buf, ns, 1, 0, 2 + len(ICON["hover_type"]), "GoDbgHoverLabel")
    _hl(nvim, buf, ns, 1, 2 + len(ICON["hover_type"]), len(lines[1]), "GoDbgHoverType")
    _hl(nvim, buf, ns, 2, 0, 2 + len(ICON["hover_val"]), "GoDbgHoverLabel")
    _hl(nvim, buf, ns, 2, 2 + len(ICON["hover_val"]), len(lines[2]), "GoDbgHoverVal")

    win = _open_float(
        nvim,
        buf,
        {
            "relative": "cursor",
            "row": 1,
            "col": 0,
            "width": min(width, 80),
            "height": len(lines),
            "title": " Inspect ",
            "zindex": 60,
        },
    )
    if win:
        _hover_win[0] = win
        nvim.command(
            "autocmd CursorMoved,CursorMovedI,InsertEnter,BufLeave <buffer>"
            " ++once GoDlvCloseHover"
        )


# ── inspector ─────────────────────────────────────────────────────────────────


def close_inspector(nvim: pynvim.Nvim) -> None:
    _close_win(nvim, _inspect_win)


def show_inspector(
    nvim: pynvim.Nvim,
    name: str,
    variables: list,
    vref: int,
    val: str,
) -> None:
    close_inspector(nvim)

    lines: list[str] = []
    hls: list[tuple[int, int, int, str]] = []

    def add(text: str, h: str | None = None, c0: int = 0, c1: int = -1) -> int:
        r = len(lines)
        lines.append(text)
        if h:
            hls.append((r, c0, len(text) if c1 == -1 else c1, h))
        return r

    add(f" {ICON['variables']}  {name}", "GoDbgSectionHdr", 4)
    add(" " + "─" * min(40, len(name) + 8), "GoDbgDivider")

    if not variables:
        if vref > 0:
            add("  (loading…)", "GoDbgEmpty")
        else:
            r = add(f"  Value: {val}")
            hls.append((r, 2, 8, "GoDbgHoverLabel"))
            hls.append((r, 9, len(lines[-1]), val_hl(val)))
    else:
        for i, v in enumerate(variables):
            vname = str(v.get("name") or i)
            vval = str(v.get("value") or "")
            row_text = f"  {vname} = {vval}"
            r = add(row_text)
            c0 = 2
            c1 = c0 + len(vname)
            hls.append((r, c0, c1, "GoDbgVarName"))
            hls.append((r, c1 + 1, c1 + 2, "GoDbgVarEq"))
            hls.append((r, c1 + 3, len(row_text), val_hl(vval)))

    width = min(80, _display_width(nvim, lines) + 2)
    height = min(24, len(lines))

    buf = _scratch_buf(nvim)
    _write_lines(nvim, buf, lines)

    ns = nvim.api.create_namespace(_NS_INSP)
    for row, c0, c1, grp in hls:
        _hl(nvim, buf, ns, row, c0, c1, grp)

    win = _open_float(
        nvim,
        buf,
        {
            "relative": "win",
            "win": nvim.api.get_current_win(),
            "row": 2,
            "col": 5,
            "width": width,
            "height": height,
            "title": " Inspector ",
            "zindex": 100,
        },
    )
    if win:
        _inspect_win[0] = win
        nvim.command(
            "autocmd CursorMoved,CursorMovedI,InsertEnter,BufLeave <buffer>"
            " ++once GoDlvUICloseInspector"
        )


# ── shared utilities ──────────────────────────────────────────────────────────


def _close_win(nvim: pynvim.Nvim, slot: list) -> None:
    w = slot[0]
    if w is not None and nvim.api.win_is_valid(w):
        try:
            nvim.api.win_close(w, True)
        except Exception:
            pass
    slot[0] = None


def _scratch_buf(nvim: pynvim.Nvim) -> int:
    buf = nvim.api.create_buf(False, True)
    for k, v in [("bufhidden", "wipe"), ("buftype", "nofile")]:
        nvim.api.set_option_value(k, v, {"buf": buf})
    return buf


def _write_lines(nvim: pynvim.Nvim, buf: int, lines: list[str]) -> None:
    nvim.api.set_option_value("modifiable", True, {"buf": buf})
    nvim.api.buf_set_lines(buf, 0, -1, False, lines)
    nvim.api.set_option_value("modifiable", False, {"buf": buf})


def _open_float(nvim: pynvim.Nvim, buf: int, extra: dict) -> int | None:
    cfg: dict = {
        "style": "minimal",
        "border": "rounded",
        "title_pos": "center",
        "focusable": True,
        "noautocmd": True,
        **extra,
    }
    try:
        win = nvim.api.open_win(buf, False, cfg)
        nvim.api.set_option_value(
            "winhl",
            "Normal:NormalFloat,FloatBorder:GoDbgAccent,FloatTitle:GoDbgSectionHdr",
            {"win": win},
        )
        nvim.api.set_option_value("cursorline", False, {"win": win})
        return win
    except Exception:
        return None


def _hl(
    nvim: pynvim.Nvim, buf: int, ns: int, row: int, c0: int, c1: int, grp: str
) -> None:
    if c1 <= c0:
        return
    try:
        nvim.api.buf_set_extmark(
            buf,
            ns,
            row,
            c0,
            {
                "end_col": c1,
                "hl_group": grp,
                "priority": 10,
            },
        )
    except Exception:
        pass


def _display_width(nvim: pynvim.Nvim, lines: list[str]) -> int:
    try:
        return max(nvim.funcs.strdisplaywidth(l) for l in lines)
    except Exception:
        return max(len(l) for l in lines)
