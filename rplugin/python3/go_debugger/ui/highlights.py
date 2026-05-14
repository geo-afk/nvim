"""Highlight groups, signs, and icon registry.

All highlight groups are defined with ``default = True`` so users can
override them in their own colorschemes without fighting specificity.
"""
from __future__ import annotations
import pynvim

SIGN_BP      = "GoDbgBP"
SIGN_BP_COND = "GoDbgBPCond"
SIGN_BP_LOG  = "GoDbgBPLog"
SIGN_PC      = "GoDbgPC"

# Nerd Font v3 icon set — single source of truth for the entire plugin.
ICON: dict[str, str] = {
    # panel headers
    "debugger":     "󰃡",
    "goroutines":   "󰓦",
    "variables":    "󰫧",
    "stack":        "󰆼",
    "breakpoints":  "󰝥",
    "watches":      "󰈈",
    "output":       "󰆍",
    "scope":        "󰅪",
    # output kinds
    "event":        "󰒲",
    "error":        "󰅙",
    "warn":         "󰀪",
    "program":      "󱨉",
    "protocol":     "󰒓",
    "raw":          "󰞋",
    # breakpoint markers
    "bp_normal":    "●",
    "bp_cond":      "◆",
    "bp_log":       "◇",
    "bp_disabled":  "○",
    # execution state
    "exec_arrow":   "▶",
    "exec_line":    "⮞",
    "frame_blank":  " ",
    "stopped":      "⏸",
    "running":      "⏵",
    # hover
    "hover_name":   "󱄑",
    "hover_type":   "󰅨",
    "hover_val":    "󰇘",
    # tree
    "tree_open":    "▼",
    "tree_closed":  "▶",
    "tree_leaf":    " ",
}

