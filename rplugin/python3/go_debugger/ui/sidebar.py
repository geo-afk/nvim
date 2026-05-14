"""Sidebar section builder and renderer.

Layout mirrors the VS Code Debug sidebar:
  ▼ 󰓦  GOROUTINES  2        ← compact header with icon + count badge
    ▶  goroutine 1
    ▶  goroutine 2           ← thin divider (virtual line)
  ▼ 󰫧  VARIABLES            ← collapsed / expanded toggle
  ▼ 󰆼  CALL STACK   3
  ▼ 󰝥  BREAKPOINTS  1
  ▼ 󰈈  WATCHES

Rendering uses a stable row model, line diffs, and persistent extmark IDs so
debugger events update only the rows and decorations that actually changed.
"""

from __future__ import annotations
import os
from typing import Optional
import pynvim
from .highlights import ICON, val_hl

# ── config ────────────────────────────────────────────────────────────────────
CFG = {
    "sidebar_min_width": 34,
    "sidebar_pct": 0.21,
    "max_val_len": 52,
    "max_watch_len": 40,
    "sep_char": "─",
}

# Ordered section definitions: (id, icon, display title)
SECTIONS = [
    ("goroutines", ICON["goroutines"], "GOROUTINES"),
    ("variables", ICON["variables"], "VARIABLES"),
    ("stack", ICON["stack"], "CALL STACK"),
    ("breakpoints", ICON["breakpoints"], "BREAKPOINTS"),
    ("watches", ICON["watches"], "WATCHES"),
]

# Namespace name used for all extmarks in the sidebar buffer.
_NS = "go_dbg_sidebar"


# ── helpers ───────────────────────────────────────────────────────────────────


def sb_width(nvim: pynvim.Nvim) -> int:
    cols = nvim.options["columns"]
    return max(CFG["sidebar_min_width"], int(cols * CFG["sidebar_pct"]))


def _truncate(s: str, max_len: int) -> str:
    return s if len(s) <= max_len else s[: max_len - 1] + "…"


def _shrt(path: str) -> str:
    """Return path relative to cwd or home, thread-safe."""
    if not path:
        return "?"
    try:
        p = path.replace("\\", "/")
        cwd = os.getcwd().replace("\\", "/")
        if p.startswith(cwd):
            return p[len(cwd) :].lstrip("/") or path
        home = os.path.expanduser("~").replace("\\", "/")
        if p.startswith(home):
            return "~/" + p[len(home) :].lstrip("/")
    except Exception:
        pass
    return path


# ── item builders ─────────────────────────────────────────────────────────────


def build_goroutine_items(threads: list, active_tid: Optional[int]) -> tuple[list, int]:
    items = []
    for t in threads:
        active = t.get("id") == active_tid
        bullet = ICON["exec_arrow"] if active else "·"
        label = t.get("name") or f"goroutine {t.get('id', '?')}"
        text = f"  {bullet}  {label}"
        grp = "GoDbgActive" if active else "GoDbgFrameInact"
        items.append(
            {
                "text": text,
                "hls": [
                    {"c0": 2, "c1": 2 + len(bullet), "grp": grp},
                    {"c0": 2 + len(bullet) + 2, "c1": len(text), "grp": grp},
                ],
                "key": f"goroutine:{t.get('id', label)}",
            }
        )
    return items, len(threads)


