"""Inspector floating window for detailed variable view."""
from __future__ import annotations
import pynvim
from .highlights import ICON, val_hl

_NS = "go_dbg_inspector"
_inspect_win: list[int | None] = [None]


def close_inspector(nvim: pynvim.Nvim) -> None:
    """Close the inspector window if it is open."""
    w = _inspect_win[0]
    if w is not None and nvim.api.win_is_valid(w):
        try:
            nvim.api.win_close(w, True)
        except Exception:
            pass
    _inspect_win[0] = None


def show_inspector(
    nvim: pynvim.Nvim, name: str, variables: list, vref: int, val: str
) -> None:
    """Open the inspector float to show variable details."""
    close_inspector(nvim)

    lines = []
    hls = []  # list of (row, c0, c1, hl_group)

    # Header
    header = f" {ICON['variables']}  {name}"
    lines.append(header)
    hls.append((0, 0, 2 + len(ICON["variables"]), "GoDbgSectionIcon"))
    hls.append((0, 4, len(header), "GoDbgSectionHdr"))

    lines.append(" " + "─" * (min(40, len(header) + 4)))
    hls.append((1, 0, -1, "GoDbgDivider"))

    if not variables:
        if vref > 0:
            lines.append("  (loading or empty)")
        else:
            line = f"  Value: {val}"
            row = len(lines)
            lines.append(line)
            hls.append((row, 2, 7, "GoDbgHoverLabel"))
            hls.append((row, 9, len(line), val_hl(val)))
    else:
        for i, v in enumerate(variables):
            vname = str(v.get("name") or i)
            val = str(v.get("value") or "")
            # typ = str(v.get("type") or "")

            line = f"  {vname} = {val}"
            row = len(lines)
            lines.append(line)

            # Syntax highlighting for the inspector line
            c0 = 2
            c1 = c0 + len(vname)
            hls.append((row, c0, c1, "GoDbgVarName"))

            c0_eq = c1 + 1
            c1_eq = c0_eq + 1
            hls.append((row, c0_eq, c1_eq, "GoDbgVarEq"))

            c0_val = c1_eq + 1
            hls.append((row, c0_val, len(line), val_hl(val)))

    # Compute size
    max_w = 40
    for l in lines:
        try:
            max_w = max(max_w, nvim.funcs.strdisplaywidth(l))
        except Exception:
            max_w = max(max_w, len(l))

    width = min(80, max_w + 2)
    height = min(20, len(lines))

    buf = nvim.api.create_buf(False, True)
    nvim.api.set_option_value("bufhidden", "wipe", {"buf": buf})
    nvim.api.set_option_value("buftype", "nofile", {"buf": buf})

    nvim.api.buf_set_lines(buf, 0, -1, False, lines)

    ns = nvim.api.create_namespace(_NS)
    for row, c0, c1, grp in hls:
        try:
            if c1 == -1:
                c1 = len(lines[row])
            nvim.api.buf_set_extmark(
                buf,
                ns,
                row,
                c0,
                {
                    "end_col": c1,
                    "hl_group": grp,
                },
            )
        except Exception:
            pass

    cfg = {
        "relative": "win",
        "win": nvim.api.get_current_win(),
        "row": 2,
        "col": 5,
        "width": width,
        "height": height,
        "style": "minimal",
        "border": "rounded",
        "title": " Inspector ",
        "title_pos": "center",
        "zindex": 100,
        "focusable": True,
    }

    try:
        win = nvim.api.open_win(buf, False, cfg)
        nvim.api.set_option_value(
            "winhl", "Normal:NormalFloat,FloatBorder:GoDbgAccent", {"win": win}
        )
        _inspect_win[0] = win

        # Close on next move
        nvim.command(
            "autocmd CursorMoved,CursorMovedI,InsertEnter,BufLeave <buffer> ++once GoDlvUICloseInspector"
        )
    except Exception:
        pass
