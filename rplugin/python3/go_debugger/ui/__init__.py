"""go_debugger.ui – Neovim UI subsystem.

Public surface
──────────────
layout    open_ui / close_ui / toggle_ui / refresh_ui / scroll_output_bottom
sidebar   render_sidebar / sidebar_select / sidebar_next_section
output    render_output
virt      apply_virt / clear_virt / toggle_virt / is_enabled
hover     show_hover / close_hover / show_inspector / close_inspector
toolbar   open_toolbar / close_toolbar / toolbar_next / toolbar_prev / toolbar_exec
help      open_help
highlights setup
"""

from .highlights import setup as setup_highlights, ICON, val_hl, type_icon
from .layout import open_ui, close_ui, toggle_ui, refresh_ui, scroll_output_bottom
from .sidebar import render_sidebar, sidebar_select, sidebar_next_section, sb_width
from .output import render_output
from .virt import apply_virt, clear_virt, toggle_virt, is_enabled
from .hover import show_hover, close_hover, show_inspector, close_inspector
from .toolbar import (
    open_toolbar,
    close_toolbar,
    toolbar_next,
    toolbar_prev,
    toolbar_exec,
)
from .help import open_help

__all__ = [
    "setup_highlights",
    "ICON",
    "val_hl",
    "type_icon",
    "open_ui",
    "close_ui",
    "toggle_ui",
    "refresh_ui",
    "scroll_output_bottom",
    "render_sidebar",
    "sidebar_select",
    "sidebar_next_section",
    "sb_width",
    "render_output",
    "apply_virt",
    "clear_virt",
    "toggle_virt",
    "is_enabled",
    "show_hover",
    "close_hover",
    "show_inspector",
    "close_inspector",
    "open_toolbar",
    "close_toolbar",
    "toolbar_next",
    "toolbar_prev",
    "toolbar_exec",
    "open_help",
]