def build_variable_items(
    scopes: list,
    vars_by_scope: dict,
    var_nodes: dict,
    width: int,
) -> tuple[list, int]:
    items = []
    total = 0
    name_w = max(12, min(18, width - 18))

    def _add_recursive(vars_list: list, depth: int, path: str):
        nonlocal total
        for v in vars_list:
            total += 1
            name = str(v.get("name") or "?")
            val = _truncate(str(v.get("value") or ""), CFG["max_val_len"] - (depth * 2))
            typ = str(v.get("type") or "")
            ref = v.get("variablesReference", 0)
            has_ch = ref > 0
            row_key = f"var:{ref}" if ref > 0 else f"var:{path}/{name}:{depth}"

            indent = "  " * (depth + 2)
            if has_ch:
                node = var_nodes.get(ref)
                exp = node.expanded if node else False
                tog = ICON["tree_open"] if exp else ICON["tree_closed"]
                pfx = f"{indent}{tog} "
            else:
                pfx = f"{indent}  "

            np = f"{name:<{max(8, name_w - depth * 2)}}"
            text = f"{pfx}{np}  {val}"

            c0n = len(pfx)
            c1n = c0n + len(np)
            c0e = c1n
            c1e = c0e + 2
            c0v = c1e

            item = {
                "text": text,
                "hls": [
                    {"c0": c0n, "c1": c1n, "grp": "GoDbgVarName"},
                    {"c0": c0e, "c1": c1e, "grp": "GoDbgVarEq"},
                    {"c0": c0v, "c1": len(text), "grp": val_hl(val)},
                ],
                "meta": {"type": "variable", "vref": ref, "name": name, "val": val},
                "key": row_key,
            }
            if typ:
                item["virt"] = typ
            items.append(item)

            if has_ch:
                node = var_nodes.get(ref)
                if node and node.expanded and node.children:
                    _add_recursive(node.children, depth + 1, row_key)

    for scope in scopes:
        sname = scope.get("name", "scope")
        ref = scope.get("variablesReference", 0)
        hdr = f"  {ICON['scope']}  {sname}"
        items.append(
            {
                "text": hdr,
                "hls": [
                    {"c0": 2, "c1": 2 + len(ICON["scope"]), "grp": "GoDbgSectionIcon"},
                    {
                        "c0": 4 + len(ICON["scope"]),
                        "c1": len(hdr),
                        "grp": "GoDbgScopeName",
                    },
                ],
                "meta": {"type": "scope", "name": sname},
                "key": f"scope:{ref}:{sname}",
            }
        )
        _add_recursive(vars_by_scope.get(ref) or [], 0, f"scope:{ref}:{sname}")

    return items, total


def build_stack_items(frames: list) -> tuple[list, int]:
    items = []
    for i, frame in enumerate(frames):
        active = i == 0
        name = frame.get("name") or f"frame {i + 1}"
        src = (frame.get("source") or {}).get("path") or ""
        lnum = frame.get("line")
        addr = frame.get("instructionPointerReference")
        fid = frame.get("id")
        arrow = ICON["exec_arrow"] if active else " "
        idx = f"{i + 1:2d}"

        row1 = f"  {arrow} {idx}  {name}"
        items.append(
            {
                "text": row1,
                "hls": [
                    {
                        "c0": 2,
                        "c1": 2 + len(arrow),
                        "grp": "GoDbgFrameArrow" if active else "GoDbgFrameInact",
                    },
                    {"c0": 3, "c1": 3 + len(idx), "grp": "GoDbgFrameIdx"},
                    {
                        "c0": 3 + len(idx) + 2,
                        "c1": len(row1),
                        "grp": "GoDbgFrameActive" if active else "GoDbgFrameInact",
                    },
                ],
                "virt": f"@ {addr}" if addr else None,
                "meta": {"type": "stack_frame", "fid": fid, "file": src, "line": lnum},
                "key": f"stack:{fid}:name",
            }
        )
        if src:
            row2 = "        " + _shrt(src) + ":" + str(lnum or "?")
            items.append(
                {
                    "text": row2,
                    "hls": [{"c0": 0, "c1": len(row2), "grp": "GoDbgFrameFile"}],
                    "meta": {
                        "type": "stack_frame",
                        "fid": fid,
                        "file": src,
                        "line": lnum,
                    },
                    "key": f"stack:{fid}:file",
                }
            )
    return items, len(frames)


