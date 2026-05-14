"""Floating debug control bar.

Renders a compact toolbar near the top-right of the editor:

  ╭─ Debug ──────────────────╮
  │  󰐊    󰆹    󰆽    󰆾   󰏤   󰓛   󰑓  │
  ╰──────────────────────────╯

Navigation: h/l or ←/→ to move the selection, <CR> to execute.
The selected button is highlighted with GoDbgBtnSel.
"""
from __future__ import annotations
import pynvim

# (icon, action_suffix, default_hl, label)
CONTROLS: list[tuple[str, str, str, str]] = [
    ("󰐊", "continue",  "GoDbgBtnContinue", "Continue"),
    ("󰆹", "step_over", "GoDbgBtnStep",     "Next"),
    ("󰆽", "step_into", "GoDbgBtnStep",     "Step In"),
    ("󰆾", "step_out",  "GoDbgBtnStep",     "Step Out"),
    ("󰏤", "pause",     "GoDbgBtnPause",    "Pause"),
    ("󰓛", "stop",      "GoDbgBtnStop",     "Stop"),
    ("󰑓", "restart",   "GoDbgBtnRestart",  "Restart"),
]

_NS      = "go_dbg_controls"
_PADDING = " "   # one space either side of each icon cell: " 󰐊 "


def open_controls(nvim: pynvim.Nvim, state, plugin) -> None:
    """Open the control bar float (idempotent)."""
    ui = state.ui
    if ui.controls_win and nvim.api.win_is_valid(ui.controls_win):
        return

    buf = nvim.api.create_buf(False, True)
    for k, v in [
        ("bufhidden", "wipe"),
        ("buftype",   "nofile"),
        ("filetype",  "godebug_controls"),
    ]:
        nvim.api.set_option_value(k, v, {"buf": buf})
    ui.controls_buf = buf
    ui.controls_idx = 0

    _render_controls(nvim, state)

    # Position: horizontally centred above the sidebar (or near the right edge).
    sw    = max(34, int(nvim.options["columns"] * 0.21))
    total = _bar_width()
    col   = max(0, nvim.options["columns"] - sw - total - 2)

    win_cfg: dict = {
        "relative":  "editor",
        "width":     total,
        "height":    1,
        "row":       0,
        "col":       col,
        "style":     "minimal",
        "border":    "rounded",
        "title":     " Debug ",
        "title_pos": "center",
        "focusable": False,
        "zindex":    150,
        "noautocmd": True,
    }
    try:
        ui.controls_win = nvim.api.open_win(buf, False, win_cfg)
        nvim.api.set_option_value(
            "winhl",
            "Normal:NormalFloat,FloatBorder:GoDbgAccent",
            {"win": ui.controls_win},
        )
    except Exception:
        ui.controls_win = None


def close_controls(nvim: pynvim.Nvim, state) -> None:
    """Close the control bar float."""
    ui = state.ui
    if ui.controls_win and nvim.api.win_is_valid(ui.controls_win):
        try:
            nvim.api.win_close(ui.controls_win, True)
        except Exception:
            pass
    ui.controls_win = None
    ui.controls_buf = None


def control_next(nvim: pynvim.Nvim, state) -> None:
    state.ui.controls_idx = (state.ui.controls_idx + 1) % len(CONTROLS)
    _render_controls(nvim, state)


def control_prev(nvim: pynvim.Nvim, state) -> None:
    state.ui.controls_idx = (state.ui.controls_idx - 1) % len(CONTROLS)
    _render_controls(nvim, state)


def control_exec(nvim: pynvim.Nvim, state, plugin) -> None:
    action = CONTROLS[state.ui.controls_idx][1]
    fn = getattr(plugin, f"dbg_{action}", None)
    if callable(fn):
        fn()


# ── internals ─────────────────────────────────────────────────────────────────

def _bar_width() -> int:
    return sum(len(_PADDING) + len(c[0]) + len(_PADDING) for c in CONTROLS)


def _render_controls(nvim: pynvim.Nvim, state) -> None:
    """Write bar text + extmarks into controls_buf."""
    ui  = state.ui
    buf = ui.controls_buf
    if not buf or not nvim.api.buf_is_valid(buf):
        return

    sel = ui.controls_idx
    text = "".join(f"{_PADDING}{c[0]}{_PADDING}" for c in CONTROLS)

    try:
        nvim.api.set_option_value("modifiable", True, {"buf": buf})
        nvim.api.buf_set_lines(buf, 0, -1, False, [text])
    finally:
        try:
            nvim.api.set_option_value("modifiable", False, {"buf": buf})
        except Exception:
            pass

    ns  = nvim.api.create_namespace(_NS)
    nvim.api.buf_clear_namespace(buf, ns, 0, -1)

    col = 0
    cell_w = len(_PADDING) + 1 + len(_PADDING)  # padding + icon (1 char wide) + padding
    for i, (icon, _, hl, _desc) in enumerate(CONTROLS):
        cell_len = len(_PADDING) + len(icon) + len(_PADDING)
        grp = "GoDbgBtnSel" if i == sel else hl
        try:
            nvim.api.buf_set_extmark(buf, ns, 0, col, {
                "end_col":  col + cell_len,
                "hl_group": grp,
                "priority": 100,
            })
        except Exception:
            pass
        col += cell_len

    # Key-binding tooltip as a virtual line below the selected button
    label_col  = sum(
        len(_PADDING) + len(CONTROLS[j][0]) + len(_PADDING)
        for j in range(sel)
    )
    label_text = f" {CONTROLS[sel][3]} "
    try:
        nvim.api.buf_set_extmark(buf, ns, 0, label_col, {
            "virt_text":     [[label_text, "GoDbgSectionCnt"]],
            "virt_text_pos": "overlay",
            "virt_text_win_col": label_col,
            "priority":      200,
        })
    except Exception:
        pass
