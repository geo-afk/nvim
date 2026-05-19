"""Sidebar panel renderer.

Panels (top → bottom):
  ① Variables / Scopes  (expandable tree)
  ② Watch expressions
  ③ Call stack
  ④ Breakpoints
  ⑤ Goroutines

Each section is independently collapsible.  Only changed sections are
re-written on update (BufWriter diff strategy).
"""

from __future__ import annotations
import os
import pynvim
from .highlights import ICON, val_hl, type_icon
from .render import BufWriter, LineBuilder

_NS = "go_dbg_sidebar"


# Sidebar occupies ~22 % of editor width, clamped 30–55 cols.
def sb_width(nvim: pynvim.Nvim) -> int:
    cols = nvim.options["columns"]
    return max(30, min(55, int(cols * 0.22)))


# ── section keys ─────────────────────────────────────────────────────────────
SEC_VARS = "variables"
SEC_WATCH = "watches"
SEC_STACK = "stack"
SEC_BP = "breakpoints"
SEC_GOROUT = "goroutines"

_SEC_ORDER = [SEC_VARS, SEC_WATCH, SEC_STACK, SEC_BP, SEC_GOROUT]

_SEC_ICON: dict[str, str] = {
    SEC_VARS: ICON["variables"],
    SEC_WATCH: ICON["watches"],
    SEC_STACK: ICON["stack"],
    SEC_BP: ICON["breakpoints"],
    SEC_GOROUT: ICON["goroutines"],
}

_SEC_TITLE: dict[str, str] = {
    SEC_VARS: "Variables",
    SEC_WATCH: "Watches",
    SEC_STACK: "Call Stack",
    SEC_BP: "Breakpoints",
    SEC_GOROUT: "Goroutines",
}


# ── per-section renderers ─────────────────────────────────────────────────────


def _render_variables(lb: LineBuilder, state) -> None:
    scopes = getattr(state.ui, "scopes", []) or []
    if not scopes:
        lb.add("  (no variables)", "GoDbgEmpty")
        return
    for scope in scopes:
        sname = scope.get("name", "Scope")
        lb.add(f"  {ICON['scope']}  {sname}", "GoDbgScopeName")
        vars_ = scope.get("variables", [])
        _render_var_list(lb, vars_, state, depth=0, scope_key=sname)


def _render_var_list(
    lb: LineBuilder,
    variables: list,
    state,
    depth: int,
    scope_key: str,
) -> None:
    indent = "  " + "  " * depth
    exp = getattr(state.ui, "var_expanded", {})

    for v in variables:
        name = str(v.get("name") or "?")
        val = str(v.get("value") or "")
        typ = str(v.get("type") or "")
        vref = int(v.get("variablesReference") or 0)
        children = v.get("_children") or []

        key = f"{scope_key}:{depth}:{name}"
        is_exp = exp.get(key, False)
        has_ch = vref > 0 or bool(children)

        caret = (
            (ICON["tree_open"] if is_exp else ICON["tree_closed"])
            if has_ch
            else ICON["tree_leaf"]
        )
        ticon = type_icon(typ)

        row_text = f"{indent}{caret} {ticon} {name}"
        type_hint = f"  {typ}" if typ else ""
        val_part = f"  = {val}" if val else ""
        full = row_text + type_hint + val_part

        row = lb.add(full)

        # highlight pieces
        c = len(indent)
        lb.hl(row, c, c + len(caret), "GoDbgTreeOpen" if is_exp else "GoDbgTreeClosed")
        c += len(caret) + 1
        lb.hl(row, c, c + len(ticon), "GoDbgVarIcon")
        c += len(ticon) + 1
        lb.hl(row, c, c + len(name), "GoDbgVarName")
        c += len(name)
        if typ:
            lb.hl(row, c + 2, c + 2 + len(typ), "GoDbgVarType")
            c += 2 + len(typ)
        if val:
            lb.hl(row, c + 4, c + 4 + len(val), val_hl(val))

        # store row → key in ui for navigation
        state.ui.var_row_key[row] = key

        if is_exp and children:
            _render_var_list(lb, children, state, depth + 1, scope_key)


