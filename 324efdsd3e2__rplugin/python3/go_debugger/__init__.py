"""Go Debugger — pynvim remote plugin entry point."""

from __future__ import annotations
import pynvim
from .core.debugger import Debugger
from .ui.layout import close_ui, toggle_ui, refresh_ui, scroll_output_bottom
from .ui.highlights import setup as setup_hl


@pynvim.plugin
class GoDebuggerPlugin:
    def __init__(self, nvim: pynvim.Nvim) -> None:
        self.nvim = nvim
        self._dbg: Debugger | None = None

    # ── lazy init ─────────────────────────────────────────────────────────────

    def _get_dbg(self) -> Debugger:
        if self._dbg is None:
            self._dbg = Debugger(self.nvim)
            self._dbg._plugin_ref = self
            setup_hl(self.nvim)
            self._dbg.load_breakpoints()
            self._dbg.load_watches()
        return self._dbg

    # ── passthrough helpers ───────────────────────────────────────────────────

    def dbg_continue(self):
        self._get_dbg().continue_exec()

    def dbg_step_over(self):
        self._get_dbg().step_over()

    def dbg_step_into(self):
        self._get_dbg().step_into()

    def dbg_step_out(self):
        self._get_dbg().step_out()

    def dbg_pause(self):
        self._get_dbg().pause()

    def dbg_stop(self):
        self._get_dbg().stop()

    def dbg_restart(self):
        self._get_dbg().restart()

    # ── Commands ──────────────────────────────────────────────────────────────

    @pynvim.command("GoDlvDebug", nargs=0, sync=False)
    def cmd_debug(self):
        self._get_dbg().debug()

    @pynvim.command("GoDlvTest", nargs=0, sync=False)
    def cmd_test(self):
        self._get_dbg().test()

    @pynvim.command("GoDlvAttachSpawn", nargs=0, sync=False)
    def cmd_attach_spawn(self):
        self._get_dbg().attach_spawn()

    @pynvim.command("GoDlvAttach", nargs=1, sync=False)
    def cmd_attach(self, args):
        self._get_dbg().attach(args[0])

    @pynvim.command("GoDlvConnect", nargs=1, sync=False)
    def cmd_connect(self, args):
        self._get_dbg().connect(args[0])

    @pynvim.command("GoDlvRestart", nargs=0, sync=False)
    def cmd_restart(self):
        self._get_dbg().restart()

    @pynvim.command("GoDlvStop", nargs=0, sync=False)
    def cmd_stop(self):
        self._get_dbg().stop()

    @pynvim.command("GoDlvContinue", nargs=0, sync=False)
    def cmd_continue(self):
        self._get_dbg().continue_exec()

    @pynvim.command("GoDlvNext", nargs=0, sync=False)
    def cmd_next(self):
        self._get_dbg().step_over()

    @pynvim.command("GoDlvStepIn", nargs=0, sync=False)
    def cmd_step_in(self):
        self._get_dbg().step_into()

    @pynvim.command("GoDlvStepOut", nargs=0, sync=False)
    def cmd_step_out(self):
        self._get_dbg().step_out()

    @pynvim.command("GoDlvPause", nargs=0, sync=False)
    def cmd_pause(self):
        self._get_dbg().pause()

    @pynvim.command("GoDlvRunToCursor", nargs=0, sync=False)
    def cmd_run_to_cursor(self):
        self._get_dbg().run_to_cursor()

    @pynvim.command("GoDlvBreakpoint", nargs=0, sync=False)
    def cmd_breakpoint(self):
        self._get_dbg().toggle_breakpoint()

    @pynvim.command("GoDlvCondBreakpoint", nargs=0, sync=True)
    def cmd_cond_bp(self):
        self._get_dbg().conditional_breakpoint()

    @pynvim.command("GoDlvLogpoint", nargs=0, sync=True)
    def cmd_logpoint(self):
        self._get_dbg().logpoint()

    @pynvim.command("GoDlvHitBreakpoint", nargs=0, sync=True)
    def cmd_hit_bp(self):
        self._get_dbg().hit_breakpoint()

    @pynvim.command("GoDlvRemoveBreakpoint", nargs=0, sync=False)
    def cmd_remove_bp(self):
        self._get_dbg().remove_breakpoint()

    @pynvim.command("GoDlvClearBreakpoints", nargs=0, sync=False)
    def cmd_clear_bps(self):
        self._get_dbg().clear_breakpoints()

    @pynvim.command("GoDlvInspect", nargs="*", sync=True)
    def cmd_inspect(self, args):
        self._get_dbg().inspect(args[0] if args else None)

    @pynvim.command("GoDlvSetVar", nargs=0, sync=True)
    def cmd_set_var(self):
        self._get_dbg().set_variable()

    @pynvim.command("GoDlvHover", nargs="*", sync=False)
    def cmd_hover(self, args):
        self._get_dbg().hover_eval(args[0] if args else None)

    @pynvim.command("GoDlvCloseHover", nargs=0, sync=False)
    def cmd_close_hover(self):
        from .ui.hover import close_hover

        close_hover(self.nvim)

    @pynvim.command("GoDlvUICloseInspector", nargs=0, sync=False)
    def cmd_close_inspector(self):
        from .ui.hover import close_inspector

        close_inspector(self.nvim)

    @pynvim.command("GoDlvWatchAdd", nargs="*", sync=True)
    def cmd_watch_add(self, args):
        self._get_dbg().watch_add(args[0] if args else None)

    @pynvim.command("GoDlvWatchRemove", nargs=0, sync=True)
    def cmd_watch_remove(self):
        self._get_dbg().watch_remove()

    @pynvim.command("GoDlvUI", nargs=0, sync=False)
    def cmd_toggle_ui(self):
        toggle_ui(self.nvim, self._get_dbg().state, self)

    @pynvim.command("GoDlvUIClose", nargs=0, sync=False)
    def cmd_ui_close(self):
        close_ui(self.nvim, self._get_dbg().state)

    @pynvim.command("GoDlvUIRefresh", nargs=0, sync=False)
    def cmd_ui_refresh(self):
        refresh_ui(self.nvim, self._get_dbg().state)

    @pynvim.command("GoDlvUISelect", nargs=0, sync=False)
    def cmd_ui_select(self):
        self._get_dbg().sidebar_select()

    @pynvim.command("GoDlvUIToggleSection", nargs=0, sync=False)
    def cmd_ui_toggle_section(self):
        self._get_dbg().sidebar_select()

    @pynvim.command("GoDlvUIInspect", nargs=0, sync=False)
    def cmd_ui_inspect(self):
        self._get_dbg().sidebar_inspect()

    @pynvim.command("GoDlvUINextSection", nargs=0, sync=False)
    def cmd_ui_next_section(self):
        from .ui.sidebar import sidebar_next_section

        sidebar_next_section(self.nvim, self._get_dbg().state, 1)

    @pynvim.command("GoDlvUIPrevSection", nargs=0, sync=False)
    def cmd_ui_prev_section(self):
        from .ui.sidebar import sidebar_next_section

        sidebar_next_section(self.nvim, self._get_dbg().state, -1)

    @pynvim.command("GoDlvUIScrollBottom", nargs=0, sync=False)
    def cmd_ui_scroll_bottom(self):
        scroll_output_bottom(self.nvim, self._get_dbg().state)

    @pynvim.command("GoDlvUIHelp", nargs=0, sync=True)
    def cmd_ui_help(self):
        from .ui.help import open_help

        open_help(self.nvim, self._get_dbg().state)

    # ── Toolbar commands (replaces GoDlvControl*) ─────────────────────────────

    @pynvim.command("GoDlvUIToolbarNext", nargs=0, sync=False)
    def cmd_toolbar_next(self):
        from .ui.toolbar import toolbar_next

        toolbar_next(self.nvim, self._get_dbg().state)

    @pynvim.command("GoDlvUIToolbarPrev", nargs=0, sync=False)
    def cmd_toolbar_prev(self):
        from .ui.toolbar import toolbar_prev

        toolbar_prev(self.nvim, self._get_dbg().state)

    @pynvim.command("GoDlvUIToolbarExec", nargs=0, sync=False)
    def cmd_toolbar_exec(self):
        from .ui.toolbar import toolbar_exec

        toolbar_exec(self.nvim, self._get_dbg().state, self)

    @pynvim.command("GoDlvToggleVirt", nargs=0, sync=False)
    def cmd_toggle_virt(self):
        from .ui.virt import toggle_virt

        toggle_virt()
        self.nvim.api.notify("[go-debug] inline virtual text toggled", 2, {})

    # ── Functions (callable from Lua) ─────────────────────────────────────────

    @pynvim.function("GoDbgHoverExpr", sync=False)
    def fn_hover_expr(self, args):
        self._get_dbg().hover_eval(args[0] if args else None)

    @pynvim.function("GoDbgBpSigns", sync=False)
    def fn_bp_signs(self, args):
        self._get_dbg()._refresh_bp_signs()

    # ── Autocmds ──────────────────────────────────────────────────────────────

    @pynvim.autocmd("BufReadPost,BufWinEnter", pattern="*.go", sync=False)
    def on_go_buf(self):
        try:
            self._get_dbg()._refresh_bp_signs()
        except Exception:
            pass

    @pynvim.autocmd("ColorScheme", pattern="*", sync=False)
    def on_colorscheme(self):
        try:
            setup_hl(self.nvim)
        except Exception:
            pass

    @pynvim.autocmd("VimLeavePre", pattern="*", sync=False)
    def on_leave(self):
        try:
            self._get_dbg().stop()
        except Exception:
            pass

    @pynvim.autocmd("VimResized", pattern="*", sync=False)
    def on_resized(self):
        try:
            dbg = self._get_dbg()
            if dbg.state.ui.open:
                refresh_ui(self.nvim, dbg.state)
        except Exception:
            pass