def build_bp_items(bps: list) -> tuple[list, int]:
    items = []
    for bp in bps:
        if bp.log_message:
            icon, ihl = ICON["bp_log"], "GoDbgBPIconLog"
        elif bp.condition:
            icon, ihl = ICON["bp_cond"], "GoDbgBPIconCond"
        else:
            icon, ihl = ICON["bp_normal"], "GoDbgBPIcon"

        f = _shrt(bp.file)
        lnum = str(bp.line)
        text = f"  {icon}  {f}:{lnum}"
        ci = 2
        cf = ci + len(icon) + 2
        cl = cf + len(f) + 1

        items.append(
            {
                "text": text,
                "hls": [
                    {"c0": ci, "c1": ci + len(icon), "grp": ihl},
                    {"c0": cf, "c1": cf + len(f), "grp": "GoDbgBPFile"},
                    {"c0": cl, "c1": len(text), "grp": "GoDbgBPLnum"},
                ],
                "meta": {"type": "breakpoint", "file": bp.file, "line": bp.line},
                "key": f"bp:{bp.file}:{bp.line}:main",
            }
        )

        if bp.condition:
            ct = f"     if {bp.condition}"
            items.append(
                {
                    "text": ct,
                    "hls": [{"c0": 0, "c1": len(ct), "grp": "GoDbgBPCond"}],
                    "meta": {"type": "breakpoint", "file": bp.file, "line": bp.line},
                    "key": f"bp:{bp.file}:{bp.line}:cond",
                }
            )
        elif bp.log_message:
            lt = f"     {ICON['output']} {bp.log_message}"
            items.append(
                {
                    "text": lt,
                    "hls": [{"c0": 0, "c1": len(lt), "grp": "GoDbgBPCond"}],
                    "meta": {"type": "breakpoint", "file": bp.file, "line": bp.line},
                    "key": f"bp:{bp.file}:{bp.line}:log",
                }
            )
    return items, len(bps)


def build_watch_items(watches: list, width: int) -> tuple[list, int]:
    items = []
    if not watches:
        t = "   no watches"
        items.append(
            {
                "text": t,
                "hls": [{"c0": 3, "c1": len(t), "grp": "GoDbgEmpty"}],
                "meta": {"type": "empty"},
                "key": "watch:empty",
            }
        )
        return items, 0

    expr_w = max(14, min(20, width - 14))
    for w in watches:
        val = _truncate(str(w.get("value") or "…"), CFG["max_watch_len"])
        pad = f"  {w['expr']:<{expr_w}}"
        text = f"{pad}  {val}"
        grp = "GoDbgOutErr" if w.get("error") else _val_hl(val)
        items.append(
            {
                "text": text,
                "hls": [
                    {"c0": 0, "c1": len(pad), "grp": "GoDbgVarName"},
                    {"c0": len(pad), "c1": len(pad) + 2, "grp": "GoDbgVarEq"},
                    {"c0": len(pad) + 2, "c1": len(text), "grp": grp},
                ],
                "meta": {"type": "watch", "expr": w["expr"]},
                "key": f"watch:{w['expr']}",
            }
        )
    return items, len(watches)


# ── renderer ──────────────────────────────────────────────────────────────────


def _visible_sidebar_state(nvim: pynvim.Nvim, state) -> dict:
    ui = state.ui
    win = ui.sidebar_win
    saved = {"cursor": None, "topline": None, "key": None}
    if not win or not nvim.api.win_is_valid(win):
        return saved

    try:
        row, col = nvim.api.win_get_cursor(win)
        saved["cursor"] = [row, col]
        if 0 <= row - 1 < len(ui.sidebar_keys):
            saved["key"] = ui.sidebar_keys[row - 1]
    except Exception:
        pass

    try:
        info = nvim.funcs.getwininfo(win)
        if info:
            saved["topline"] = int(info[0].get("topline") or 1)
    except Exception:
        pass

    return saved


