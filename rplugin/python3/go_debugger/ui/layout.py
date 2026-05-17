"""Window layout management.

Layout:
  ┌──────────────────────────┬─────────────┐
  │                          │  Sidebar    │
  │       Editor             │  (22% wide) │
  │                          │             │
  ├──────────────────────────┴─────────────┤
  │  Output panel  (8 rows)                │
  └────────────────────────────────────────┘

Toolbar float anchored top-right (non-focusable).
"""

from __future__ import annotations
import pynvim
from .highlights import setup as setup_hl, ICON
from .sidebar import sb_width, render_sidebar
from .output import _set_winbar
from .toolbar import open_toolbar

_SIDEBAR_OPTS: dict = {
    "number": False,
    "relativenumber": False,
    "signcolumn": "no",
    "wrap": False,
    "cursorline": True,
    "winfixwidth": True,
    "foldcolumn": "0",
    "spell": False,
    "fillchars": "eob: ",
    "scrolloff": 2,
}
_OUTPUT_OPTS: dict = {
    "number": False,
    "relativenumber": False,
    "signcolumn": "no",
    "wrap": False,
    "cursorline": False,
    "winfixheight": True,
    "foldcolumn": "0",
    "spell": False,
    "fillchars": "eob: ",
}


def _set_opts(nvim: pynvim.Nvim, win: int, opts: dict) -> None:
    for k, v in opts.items():
        try:
            nvim.api.set_option_value(k, v, {"win": win})
        except Exception:
            pass


def _make_buf(nvim: pynvim.Nvim, name: str, ft: str) -> int:
    buf = nvim.api.create_buf(False, True)
    for k, v in [
        ("bufhidden", "hide"),
        ("buftype", "nofile"),
        ("swapfile", False),
        ("filetype", ft),
    ]:
        nvim.api.set_option_value(k, v, {"buf": buf})
    try:
        nvim.api.buf_set_name(buf, f"go-debug://{name}")
    except Exception:
        pass
    return buf


def _bind_sidebar(nvim: pynvim.Nvim, buf: int) -> None:
    km = lambda lhs, rhs, desc="": nvim.api.buf_set_keymap(
        buf, "n", lhs, rhs, {"silent": True, "nowait": True, "desc": desc}
    )
    km("q", "<cmd>GoDlvUIClose<CR>", "Close UI")
    km("<Esc>", "<cmd>GoDlvUIClose<CR>", "Close UI")
    km("<CR>", "<cmd>GoDlvUISelect<CR>", "Expand/collapse")
    km("k", "<cmd>GoDlvUIInspect<CR>", "Inspect value")
    km("<LeftMouse>", "<LeftMouse><cmd>GoDlvUISelect<CR>")
    km("<Tab>", "<cmd>GoDlvUINextSection<CR>", "Next section")
    km("<S-Tab>", "<cmd>GoDlvUIPrevSection<CR>", "Prev section")
    km("R", "<cmd>GoDlvUIRefresh<CR>", "Refresh")
    km("c", "<cmd>GoDlvContinue<CR>", "Continue")
    km("n", "<cmd>GoDlvNext<CR>", "Step over")
    km("i", "<cmd>GoDlvStepIn<CR>", "Step into")
    km("o", "<cmd>GoDlvStepOut<CR>", "Step out")
    km("p", "<cmd>GoDlvPause<CR>", "Pause")
    km("s", "<cmd>GoDlvStop<CR>", "Stop")
    km("r", "<cmd>GoDlvRestart<CR>", "Restart")
    km("?", "<cmd>GoDlvUIHelp<CR>", "Help")
    km("h", "<cmd>GoDlvUIToolbarPrev<CR>", "Toolbar prev")
    km("l", "<cmd>GoDlvUIToolbarNext<CR>", "Toolbar next")
    km("<Space>", "<cmd>GoDlvUIToolbarExec<CR>", "Toolbar exec")