def _render_watches(lb: LineBuilder, state) -> None:
    watches = getattr(state, "watches", []) or []
    if not watches:
        lb.add("  (no watches)", "GoDbgEmpty")
        return
    for i, w in enumerate(watches):
        expr = w.get("expr", "?")
        val = w.get("value", "…")
        row = lb.add(f"  {ICON['watches']} {expr}  =  {val}")
        c = 2 + len(ICON["watches"]) + 1
        lb.hl(row, c, c + len(expr), "GoDbgWatchExpr")
        c += len(expr) + 5
        lb.hl(row, c, c + len(val), "GoDbgWatchVal")
        state.ui.var_row_key[row] = f"watch:{i}"


def _render_stack(lb: LineBuilder, state) -> None:
    frames = getattr(state.ui, "frames", []) or []
    if not frames:
        lb.add("  (no frames)", "GoDbgEmpty")
        return
    active = getattr(state.ui, "active_frame", 0) or 0
    for i, f in enumerate(frames):
        func = f.get("name", "?")
        file = f.get("source", {}).get("name", "")
        lnum = f.get("line", 0)

        is_active = i == active
        arrow = ICON["exec_arrow"] if is_active else " "
        row = lb.add(f"  {arrow} #{i}  {func}")
        hl = "GoDbgFrameActive" if is_active else "GoDbgFrameInact"

        c = 2 + len(arrow) + 1
        lb.hl(row, c, c + 2 + len(str(i)), "GoDbgFrameIdx")
        c += 3 + len(str(i))
        lb.hl(row, c, c + len(func), hl)

        if file:
            loc = f"    {file}:{lnum}"
            r2 = lb.add(loc)
            lb.hl(r2, 4, len(loc), "GoDbgFrameFile")

        state.ui.var_row_key[row] = f"frame:{i}"


def _render_breakpoints(lb: LineBuilder, state) -> None:
    bps_dict = getattr(state, "breakpoints", {}) or {}
    bps = sorted(
        (bp for bp in bps_dict.values() if not getattr(bp, "tmp", False)),
        key=lambda b: (b.file, b.line),
    )
    if not bps:
        lb.add("  (no breakpoints)", "GoDbgEmpty")
        return
    for i, bp in enumerate(bps):
        file = os.path.basename(bp.file)
        lnum = bp.line
        cond = bp.condition or ""
        log = bp.log_message or ""

        if log:
            icon = ICON["bp_log"]
            hl = "GoDbgBPIconLog"
        elif cond:
            icon = ICON["bp_cond"]
            hl = "GoDbgBPIconCond"
        else:
            icon = ICON["bp_normal"]
            hl = "GoDbgBPIcon"

        row = lb.add(f"  {icon}  {file}:{lnum}")
        lb.hl(row, 2, 2 + len(icon), hl)
        lb.hl(row, 4 + len(icon), len(f"  {icon}  {file}"), "GoDbgBPFile")
        lb.hl(
            row,
            len(f"  {icon}  {file}") + 1,
            len(f"  {icon}  {file}:{lnum}"),
            "GoDbgBPLnum",
        )

        if cond:
            r2 = lb.add(f"    if {cond}")
            lb.hl(r2, 7, len(f"    if {cond}"), "GoDbgBPCond")

        state.ui.var_row_key[row] = f"bp:{i}"


def _render_goroutines(lb: LineBuilder, state) -> None:
    goroutines = getattr(state.ui, "goroutines", []) or []
    if not goroutines:
        lb.add("  (none)", "GoDbgEmpty")
        return
    cur = getattr(state.ui, "active_goroutine", None)
    for g in goroutines:
        gid = g.get("id", "?")
        gname = g.get("name", "")
        arrow = ICON["exec_arrow"] if gid == cur else " "
        text = f"  {arrow} G{gid}"
        if gname:
            text += f"  {gname}"
        row = lb.add(text)
        lb.hl(row, 2, 2 + len(arrow), "GoDbgFrameArrow" if gid == cur else "GoDbgMuted")
        state.ui.var_row_key[row] = f"goroutine:{gid}"


