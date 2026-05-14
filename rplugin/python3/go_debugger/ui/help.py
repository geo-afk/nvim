"""Help popup — opened with `?` from the sidebar or output panel.

Shows all keymaps grouped by category in a centered floating window.
Close with q, <Esc>, or ?.
"""
from __future__ import annotations
import pynvim
from .highlights import ICON

_NS = "go_dbg_help"

# (key_label, description)
_SECTIONS: list[tuple[str, list[tuple[str, str]]]] = [
    ("Execution (Session active)", [
        ("c or <F5>",   "Continue"),
        ("n or <F10>",  "Step over (next)"),
        ("s or <F11>",  "Step into"),
        ("o or <F12>",  "Step out"),
        ("z",           "Pause"),
        ("<leader>dq",  "Stop session"),
        ("<leader>dr",  "Restart session"),
        ("<leader>dg",  "Run to cursor"),
    ]),
    ("Breakpoints", [
        ("<leader>dp",  "Toggle breakpoint"),
        ("<leader>dP",  "Conditional breakpoint"),
        ("<leader>dL",  "Logpoint"),
        ("<leader>dH",  "Hit-count breakpoint"),
        ("<leader>dx",  "Remove breakpoint"),
        ("<leader>dX",  "Clear all breakpoints"),
    ]),
    ("Inspection", [
        ("<leader>dk",  "Hover evaluate"),
        ("<leader>de",  "Inspect expression"),
        ("<leader>dE",  "Set variable value"),
        ("<leader>dw",  "Add watch expression"),
        ("<leader>dW",  "Remove watch expression"),
        ("<leader>dV",  "Toggle inline virt text"),
    ]),
    ("Navigation (Sidebar)", [
        ("<CR>",        "Expand / collapse section"),
        ("<Tab>",       "Jump to next section"),
        ("<S-Tab>",     "Jump to prev section"),
        ("R",           "Refresh layout"),
    ]),
    ("UI & Launch", [
        ("<leader>dd",  "Start debug (main pkg)"),
        ("<leader>dt",  "Debug test package"),
        ("<leader>db",  "Build + debug binary"),
        ("<leader>da",  "Attach to PID"),
        ("<leader>du",  "Toggle debug UI"),
        ("<leader>dC",  "Connect to dlv (host:port)"),
        ("q / <Esc>",   "Close panel"),
        ("?",           "Toggle this help"),
    ]),
]

_KEY_W  = 18   # width of key column
_DESC_W = 32   # width of description column
_PAD    = "  "


def _build_lines() -> tuple[list[str], list[tuple[int, int, int, str]]]:
    """Return (lines, [(row, col_start, col_end, hl_group)])."""
    lines: list[str]                        = []
    hls:   list[tuple[int, int, int, str]]  = []

    def add(text: str, hl: str | None = None, col: int = 0) -> None:
        r = len(lines)
        lines.append(text)
        if hl:
            hls.append((r, col, len(text), hl))

    # title bar
    title = f" {ICON['debugger']}  Go Debugger — Keymaps "
    add(title, "GoDbgSectionHdr")
    lines.append("")

    for sec_name, entries in _SECTIONS:
        # section header
        hdr = f" {ICON['scope']}  {sec_name}"
        add(hdr, "GoDbgScopeName")

        for key, desc in entries:
            r   = len(lines)
            kp  = f"{_PAD}{key:<{_KEY_W}}"
            dp  = desc
            row = f"{kp}  {dp}"
            lines.append(row)
            hls.append((r, len(_PAD),                len(_PAD) + _KEY_W,      "GoDbgSectionKey"))
            hls.append((r, len(_PAD) + _KEY_W + 2,   len(row),                "GoDbgFrameInact"))

        lines.append("")

    # footer
    foot = "  q / <Esc> / ?  close"
    add(foot, "Comment")

    return lines, hls


def open_help(nvim: pynvim.Nvim, state) -> None:
    """Open (or close if already open) the help float."""
    ui = state.ui
    if ui.help_win is not None:
        if nvim.api.win_is_valid(ui.help_win):
            try:
                nvim.api.win_close(ui.help_win, True)
            except Exception:
                pass
        ui.help_win = None
        return

    lines, hls = _build_lines()
    width  = max(len(l) for l in lines) + 2
    height = len(lines)

    buf = nvim.api.create_buf(False, True)
    for k, v in [
        ("bufhidden", "wipe"),
        ("buftype",   "nofile"),
        ("modifiable", True),
    ]:
        nvim.api.set_option_value(k, v, {"buf": buf})

    nvim.api.buf_set_lines(buf, 0, -1, False, lines)
    nvim.api.set_option_value("modifiable", False, {"buf": buf})

    ns = nvim.api.create_namespace(_NS)
    for (row, c0, c1, grp) in hls:
        try:
            nvim.api.buf_set_extmark(buf, ns, row, c0, {
                "end_col":  c1,
                "hl_group": grp,
                "priority": 10,
            })
        except Exception:
            pass

    # center on screen
    ui_width  = nvim.options["columns"]
    ui_height = nvim.options["lines"]
    row = max(0, (ui_height - height) // 2)
    col = max(0, (ui_width  - width)  // 2)

    win_cfg: dict = {
        "relative":  "editor",
        "width":     width,
        "height":    height,
        "row":       row,
        "col":       col,
        "style":     "minimal",
        "border":    "rounded",
        "title":     " Help ",
        "title_pos": "center",
        "focusable": True,
        "zindex":    200,
        "noautocmd": True,
    }
    try:
        ui.help_win = nvim.api.open_win(buf, True, win_cfg)
    except Exception:
        return

    nvim.api.set_option_value(
        "winhl",
        "Normal:NormalFloat,FloatBorder:GoDbgAccent,FloatTitle:GoDbgSectionHdr",
        {"win": ui.help_win},
    )
    nvim.api.set_option_value("cursorline", False, {"win": ui.help_win})

    # close mappings inside the help buffer
    for key in ("q", "<Esc>", "?"):
        nvim.api.buf_set_keymap(buf, "n", key,
                                "<cmd>GoDlvUIHelp<CR>",
                                {"silent": True, "nowait": True})