def _restore_sidebar_state(nvim: pynvim.Nvim, state, saved: dict) -> None:
    ui = state.ui
    win = ui.sidebar_win
    if not win or not nvim.api.win_is_valid(win):
        return

    line_count = max(1, nvim.api.buf_line_count(ui.sidebar_buf))
    row = 1
    col = 0
    key = saved.get("key")
    if key and key in ui.sidebar_keys:
        row = ui.sidebar_keys.index(key) + 1
    elif saved.get("cursor"):
        row = min(max(1, int(saved["cursor"][0])), line_count)
        col = int(saved["cursor"][1])

    try:
        nvim.api.win_set_cursor(win, [row, col])
    except Exception:
        try:
            nvim.api.win_set_cursor(win, [min(row, line_count), 0])
        except Exception:
            pass

    topline = saved.get("topline")
    if topline:
        topline = min(max(1, int(topline)), line_count)
        try:
            nvim.funcs.win_execute(
                win,
                f"keepjumps call cursor({topline}, 1) | normal! zt | keepjumps call cursor({row}, {col + 1})",
                True,
            )
        except Exception:
            pass


def _apply_line_diff(nvim: pynvim.Nvim, buf: int, old: list[str], new: list[str]) -> None:
    if old == new:
        return

    if not old:
        nvim.api.buf_set_lines(buf, 0, -1, False, new)
        return

    same_len_changes = [
        idx for idx, (before, after) in enumerate(zip(old, new)) if before != after
    ]
    if len(old) == len(new) and len(same_len_changes) <= 16:
        for idx in same_len_changes:
            nvim.api.buf_set_lines(buf, idx, idx + 1, False, [new[idx]])
        return

    prefix = 0
    limit = min(len(old), len(new))
    while prefix < limit and old[prefix] == new[prefix]:
        prefix += 1

    suffix = 0
    while (
        suffix < len(old) - prefix
        and suffix < len(new) - prefix
        and old[len(old) - 1 - suffix] == new[len(new) - 1 - suffix]
    ):
        suffix += 1

    old_end = len(old) - suffix
    new_end = len(new) - suffix
    nvim.api.buf_set_lines(buf, prefix, old_end, False, new[prefix:new_end])


def _set_extmarks(nvim: pynvim.Nvim, state, buf: int, ns: int, marks: list[dict]) -> None:
    ui = state.ui
    next_ids: dict[str, int] = {}

    for mark in marks:
        key = mark["key"]
        opts = dict(mark["opts"])
        old_id = ui.sidebar_extmarks.get(key)
        if old_id:
            opts["id"] = old_id
        try:
            next_ids[key] = nvim.api.buf_set_extmark(
                buf, ns, mark["row"], mark["col"], opts
            )
        except Exception:
            pass

    for key, mark_id in list(ui.sidebar_extmarks.items()):
        if key not in next_ids:
            try:
                nvim.api.buf_del_extmark(buf, ns, mark_id)
            except Exception:
                pass

    ui.sidebar_extmarks = next_ids


