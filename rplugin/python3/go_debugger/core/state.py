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
    tmp: bool = False  # run-to-cursor temporary

    def bp_key(self) -> str:
        return f"{self.file}:{self.line}"


@dataclass
class VarNode:
    expanded: bool = False
    children: list[dict] = field(default_factory=list)


@dataclass
class SectionState:
    collapsed: bool = False
    items: list[dict] = field(default_factory=list)
    count: Optional[int] = None


@dataclass
class UIState:
    open: bool = False
    sidebar_win: Optional[int] = None
    output_win: Optional[int] = None
    controls_win: Optional[int] = None
    sidebar_buf: Optional[int] = None
    output_buf: Optional[int] = None
    controls_buf: Optional[int] = None
    help_win: Optional[int] = None
    sections: dict[str, SectionState] = field(
        default_factory=lambda: {
            "goroutines": SectionState(),
            "variables": SectionState(),
            "stack": SectionState(),
            "breakpoints": SectionState(),
            "watches": SectionState(),
        }
    )
    sec_rows: dict[int, str] = field(default_factory=dict)  # 1-based row → section_id
    var_nodes: dict[int, VarNode] = field(default_factory=dict)
    output_items: list[Any] = field(default_factory=list)
    output_lines: list[str] = field(default_factory=list)
    output_extmarks: dict[str, int] = field(default_factory=dict)
    output_mark_sig: list[str] = field(default_factory=list)
    sidebar_lines: list[str] = field(default_factory=list)
    sidebar_keys: list[str] = field(default_factory=list)
    sidebar_mark_sig: list[str] = field(default_factory=list)
    sidebar_extmarks: dict[str, int] = field(default_factory=dict)
    sidebar_rendering: bool = False
    last_status: str = "ready"
    current_file: Optional[str] = None
    current_line: Optional[int] = None
    bp_sign_ids: dict[int, list[int]] = field(default_factory=dict)
    sign_ctr: int = 4000
    pending: dict[str, bool] = field(default_factory=dict)
    controls_idx: int = 0
    row_map: dict[int, dict] = field(
        default_factory=dict
    )  # 0-based row -> {type, ...metadata}


@dataclass
class DebuggerState:
    breakpoints: dict[str, Breakpoint] = field(default_factory=dict)
    session: Any = None
    synced_bp_files: set[str] = field(default_factory=set)
    last_config: Optional[dict] = None
    run_to_cursor_key: Optional[str] = None
    watches: list[dict] = field(default_factory=list)
    ui: UIState = field(default_factory=UIState)