def _bind_output(nvim: pynvim.Nvim, buf: int) -> None:
    def km(lhs, rhs):
        return nvim.api.buf_set_keymap(
            buf, "n", lhs, rhs, {"silent": True, "nowait": True}
        )

    km("q", "<cmd>GoDlvUIClose<CR>")
    km("<Esc>", "<cmd>GoDlvUIClose<CR>")
    km("G", "<cmd>GoDlvUIScrollBottom<CR>")
    km("?", "<cmd>GoDlvUIHelp<CR>")


def open_ui(nvim: pynvim.Nvim, state, plugin=None) -> None:
    ui = state.ui
    if ui.open and ui.sidebar_win and nvim.api.win_is_valid(ui.sidebar_win):
        return

    setup_hl(nvim)
    origin = nvim.api.get_current_win()

    if not ui.sidebar_buf or not nvim.api.buf_is_valid(ui.sidebar_buf):
        ui.sidebar_buf = _make_buf(nvim, "sidebar", "godebug_sidebar")
        _bind_sidebar(nvim, ui.sidebar_buf)

    if not ui.output_buf or not nvim.api.buf_is_valid(ui.output_buf):
        ui.output_buf = _make_buf(nvim, "output", "godebug_output")
        _bind_output(nvim, ui.output_buf)

    # output strip (bottom)
    nvim.command("botright 8split")
    ui.output_win = nvim.api.get_current_win()
    nvim.api.win_set_buf(ui.output_win, ui.output_buf)
    _set_opts(nvim, ui.output_win, _OUTPUT_OPTS)

    # restore editor focus before sidebar
    nvim.api.set_current_win(origin)

    # sidebar (right)
    sw = sb_width(nvim)
    nvim.command(f"botright {sw}vsplit")
    ui.sidebar_win = nvim.api.get_current_win()
    nvim.api.win_set_buf(ui.sidebar_win, ui.sidebar_buf)
    _set_opts(nvim, ui.sidebar_win, _SIDEBAR_OPTS)
    _set_sidebar_statusline(nvim, ui.sidebar_win)

    # invalidate writers so they rebuild against fresh buffers
    ui._sb_writer = None
    ui._out_writer = None

    ui.open = True

    if nvim.api.win_is_valid(origin):
        nvim.api.set_current_win(origin)

    render_sidebar(nvim, state)
    _set_winbar(nvim, state)

    if plugin:
        open_toolbar(nvim, state)


def close_ui(nvim: pynvim.Nvim, state, plugin=None) -> None:
    ui = state.ui
    for attr in ("sidebar_win", "output_win", "toolbar_win", "help_win"):
        win = getattr(ui, attr, None)
        if win and nvim.api.win_is_valid(win):
            try:
                nvim.api.win_close(win, True)
            except Exception:
                pass
        setattr(ui, attr, None)
    ui.open = False


def toggle_ui(nvim: pynvim.Nvim, state, plugin=None) -> None:
    ui = state.ui
    if ui.open and ui.sidebar_win and nvim.api.win_is_valid(ui.sidebar_win):
        close_ui(nvim, state, plugin)
    else:
        open_ui(nvim, state, plugin)


def refresh_ui(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    if not ui.open:
        return
    if ui.sidebar_win and nvim.api.win_is_valid(ui.sidebar_win):
        try:
            nvim.api.win_set_width(ui.sidebar_win, sb_width(nvim))
        except Exception:
            pass
        render_sidebar(nvim, state)
    _set_winbar(nvim, state)


def scroll_output_bottom(nvim: pynvim.Nvim, state) -> None:
    win = state.ui.output_win
    if not win or not nvim.api.win_is_valid(win):
        return
    buf = nvim.api.win_get_buf(win)
    lc = nvim.api.buf_line_count(buf)
    try:
        nvim.api.win_set_cursor(win, [lc, 0])
    except Exception:
        pass


def _set_sidebar_statusline(nvim: pynvim.Nvim, win: int) -> None:
    sl = (
        f" %=%#GoDbgSectionIcon#{ICON['debugger']}"
        f"%#GoDbgSectionHdr# Go Debugger %#Normal# "
    )
    try:
        nvim.api.set_option_value("statusline", sl, {"win": win})
    except Exception:
        pass
