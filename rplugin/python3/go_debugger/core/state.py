"""Shared debugger state."""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, Optional


@dataclass
class Breakpoint:
    file: str
    line: int
    condition: Optional[str] = None
    hit_condition: Optional[str] = None
    log_message: Optional[str] = None
    tmp: bool = False

    def bp_key(self) -> str:
        return f"{self.file}:{self.line}"


@dataclass
class UIState:
    open: bool = False

    # windows
    sidebar_win: Optional[int] = None
    output_win: Optional[int] = None
    toolbar_win: Optional[int] = None
    help_win: Optional[int] = None

    # persistent buffers (survive window close/reopen)
    sidebar_buf: Optional[int] = None
    output_buf: Optional[int] = None
    toolbar_buf: Optional[int] = None

    # ── sidebar state ─────────────────────────────────────────────────────────
    # row (0-based) → section key  (built by render_sidebar)
    sec_rows: dict[int, str] = field(default_factory=dict)
    # row (0-based) → arbitrary key string  (variable / frame / bp / watch / goroutine)
    var_row_key: dict[int, str] = field(default_factory=dict)
    # section collapse state  {"variables": True, ...}
    sec_collapsed: dict[str, bool] = field(default_factory=dict)
    # variable expand state  {scope:depth:name → bool}
    var_expanded: dict[str, bool] = field(default_factory=dict)

    # ── toolbar ───────────────────────────────────────────────────────────────
    toolbar_idx: int = 0

    # ── output panel ──────────────────────────────────────────────────────────
    output_items: list[Any] = field(default_factory=list)
    last_status: str = "ready"

    # ── execution location ────────────────────────────────────────────────────
    current_file: Optional[str] = None
    current_line: Optional[int] = None

    # ── breakpoint sign tracking ──────────────────────────────────────────────
    bp_sign_ids: dict[int, list[int]] = field(default_factory=dict)
    sign_ctr: int = 4000

    # ── render deduplication ─────────────────────────────────────────────────
    pending: dict[str, bool] = field(default_factory=dict)

    # ── BufWriter instances (set by layout.open_ui, cleared on close) ─────────
    # Typed as Any to avoid circular import; runtime type is render.BufWriter
    _sb_writer: Any = field(default=None, repr=False)
    _out_writer: Any = field(default=None, repr=False)

    # ── data fed by debugger (read by sidebar renderers) ──────────────────────
    # Each field mirrors what the old sections[x].items pattern provided.
    # Sidebar renderers read directly from DebuggerState; these are kept here
    # as lightweight caches so render_sidebar stays stateless.
    scopes: list[dict] = field(default_factory=list)
    frames: list[dict] = field(default_factory=list)
    goroutines: list[dict] = field(default_factory=list)
    active_goroutine: Optional[int] = None
    active_frame: int = 0


@dataclass
class DebuggerState:
    breakpoints: dict[str, Breakpoint] = field(default_factory=dict)
    session: Any = None
    watches: list[dict] = field(default_factory=list)
    synced_bp_files: set[str] = field(default_factory=set)
    last_config: Optional[dict] = None
    run_to_cursor_key: Optional[str] = None
    ui: UIState = field(default_factory=UIState)
