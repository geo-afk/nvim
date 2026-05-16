;; extends

; Capture the whole import path content as @module.path
; This provides a base highlight for all imports.
(import_spec
  path: (interpreted_string_literal
    (interpreted_string_literal_content) @module.path))
