"""Highlight groups, signs, and icon registry.

All groups use ``default = True`` so users can override freely.
Icons require Nerd Font v3.
"""

from __future__ import annotations
import pynvim

# ── signs ─────────────────────────────────────────────────────────────────────
SIGN_BP = "GoDbgBP"
SIGN_BP_COND = "GoDbgBPCond"
SIGN_BP_LOG = "GoDbgBPLog"
SIGN_PC = "GoDbgPC"

# ── icon registry ─────────────────────────────────────────────────────────────
ICON: dict[str, str] = {
    # panel identities
    "debugger": "󰃡",
    "goroutines": "󰓦",
    "variables": "󰫧",
    "stack": "󰆼",
    "breakpoints": "󰝥",
    "watches": "󰈈",
    "output": "󰆍",
    "scope": "󰅪",
    "console": "󰞷",
    # output severities
    "event": "󰒲",
    "error": "󰅙",
    "warn": "󰀪",
    "program": "󱨉",
    "protocol": "󰒓",
    "raw": "󰞋",
    # breakpoint glyphs
    "bp_normal": "●",
    "bp_cond": "◆",
    "bp_log": "◇",
    "bp_disabled": "○",
    # execution state
    "exec_arrow": "▶",
    "stopped": "⏸",
    "running": "⏵",
    # tree chrome
    "tree_open": "󰅀",
    "tree_closed": "󰅂",
    "tree_leaf": "󰧞",
    # value type icons
    "type_obj": "󰆦",
    "type_arr": "󰅪",
    "type_str": "󰊄",
    "type_num": "󰎠",
    "type_bool": "󰨙",
    "type_ptr": "󰙅",
    "type_nil": "󰟢",
    # hover
    "hover_name": "󱄑",
    "hover_type": "󰅨",
    "hover_val": "󰇘",
    # control bar actions
    "ctrl_continue": "󰐊",
    "ctrl_next": "󰆹",
    "ctrl_into": "󰆽",
    "ctrl_out": "󰆾",
    "ctrl_pause": "󰏤",
    "ctrl_stop": "󰓛",
    "ctrl_restart": "󰑓",
}