def render_sidebar(nvim: pynvim.Nvim, state) -> None:
    """Render sidebar rows incrementally without stealing focus or view state."""
    ui = state.ui
    buf = ui.sidebar_buf
    if not buf or not nvim.api.buf_is_valid(buf):
        return
    if ui.sidebar_rendering:
        return

    ui.sidebar_rendering = True
    ns = nvim.api.create_namespace(_NS)
    w = sb_width(nvim)

    lines: list[str] = []
    keys: list[str] = []
    marks: list[dict] = []
    sec_rows: dict[int, str] = {}  # 0-based row → section_id
    row_map: dict[int, dict] = {}  # 0-based row -> metadata

    def add_hl(r: int, c0: int, c1: int, grp: str) -> None:
        if c1 > c0:
            marks.append(
                {
                    "key": f"{keys[r]}:hl:{c0}:{c1}:{grp}",
                    "row": r,
                    "col": c0,
                    "opts": {"end_col": c1, "hl_group": grp, "priority": 10},
                }
            )

    def add_line_mark(r: int, grp: str) -> None:
        marks.append(
            {
                "key": f"{keys[r]}:line:{grp}",
                "row": r,
                "col": 0,
                "opts": {"line_hl_group": grp, "priority": 1},
            }
        )

    def add_virt(r: int, text: str) -> None:
        marks.append(
            {
                "key": f"{keys[r]}:virt:{text}",
                "row": r,
                "col": 0,
                "opts": {
                    "virt_text": [[text, "GoDbgVarType"]],
                    "virt_text_pos": "right_align",
                    "priority": 5,
                },
            }
        )

    def add_divider(r: int) -> None:
        marks.append(
            {
                "key": f"{keys[r]}:divider",
                "row": r,
                "col": 0,
                "opts": {
                    "virt_lines": [[["─" * w, "GoDbgDivider"]]],
                    "virt_lines_above": False,
                    "priority": 1,
                },
            }
        )

    for si, (sec_id, sec_icon, sec_title) in enumerate(SECTIONS):
        sec = ui.sections[sec_id]
        row0 = len(lines)

        # ── section header ────────────────────────────────────────────────
        tog = ICON["tree_open"] if not sec.collapsed else ICON["tree_closed"]
        cnt = f"  {sec.count}" if sec.count is not None else ""
        # e.g. "▼ 󰓦  GOROUTINES  2"
        hdr = f" {tog} {sec_icon}  {sec_title}{cnt}"

        lines.append(hdr)
        keys.append(f"section:{sec_id}")
        sec_rows[row0] = sec_id
        row_map[row0] = {"type": "section_header", "section_id": sec_id}
        add_line_mark(row0, "GoDbgHeader")

        col = 1
        add_hl(row0, col, col + len(tog), "GoDbgCollapse")
        col += len(tog) + 1
        add_hl(row0, col, col + len(sec_icon), "GoDbgSectionIcon")
        col += len(sec_icon) + 2
        add_hl(row0, col, col + len(sec_title), "GoDbgSectionHdr")
        col += len(sec_title)
        if sec.count is not None:
            add_hl(row0, col, len(hdr), "GoDbgSectionCnt")

        # ── section body ─────────────────────────────────────────────────
        if not sec.collapsed:
            its = sec.items or []
            if not its:
                r = len(lines)
                et = "   —"
                lines.append(et)
                keys.append(f"empty:{sec_id}")
                row_map[r] = {"type": "empty", "section_id": sec_id}
                add_hl(r, 0, len(et), "GoDbgEmpty")
            else:
                for item in its:
                    r = len(lines)
                    lines.append(item["text"])
                    keys.append(str(item.get("key") or f"{sec_id}:{r}:{item['text']}"))
                    row_map[r] = item.get("meta") or {
                        "type": "item",
                        "section_id": sec_id,
                    }
                    for h in item.get("hls") or []:
                        add_hl(r, h["c0"], h["c1"], h["grp"])
                    if item.get("virt"):
                        add_virt(r, item["virt"])

        # thin divider between sections (not after the last one)
        if si < len(SECTIONS) - 1:
            add_divider(len(lines) - 1)

    mark_sig = [mark["key"] for mark in marks]
    if (
        lines == ui.sidebar_lines
        and keys == ui.sidebar_keys
        and row_map == ui.row_map
        and mark_sig == ui.sidebar_mark_sig
    ):
        ui.sidebar_rendering = False
        return

    saved = _visible_sidebar_state(nvim, state)
    try:
        try:
            nvim.api.set_option_value("modifiable", True, {"buf": buf})
            _apply_line_diff(nvim, buf, ui.sidebar_lines, lines)
            _set_extmarks(nvim, state, buf, ns, marks)
        except Exception:
            ui.sidebar_rendering = False
            return

    finally:
        try:
            nvim.api.set_option_value("modifiable", False, {"buf": buf})
        except Exception:
            pass

    ui.sec_rows = sec_rows
    ui.row_map = row_map
    ui.sidebar_lines = lines
    ui.sidebar_keys = keys
    ui.sidebar_mark_sig = mark_sig
    _restore_sidebar_state(nvim, state, saved)
    ui.sidebar_rendering = False
