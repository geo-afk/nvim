"""Help popup — toggle with ? from sidebar or output panel."""

from __future__ import annotations
import pynvim
from .highlights import ICON

_NS = "go_dbg_help"
_PAD = "  "
_KEY_W = 18

_SECTIONS: list[tuple[str, list[tuple[str, str]]]] = [
    (
        "Execution",
        [
            ("c / <F5>", "Continue"),
            ("n / <F10>", "Step over"),
            ("s / <F11>", "Step into"),
            ("o / <F12>", "Step out"),
            ("z", "Pause"),
            ("<leader>dq", "Stop session"),
            ("<leader>dr", "Restart session"),
            ("<leader>dg", "Run to cursor"),
        ],
    ),
    (
        "Breakpoints",
        [
            ("<leader>dp", "Toggle breakpoint"),
            ("<leader>dP", "Conditional breakpoint"),
            ("<leader>dL", "Logpoint"),
            ("<leader>dH", "Hit-count breakpoint"),
            ("<leader>dx", "Remove breakpoint"),
            ("<leader>dX", "Clear all breakpoints"),
        ],
    ),
    (
        "Inspection",
        [
            ("<leader>dk", "Hover evaluate"),
            ("<leader>de", "Inspect expression"),
            ("<leader>dE", "Set variable value"),
            ("<leader>dw", "Add watch expression"),
            ("<leader>dW", "Remove watch expression"),
            ("<leader>dV", "Toggle inline virt text"),
        ],
    ),
    (
        "Navigation",
        [
            ("<CR>", "Expand / collapse"),
            ("<Tab>", "Next section"),
            ("<S-Tab>", "Prev section"),
            ("R", "Refresh layout"),
            ("q / <Esc>", "Close panel"),
            ("?", "Toggle this help"),
        ],
    ),
    (
        "Launch",
        [
            ("<leader>dd", "Start debug"),
            ("<leader>dt", "Debug test package"),
            ("<leader>db", "Build + debug binary"),
            ("<leader>da", "Attach to PID"),
            ("<leader>du", "Toggle UI"),
            ("<leader>dC", "Connect to dlv"),
        ],
    ),
]


def _build() -> tuple[list[str], list[tuple[int, int, int, str]]]:
    lines: list[str] = []
    hls: list[tuple[int, int, int, str]] = []

    def row(text: str, hl: str | None = None, c0: int = 0) -> None:
        r = len(lines)
        lines.append(text)
        if hl:
            hls.append((r, c0, len(text), hl))

    row(f" {ICON['debugger']}  Go Debugger — Keymaps ", "GoDbgSectionHdr")
    lines.append("")

    for title, entries in _SECTIONS:
        row(f" {ICON['scope']}  {title}", "GoDbgScopeName")
        for key, desc in entries:
            r = len(lines)
            kp = f"{_PAD}{key:<{_KEY_W}}"
            text = f"{kp}  {desc}"
            lines.append(text)
            hls.append((r, len(_PAD), len(_PAD) + _KEY_W, "GoDbgSectionKey"))
            hls.append((r, len(_PAD) + _KEY_W + 2, len(text), "GoDbgFrameInact"))
        lines.append("")

    row("  q / <Esc> / ?  close", "Comment")
    return lines, hls


def open_help(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    if ui.help_win is not None:
        if nvim.api.win_is_valid(ui.help_win):
            try:
                nvim.api.win_close(ui.help_win, True)
            except Exception:
                pass
        ui.help_win = None
        return

    lines, hls = _build()
    width = max(len(l) for l in lines) + 2
    height = len(lines)

    buf = nvim.api.create_buf(False, True)
    for k, v in [("bufhidden", "wipe"), ("buftype", "nofile"), ("modifiable", True)]:
        nvim.api.set_option_value(k, v, {"buf": buf})
    nvim.api.buf_set_lines(buf, 0, -1, False, lines)
    nvim.api.set_option_value("modifiable", False, {"buf": buf})

    ns = nvim.api.create_namespace(_NS)
    for row, c0, c1, grp in hls:
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

    uw = nvim.options["columns"]
    uh = nvim.options["lines"]
    cfg: dict = {
        "relative": "editor",
        "width": width,
        "height": height,
        "row": max(0, (uh - height) // 2),
        "col": max(0, (uw - width) // 2),
        "style": "minimal",
        "border": "rounded",
        "title": " Help ",
        "title_pos": "center",
        "focusable": True,
        "zindex": 200,
        "noautocmd": True,
    }
    try:
        ui.help_win = nvim.api.open_win(buf, True, cfg)
    except Exception:
        return

    nvim.api.set_option_value(
        "winhl",
        "Normal:NormalFloat,FloatBorder:GoDbgAccent,FloatTitle:GoDbgSectionHdr",
        {"win": ui.help_win},
    )
    nvim.api.set_option_value("cursorline", False, {"win": ui.help_win})

    for key in ("q", "<Esc>", "?"):
        nvim.api.buf_set_keymap(
            buf, "n", key, "<cmd>GoDlvUIHelp<CR>", {"silent": True, "nowait": True}
        )