# ── highlight table ───────────────────────────────────────────────────────────
_HLS: list[tuple[str, dict]] = [
    # chrome
    ("GoDbgBg", {"bg": "NONE"}),
    ("GoDbgWinSep", {"link": "WinSeparator"}),
    ("GoDbgAccent", {"link": "DiagnosticInfo"}),
    ("GoDbgMuted", {"link": "Comment"}),
    ("GoDbgEmpty", {"link": "Comment", "italic": True}),
    ("GoDbgDivider", {"link": "WinSeparator"}),
    # section headers
    ("GoDbgSectionHdr", {"link": "Title", "bold": True}),
    ("GoDbgSectionIcon", {"link": "DiagnosticInfo"}),
    ("GoDbgSectionCnt", {"link": "Comment", "italic": True}),
    ("GoDbgSectionKey", {"link": "DiagnosticHint", "bold": True}),
    ("GoDbgCollapse", {"link": "NonText"}),
    # variable tree
    ("GoDbgScopeName", {"link": "Directory", "bold": True}),
    ("GoDbgVarIndent", {"link": "NonText"}),
    ("GoDbgVarName", {"link": "Identifier"}),
    ("GoDbgVarEq", {"link": "Operator"}),
    ("GoDbgVarType", {"link": "Comment", "italic": True}),
    ("GoDbgVarVal", {"link": "Number"}),
    ("GoDbgVarStr", {"link": "String"}),
    ("GoDbgVarBool", {"link": "Boolean"}),
    ("GoDbgVarNil", {"link": "Comment", "italic": True}),
    ("GoDbgVarPtr", {"link": "SpecialChar"}),
    ("GoDbgVarIcon", {"link": "NonText"}),
    ("GoDbgTreeOpen", {"link": "DiagnosticHint"}),
    ("GoDbgTreeClosed", {"link": "NonText"}),
    # call stack
    ("GoDbgFrameActive", {"link": "DiagnosticInfo", "bold": True}),
    ("GoDbgFrameInact", {"link": "Normal"}),
    ("GoDbgFrameIdx", {"link": "Comment", "italic": True}),
    ("GoDbgFrameFile", {"link": "Comment", "italic": True}),
    ("GoDbgFrameArrow", {"link": "DiagnosticInfo"}),
    # breakpoints
    ("GoDbgBPIcon", {"link": "DiagnosticError"}),
    ("GoDbgBPIconCond", {"link": "DiagnosticWarn"}),
    ("GoDbgBPIconLog", {"link": "DiagnosticHint"}),
    ("GoDbgBPIconDis", {"link": "Comment"}),
    ("GoDbgBPFile", {"link": "Normal"}),
    ("GoDbgBPLnum", {"link": "Number"}),
    ("GoDbgBPCond", {"link": "DiagnosticWarn"}),
    # output panel
    ("GoDbgOutLog", {"link": "Normal"}),
    ("GoDbgOutErr", {"link": "DiagnosticError"}),
    ("GoDbgOutWarn", {"link": "DiagnosticWarn"}),
    ("GoDbgOutEvent", {"link": "DiagnosticInfo"}),
    ("GoDbgOutProgram", {"link": "String"}),
    ("GoDbgOutProtocol", {"link": "Comment", "italic": True}),
    ("GoDbgOutRaw", {"link": "DiagnosticUnnecessary"}),
    ("GoDbgOutTs", {"link": "Comment", "italic": True}),
    # source decorations
    ("GoDbgExecLine", {"link": "CursorLine"}),
    ("GoDbgExecVirt", {"link": "DiagnosticVirtualTextInfo", "italic": True}),
    ("GoDbgExecSign", {"link": "DiagnosticInfo", "bold": True}),
    # hover float
    ("GoDbgHoverTitle", {"link": "Title", "bold": True}),
    ("GoDbgHoverLabel", {"link": "Comment", "italic": True}),
    ("GoDbgHoverVal", {"link": "String"}),
    ("GoDbgHoverType", {"link": "Keyword", "italic": True}),
    # inline virt text
    ("GoDbgVirt", {"link": "DiagnosticVirtualTextInfo", "italic": True}),
    (
        "GoDbgVirtChanged",
        {"link": "DiagnosticVirtualTextWarn", "bold": True, "italic": True},
    ),
    # control bar
    ("GoDbgCtrlContinue", {"link": "DiagnosticInfo", "bold": True}),
    ("GoDbgCtrlStep", {"link": "Normal"}),
    ("GoDbgCtrlPause", {"link": "DiagnosticWarn"}),
    ("GoDbgCtrlStop", {"link": "DiagnosticError"}),
    ("GoDbgCtrlRestart", {"link": "DiagnosticHint"}),
    ("GoDbgCtrlSel", {"link": "Visual"}),
    ("GoDbgCtrlLabel", {"link": "Comment", "italic": True}),
    # status
    ("GoDbgActive", {"link": "DiagnosticInfo", "bold": True}),
    ("GoDbgStatus", {"link": "StatusLine"}),
    ("GoDbgStatusHL", {"link": "DiagnosticInfo", "bold": True}),
    ("GoDbgAddr", {"link": "Comment", "italic": True}),
    # watches
    ("GoDbgWatchExpr", {"link": "Identifier"}),
    ("GoDbgWatchVal", {"link": "String"}),
]


def val_hl(v: str) -> str:
    """Return the highlight group appropriate for a value string."""
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


def type_icon(typ: str) -> str:
    """Return a Nerd Font icon for a Go/generic type string."""
    t = (typ or "").lower()
    if not t:
        return ICON["tree_leaf"]
    if t.startswith("*"):
        return ICON["type_ptr"]
    if t in ("bool",):
        return ICON["type_bool"]
    if t in ("string",):
        return ICON["type_str"]
    if any(
        t.startswith(p) for p in ("int", "uint", "float", "complex", "byte", "rune")
    ):
        return ICON["type_num"]
    if t.startswith("[]") or t.startswith("["):
        return ICON["type_arr"]
    if t.startswith("map[") or t.startswith("struct") or t.startswith("{"):
        return ICON["type_obj"]
    if "interface" in t:
        return ICON["type_nil"]
    return ICON["tree_leaf"]


def setup(nvim: pynvim.Nvim) -> None:
    """Define all highlight groups and signs. Idempotent."""
    for name, opts in _HLS:
        try:
            nvim.api.set_hl(0, name, {**opts, "default": True})
        except Exception:
            pass

    for sname, text, texthl, linehl in [
        (SIGN_BP, ICON["bp_normal"], "DiagnosticError", None),
        (SIGN_BP_COND, ICON["bp_cond"], "DiagnosticWarn", None),
        (SIGN_BP_LOG, ICON["bp_log"], "DiagnosticHint", None),
        (SIGN_PC, ICON["exec_arrow"], "GoDbgExecSign", "GoDbgExecLine"),
    ]:
        sign_opts: dict = {"text": text, "texthl": texthl, "numhl": texthl}
        if linehl:
            sign_opts["linehl"] = linehl
        try:
            nvim.funcs.sign_define(sname, sign_opts)
        except Exception:
            pass
