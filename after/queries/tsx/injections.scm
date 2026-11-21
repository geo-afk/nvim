;; extends

; =============================================================================
; HTML Template Injections for TSX
; =============================================================================

; 1. Tagged template literals: html`...`, svg`...`, etc.
((call_expression
  function: (identifier) @_tag
  (#any-of? @_tag "html" "svg" "raw" "tpl")
  arguments: (template_string) @injection.content)
 (#offset! @injection.content 0 1 0 -1)
 (#set! injection.include-children)
 (#set! injection.language "html"))

; 2. Comments before template literal: /* html */ `...`
((comment) @_comment
 (#lua-match? @_comment "^/%*+%s*html%s*%*+/$")
 .
 (template_string) @injection.content
 (#offset! @injection.content 0 1 0 -1)
 (#set! injection.include-children)
 (#set! injection.language "html"))

; 3. Template literals containing HTML markup
((template_string) @injection.content
 (#lua-match? @injection.content "<%s*[%a!/][^>]*>")
 (#offset! @injection.content 0 1 0 -1)
 (#set! injection.include-children)
 (#set! injection.language "html"))
