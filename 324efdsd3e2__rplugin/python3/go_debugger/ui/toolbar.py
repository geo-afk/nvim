"""Debug control toolbar.

Rendered as a floating bar anchored to the top of the editor.
Replaces controls.py with a cleaner, self-contained implementation.

  ╭─ Debug ─────────────────────────────────╮
  │  󰐊   󰆹   󰆽   󰆾   󰏤   󰓛   󰑓             │
  ╰─────────────────────────────────────────╯

- h / l / ← / → : cycle selection
- <CR>           : execute action
- The selected button shows its label as overlay virt-text.
"""

from __future__ import annotations
import pynvim
from .highlights import ICON

_NS = "go_dbg_toolbar"
_PAD = " "

# (icon, method_suffix, default_hl, label)
ACTIONS: list[tuple[str, str, str, str]] = [
    (ICON["ctrl_continue"], "continue", "GoDbgCtrlContinue", "Continue"),
    (ICON["ctrl_next"], "step_over", "GoDbgCtrlStep", "Next"),
    (ICON["ctrl_into"], "step_into", "GoDbgCtrlStep", "Step In"),
    (ICON["ctrl_out"], "step_out", "GoDbgCtrlStep", "Step Out"),
    (ICON["ctrl_pause"], "pause", "GoDbgCtrlPause", "Pause"),
    (ICON["ctrl_stop"], "stop", "GoDbgCtrlStop", "Stop"),
    (ICON["ctrl_restart"], "restart", "GoDbgCtrlRestart", "Restart"),
]


def _bar_text() -> str:
    return "".join(f"{_PAD}{a[0]}{_PAD}" for a in ACTIONS)


def _cell_start(idx: int) -> int:
    return sum(len(_PAD) + len(ACTIONS[j][0]) + len(_PAD) for j in range(idx))


def open_toolbar(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    if ui.toolbar_win and nvim.api.win_is_valid(ui.toolbar_win):
        return

    buf = nvim.api.create_buf(False, True)
    for k, v in [
        ("bufhidden", "wipe"),
        ("buftype", "nofile"),
        ("filetype", "godebug_toolbar"),
    ]:
        nvim.api.set_option_value(k, v, {"buf": buf})
    ui.toolbar_buf = buf
    if not hasattr(ui, "toolbar_idx"):
        ui.toolbar_idx = 0

    _render_bar(nvim, state)

    total = len(_bar_text())
    sw = max(34, int(nvim.options["columns"] * 0.22))
    col = max(0, nvim.options["columns"] - sw - total - 2)

    cfg: dict = {
        "relative": "editor",
        "width": total,
        "height": 1,
        "row": 0,
        "col": col,
        "style": "minimal",
        "border": "rounded",
        "title": " Debug ",
        "title_pos": "center",
        "focusable": False,
        "zindex": 150,
        "noautocmd": True,
    }
    try:
        ui.toolbar_win = nvim.api.open_win(buf, False, cfg)
        nvim.api.set_option_value(
            "winhl",
            "Normal:NormalFloat,FloatBorder:GoDbgAccent",
            {"win": ui.toolbar_win},
        )
    except Exception:
        ui.toolbar_win = None


def close_toolbar(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    if ui.toolbar_win and nvim.api.win_is_valid(ui.toolbar_win):
        try:
            nvim.api.win_close(ui.toolbar_win, True)
        except Exception:
            pass
    ui.toolbar_win = None
    ui.toolbar_buf = None


def toolbar_next(nvim: pynvim.Nvim, state) -> None:
    state.ui.toolbar_idx = (state.ui.toolbar_idx + 1) % len(ACTIONS)
    _render_bar(nvim, state)


def toolbar_prev(nvim: pynvim.Nvim, state) -> None:
    state.ui.toolbar_idx = (state.ui.toolbar_idx - 1) % len(ACTIONS)
    _render_bar(nvim, state)


def toolbar_exec(nvim: pynvim.Nvim, state, plugin) -> None:
    action = ACTIONS[state.ui.toolbar_idx][1]
    fn = getattr(plugin, f"dbg_{action}", None)
    if callable(fn):
        fn()


# ── internal ──────────────────────────────────────────────────────────────────


def _render_bar(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    buf = getattr(ui, "toolbar_buf", None)
    if not buf or not nvim.api.buf_is_valid(buf):
        return

    text = _bar_text()
    try:
        nvim.api.set_option_value("modifiable", True, {"buf": buf})
        nvim.api.buf_set_lines(buf, 0, -1, False, [text])
    finally:
        try:
            nvim.api.set_option_value("modifiable", False, {"buf": buf})
        except Exception:
            pass

    ns = nvim.api.create_namespace(_NS)
    nvim.api.buf_clear_namespace(buf, ns, 0, -1)

    sel = getattr(ui, "toolbar_idx", 0)
    col = 0
    for i, (icon, _, hl, label) in enumerate(ACTIONS):
        cell = len(_PAD) + len(icon) + len(_PAD)
        grp = "GoDbgCtrlSel" if i == sel else hl
        try:
            nvim.api.buf_set_extmark(
                buf,
                ns,
                0,
                col,
                {
                    "end_col": col + cell,
                    "hl_group": grp,
                    "priority": 100,
                },
            )
        except Exception:
            pass
        if i == sel:
            try:
                nvim.api.buf_set_extmark(
                    buf,
                    ns,
                    0,
                    col,
                    {
                        "virt_text": [[f" {label} ", "GoDbgCtrlLabel"]],
                        "virt_text_pos": "overlay",
                        "virt_text_win_col": col,
                        "priority": 200,
                    },
                )
            except Exception:
                pass
        col += cell