# ---------------------------------------------------------------------------
# Highlight table
# Each entry: (name, attrs).  ``default: True`` is added automatically.
# ---------------------------------------------------------------------------
_HLS: list[tuple[str, dict]] = [
    # ── chrome ────────────────────────────────────────────────────────────
    ("GoDbgBg",           {"bg": "NONE"}),
    ("GoDbgWinSep",       {"link": "WinSeparator"}),
    ("GoDbgHeader",       {"link": "CursorLine"}),
    ("GoDbgHeaderFocus",  {"link": "Visual"}),
    # section title bar
    ("GoDbgSectionHdr",   {"link": "Title",           "bold": True}),
    ("GoDbgSectionIcon",  {"link": "DiagnosticInfo"}),
    ("GoDbgSectionCnt",   {"link": "Comment",         "italic": True}),
    ("GoDbgSectionKey",   {"link": "DiagnosticHint",  "bold": True}),
    ("GoDbgCollapse",     {"link": "NonText"}),
    # thin virtual-line dividers
    ("GoDbgDivider",      {"link": "WinSeparator"}),
    ("GoDbgEmpty",        {"link": "Comment",         "italic": True}),
    ("GoDbgAccent",       {"link": "DiagnosticInfo"}),

    # ── variables ─────────────────────────────────────────────────────────
    ("GoDbgScopeName",    {"link": "Directory",       "bold": True}),
    ("GoDbgVarIndent",    {"link": "NonText"}),
    ("GoDbgVarName",      {"link": "Identifier"}),
    ("GoDbgVarEq",        {"link": "Operator"}),
    ("GoDbgVarType",      {"link": "Comment",         "italic": True}),
    ("GoDbgVarVal",       {"link": "Number"}),
    ("GoDbgVarStr",       {"link": "String"}),
    ("GoDbgVarBool",      {"link": "Boolean"}),
    ("GoDbgVarNil",       {"link": "Comment",         "italic": True}),
    ("GoDbgVarPtr",       {"link": "SpecialChar"}),

    # ── call stack ────────────────────────────────────────────────────────
    ("GoDbgFrameActive",  {"link": "DiagnosticInfo",  "bold": True}),
    ("GoDbgFrameInact",   {"link": "Normal"}),
    ("GoDbgFrameIdx",     {"link": "Comment",         "italic": True}),
    ("GoDbgFrameFile",    {"link": "Comment",         "italic": True}),
    ("GoDbgFrameArrow",   {"link": "DiagnosticInfo"}),

    # ── breakpoints ───────────────────────────────────────────────────────
    ("GoDbgBPIcon",       {"link": "DiagnosticError"}),
    ("GoDbgBPIconCond",   {"link": "DiagnosticWarn"}),
    ("GoDbgBPIconLog",    {"link": "DiagnosticHint"}),
    ("GoDbgBPIconDis",    {"link": "Comment"}),
    ("GoDbgBPFile",       {"link": "Normal"}),
    ("GoDbgBPLnum",       {"link": "Number"}),
    ("GoDbgBPCond",       {"link": "DiagnosticWarn"}),

    # ── output panel ──────────────────────────────────────────────────────
    ("GoDbgOutLog",       {"link": "Normal"}),
    ("GoDbgOutErr",       {"link": "DiagnosticError"}),
    ("GoDbgOutWarn",      {"link": "DiagnosticWarn"}),
    ("GoDbgOutEvent",     {"link": "DiagnosticInfo"}),
    ("GoDbgOutProgram",   {"link": "String"}),
    ("GoDbgOutProtocol",  {"link": "Comment",         "italic": True}),
    ("GoDbgOutRaw",       {"link": "DiagnosticUnnecessary"}),
    ("GoDbgOutTs",        {"link": "Comment",         "italic": True}),

    # ── source decorations ────────────────────────────────────────────────
    ("GoDbgExecLine",     {"link": "CursorLine"}),
    ("GoDbgExecVirt",     {"link": "DiagnosticVirtualTextInfo", "italic": True}),
    ("GoDbgExecSign",     {"link": "DiagnosticInfo",  "bold": True}),

    # ── hover float ───────────────────────────────────────────────────────
    ("GoDbgHoverTitle",   {"link": "Title",            "bold": True}),
    ("GoDbgHoverLabel",   {"link": "Comment",          "italic": True}),
    ("GoDbgHoverVal",     {"link": "String"}),
    ("GoDbgHoverType",    {"link": "Keyword",          "italic": True}),

    # ── inline virt text ──────────────────────────────────────────────────
    ("GoDbgVirt",         {"link": "DiagnosticVirtualTextInfo", "italic": True}),
    ("GoDbgVirtChanged",  {"link": "DiagnosticVirtualTextWarn", "bold": True, "italic": True}),

    # ── control bar ───────────────────────────────────────────────────────
    ("GoDbgBtnContinue",  {"link": "DiagnosticInfo",  "bold": True}),
    ("GoDbgBtnStep",      {"link": "Normal"}),
    ("GoDbgBtnPause",     {"link": "DiagnosticWarn"}),
    ("GoDbgBtnStop",      {"link": "DiagnosticError"}),
    ("GoDbgBtnRestart",   {"link": "DiagnosticHint"}),
    ("GoDbgBtnSel",       {"link": "Visual"}),

    # ── misc ──────────────────────────────────────────────────────────────
    ("GoDbgActive",       {"link": "DiagnosticInfo",  "bold": True}),
    ("GoDbgStatus",       {"link": "StatusLine"}),
    ("GoDbgStatusHL",     {"link": "DiagnosticInfo",  "bold": True}),
    ("GoDbgAddr",         {"link": "Comment",         "italic": True}),
]


def val_hl(v: str) -> str:
    """Return the highlight group name appropriate for value string v."""
    if v in ("nil", "<nil>"):
        return "GoDbgVarNil"
    if v in ("true", "false"):
        return "GoDbgVarBool"
    if v.startswith("0x"):
        return "GoDbgVarPtr"
    if v and v[0] in ('"', "`"):
        return "GoDbgVarStr"
    if v and (v[0].isdigit() or (v[0] == "-" and len(v) > 1 and v[1].isdigit())):
        return "GoDbgVarVal"
    return "GoDbgVarName"


def setup(nvim: pynvim.Nvim) -> None:
    """Define all highlight groups and signs (idempotent)."""
    for name, opts in _HLS:
        try:
            nvim.api.set_hl(0, name, {**opts, "default": True})
        except Exception:
            pass

    # signs ──────────────────────────────────────────────────────────────────
    for sname, text, texthl, linehl in [
        (SIGN_BP,      ICON["bp_normal"],   "DiagnosticError", None),
        (SIGN_BP_COND, ICON["bp_cond"],     "DiagnosticWarn",  None),
        (SIGN_BP_LOG,  ICON["bp_log"],      "DiagnosticHint",  None),
        (SIGN_PC,      ICON["exec_arrow"],  "GoDbgExecSign",   "GoDbgExecLine"),
    ]:
        sign_opts: dict = {"text": text, "texthl": texthl, "numhl": texthl}
        if linehl:
            sign_opts["linehl"] = linehl
        try:
            nvim.funcs.sign_define(sname, sign_opts)
        except Exception:
            pass
