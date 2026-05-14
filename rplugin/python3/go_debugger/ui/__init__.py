"""go_debugger.ui – Neovim UI subsystem.

Public surface used by the core debugger:

  layout   – open_ui / close_ui / toggle_ui / refresh_ui
  sidebar  – render_sidebar, build_* item helpers
  output   – render_output
  virt     – apply_virt / clear_virt / toggle_virt
  hover    – show_hover / close_hover
  controls – open_controls / close_controls / control_next / control_prev
             / control_exec
  highlights – setup()
"""
