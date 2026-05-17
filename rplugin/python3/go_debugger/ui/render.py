"""Low-level buffer rendering utilities.

Single responsibility: write lines + extmarks into a buffer
with minimal redraws. All higher-level panels call into here.
"""

from __future__ import annotations
import pynvim


class BufWriter:
    """Stateful writer that tracks previous content and diffs on write."""

    def __init__(self, nvim: pynvim.Nvim, buf: int, ns: int) -> None:
        self.nvim = nvim
        self.buf = buf
        self.ns = ns
        self._lines: list[str] = []
        self._marks: dict[str, int] = {}  # key → extmark id

    # ── line writing ──────────────────────────────────────────────────────────

    def set_lines(self, lines: list[str]) -> bool:
        """Diff-write lines. Returns True if anything changed."""
        old = self._lines
        new = lines
        if old == new:
            return False

        nvim = self.nvim
        buf = self.buf
        try:
            nvim.api.set_option_value("modifiable", True, {"buf": buf})
            _diff_write(nvim, buf, old, new)
        except Exception:
            return False
        finally:
            try:
                nvim.api.set_option_value("modifiable", False, {"buf": buf})
            except Exception:
                pass
        self._lines = list(new)
        return True

    # ── extmark writing ───────────────────────────────────────────────────────

    def set_marks(self, marks: list[dict]) -> None:
        """Reconcile extmarks: add/update new, delete stale."""
        nvim = self.nvim
        buf = self.buf
        ns = self.ns
        next_ids: dict[str, int] = {}

        for m in marks:
            key = m["key"]
            opts = dict(m["opts"])
            old = self._marks.get(key)
            if old is not None:
                opts["id"] = old
            try:
                new_id = nvim.api.buf_set_extmark(buf, ns, m["row"], m["col"], opts)
                next_ids[key] = new_id
            except Exception:
                pass

        for key, mid in list(self._marks.items()):
            if key not in next_ids:
                try:
                    nvim.api.buf_del_extmark(buf, ns, mid)
                except Exception:
                    pass

        self._marks = next_ids

    def clear_marks(self) -> None:
        try:
            self.nvim.api.buf_clear_namespace(self.buf, self.ns, 0, -1)
        except Exception:
            pass
        self._marks = {}

    def reset(self) -> None:
        self._lines = []
        self.clear_marks()


# ── line builder helpers ──────────────────────────────────────────────────────


class LineBuilder:
    """Accumulates (text, highlights) for a single virtual buffer page."""

    def __init__(self) -> None:
        self.lines: list[str] = []
        self.marks: list[dict] = []

    def blank(self) -> None:
        self.lines.append("")

    def add(
        self,
        text: str,
        hl: str | None = None,
        *,
        col: int = 0,
        end_col: int | None = None,
        priority: int = 10,
        virt_text: list | None = None,
        virt_text_pos: str = "right_align",
    ) -> int:
        """Append *text* as the next line. Returns the row index."""
        row = len(self.lines)
        self.lines.append(text)
        if hl:
            ec = end_col if end_col is not None else len(text)
            self._mark(row, col, ec, hl, priority=priority)
        if virt_text:
            self.marks.append(
                {
                    "key": f"vt:{row}:{virt_text_pos}",
                    "row": row,
                    "col": 0,
                    "opts": {
                        "virt_text": virt_text,
                        "virt_text_pos": virt_text_pos,
                        "priority": priority - 1,
                    },
                }
            )
        return row

    def hl(self, row: int, c0: int, c1: int, grp: str, priority: int = 10) -> None:
        if c1 > c0:
            self._mark(row, c0, c1, grp, priority=priority)

    def _mark(
        self, row: int, c0: int, c1: int, grp: str, *, priority: int = 10
    ) -> None:
        key = f"hl:{row}:{c0}:{grp}"
        self.marks.append(
            {
                "key": key,
                "row": row,
                "col": c0,
                "opts": {"end_col": c1, "hl_group": grp, "priority": priority},
            }
        )

    def section_header(
        self, icon: str, title: str, count: str = "", collapsed: bool = False
    ) -> int:
        from .highlights import ICON

        caret = ICON["tree_closed"] if collapsed else ICON["tree_open"]
        text = f" {caret} {icon}  {title}"
        if count:
            text += f"  {count}"
        row = len(self.lines)
        self.lines.append(text)

        col = 1
        self._mark(row, col, col + len(caret), "GoDbgCollapse")
        col += len(caret) + 1
        self._mark(row, col, col + len(icon), "GoDbgSectionIcon")
        col += len(icon) + 2
        self._mark(row, col, col + len(title), "GoDbgSectionHdr")
        if count:
            self._mark(row, col + len(title) + 2, len(text), "GoDbgSectionCnt")
        return row

    def divider(self) -> None:
        self.lines.append("")


# ── private helpers ───────────────────────────────────────────────────────────


def _diff_write(nvim: pynvim.Nvim, buf: int, old: list[str], new: list[str]) -> None:
    if not old:
        nvim.api.buf_set_lines(buf, 0, -1, False, new)
        return

    # Find common prefix
    prefix = 0
    lim = min(len(old), len(new))
    while prefix < lim and old[prefix] == new[prefix]:
        prefix += 1

    # Find common suffix (within the differing region)
    suffix = 0
    while (
        suffix < len(old) - prefix
        and suffix < len(new) - prefix
        and old[len(old) - 1 - suffix] == new[len(new) - 1 - suffix]
    ):
        suffix += 1

    nvim.api.buf_set_lines(
        buf,
        prefix,
        len(old) - suffix,
        False,
        new[prefix : len(new) - suffix if suffix else len(new)],
    )
