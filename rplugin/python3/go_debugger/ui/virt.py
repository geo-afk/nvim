"""Inline variable-value extmarks rendered at end-of-line in source buffers.

For every stopped variable the plugin finds the last source line where the
variable name appears and appends a virtual-text hint:

    x := compute()    ⬝ x = 42  (italic, dim)
    x := compute()    ⬝ x = 99  (bold, highlighted – value changed!)

Changed values persist until the next stop event.
"""
from __future__ import annotations
import re
import pynvim

_NS = "go_dbg_virt"

_GO_KEYWORDS: frozenset[str] = frozenset([
    "break", "default", "func", "interface", "select",
    "case", "defer", "go", "map", "struct",
    "chan", "else", "goto", "package", "switch",
    "const", "fallthrough", "if", "range", "type",
    "continue", "for", "import", "return", "var",
    "nil", "true", "false",
])

_MAX_VAL = 50    # characters before truncating the value string
_ICON    = "󱄑"  # Nerd Font: variable

# Module-level state
_prev_vals: dict[str, dict[str, str]] = {}   # normalised_path → {name: value}
_enabled:   bool                       = True


# ── public API ────────────────────────────────────────────────────────────────

def toggle_virt() -> None:
    """Toggle inline virtual text on/off."""
    global _enabled
    _enabled = not _enabled


def is_enabled() -> bool:
    return _enabled


def clear_virt(nvim: pynvim.Nvim, file: str | None = None) -> None:
    """Clear virtual text.  If *file* is None, clears all loaded buffers."""
    global _prev_vals
    ns = nvim.api.create_namespace(_NS)

    if file is None:
        _prev_vals = {}
        for b in nvim.api.list_bufs():
            if nvim.api.buf_is_loaded(b):
                try:
                    nvim.api.buf_clear_namespace(b, ns, 0, -1)
                except Exception:
                    pass
        return

    norm = _norm(nvim, file)
    _prev_vals.pop(norm, None)
    buf = _buf_for(nvim, file)
    if buf is not None:
        try:
            nvim.api.buf_clear_namespace(buf, ns, 0, -1)
        except Exception:
            pass


def apply_virt(nvim: pynvim.Nvim, file: str, variables: list) -> None:
    """Render inline hints for *variables* in the buffer for *file*."""
    if not _enabled:
        return

    buf = _buf_for(nvim, file)
    if buf is None:
        return

    ns   = nvim.api.create_namespace(_NS)
    norm = _norm(nvim, file)
    prev = _prev_vals.setdefault(norm, {})

    # Filter out keywords and invalid names.
    valid = [
        v for v in variables
        if v.get("name")
        and v["name"] not in _GO_KEYWORDS
        and not v["name"].startswith("[")
    ]
    if not valid:
        return

    lines    = nvim.api.buf_get_lines(buf, 0, -1, False)
    var_rows = _find_rows(lines, [v["name"] for v in valid])

    nvim.api.buf_clear_namespace(buf, ns, 0, -1)

    for v in valid:
        name = v["name"]
        row  = var_rows.get(name)
        if row is None:
            continue

        raw = str(v.get("value") or "")
        val = raw if len(raw) <= _MAX_VAL else raw[:_MAX_VAL - 1] + "…"

        changed = name in prev and prev[name] != val
        hl      = "GoDbgVirtChanged" if changed else "GoDbgVirt"
        prev[name] = val

        try:
            nvim.api.buf_set_extmark(buf, ns, row, 0, {
                "virt_text":     [[f"  {_ICON} {name} = {val}", hl]],
                "virt_text_pos": "eol",
                "priority":      90,
            })
        except Exception:
            pass


# ── internals ─────────────────────────────────────────────────────────────────

def _find_rows(lines: list[str], names: list[str]) -> dict[str, int]:
    """Return the last source row (0-based) where each name appears."""
    result:    dict[str, int] = {}
    remaining: set[str]       = set(names)
    patterns:  dict[str, re.Pattern] = {
        n: re.compile(rf"\b{re.escape(n)}\b") for n in names
    }
    for i in range(len(lines) - 1, -1, -1):
        for name in list(remaining):
            if patterns[name].search(lines[i]):
                result[name] = i
                remaining.discard(name)
        if not remaining:
            break
    return result


def _norm(nvim: pynvim.Nvim, path: str) -> str:
    try:
        return nvim.funcs.fnamemodify(path, ":p").replace("\\", "/")
    except Exception:
        return path.replace("\\", "/")


def _buf_for(nvim: pynvim.Nvim, file: str) -> int | None:
    norm = _norm(nvim, file)
    for b in nvim.api.list_bufs():
        if nvim.api.buf_is_loaded(b):
            try:
                if _norm(nvim, nvim.api.buf_get_name(b)) == norm:
                    return b
            except Exception:
                pass
    return None