_SEC_RENDER = {
    SEC_VARS: _render_variables,
    SEC_WATCH: _render_watches,
    SEC_STACK: _render_stack,
    SEC_BP: _render_breakpoints,
    SEC_GOROUT: _render_goroutines,
}


# ── public render ─────────────────────────────────────────────────────────────


def render_sidebar(nvim: pynvim.Nvim, state) -> None:
    ui = state.ui
    buf = ui.sidebar_buf
    if not buf or not nvim.api.buf_is_valid(buf):
        return

    if not hasattr(ui, "_sb_writer") or ui._sb_writer is None:
        ns = nvim.api.create_namespace(_NS)
        ui._sb_writer = BufWriter(nvim, buf, ns)

    writer = ui._sb_writer
    collapsed: dict[str, bool] = getattr(ui, "sec_collapsed", {})
    ui.sec_rows = {}
    ui.var_row_key = {}

    lb = LineBuilder()
    lb.blank()

    for sec in _SEC_ORDER:
        is_col = collapsed.get(sec, False)
        count = _sec_count(state, sec)
        hdr_row = lb.section_header(
            _SEC_ICON[sec],
            _SEC_TITLE[sec],
            count=str(count) if count else "",
            collapsed=is_col,
        )
        ui.sec_rows[hdr_row] = sec

        if not is_col:
            _SEC_RENDER[sec](lb, state)

        lb.blank()

    writer.set_lines(lb.lines)
    writer.set_marks(lb.marks)


def _sec_count(state, sec: str) -> int:
    try:
        if sec == SEC_VARS:
            return sum(
                len(sc.get("variables", []))
                for sc in (getattr(state.ui, "scopes", []) or [])
            )
        if sec == SEC_WATCH:
            return len(getattr(state, "watches", []) or [])
        if sec == SEC_STACK:
            return len(getattr(state.ui, "frames", []) or [])
        if sec == SEC_BP:
            bps = getattr(state, "breakpoints", {}) or {}
            return sum(1 for bp in bps.values() if not getattr(bp, "tmp", False))
        if sec == SEC_GOROUT:
            return len(getattr(state.ui, "goroutines", []) or [])
    except Exception:
        pass
    return 0


# ── navigation helpers ────────────────────────────────────────────────────────


def sidebar_select(nvim: pynvim.Nvim, state) -> None:
    """Toggle expansion for the item under cursor."""
    ui = state.ui
    win = ui.sidebar_win
    if not win or not nvim.api.win_is_valid(win):
        return
    row = nvim.api.win_get_cursor(win)[0] - 1  # 0-based

    # section header?
    if row in ui.sec_rows:
        sec = ui.sec_rows[row]
        col = getattr(ui, "sec_collapsed", {})
        col[sec] = not col.get(sec, False)
        ui.sec_collapsed = col
        render_sidebar(nvim, state)
        return

    # variable row?
    key = ui.var_row_key.get(row)
    if key and not key.startswith(("frame:", "bp:", "watch:", "goroutine:")):
        exp = getattr(ui, "var_expanded", {})
        exp[key] = not exp.get(key, False)
        ui.var_expanded = exp
        render_sidebar(nvim, state)


def sidebar_next_section(nvim: pynvim.Nvim, state, direction: int = 1) -> None:
    ui = state.ui
    win = ui.sidebar_win
    if not win or not nvim.api.win_is_valid(win):
        return
    cur = nvim.api.win_get_cursor(win)[0] - 1
    rows = sorted(ui.sec_rows.keys())
    if not rows:
        return
    if direction > 0:
        target = next((r for r in rows if r > cur), rows[0])
    else:
        target = next((r for r in reversed(rows) if r < cur), rows[-1])
    nvim.api.win_set_cursor(win, [target + 1, 0])
