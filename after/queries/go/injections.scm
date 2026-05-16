;; extends

; =============================================================================
;  SQL INJECTIONS
; =============================================================================

; 1. Primary SQL injection via pattern matching
; Enhanced to catch more DDL/DML and handle line breaks correctly.
(([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
] @injection.content)
 (#match? @injection.content "\\v\\c^\\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|TRUNCATE|WITH|GRANT|REVOKE|EXPLAIN|ANALYZE|MERGE|REPLACE|COMMENT|REINDEX)\\s+")
 (#match? @injection.content "\\v\\c(FROM|INTO|VALUES|SET|TABLE|DATABASE|INDEX|AS|TO|USING|ON|JOIN|WHERE|GROUP|ORDER|LIMIT|RETURNING|UNION)")
 (#set! injection.language "sql"))

; 2. Magic comments: // sql, /* sql */, // language=sql, and sqlc's // name:
; We match the comment and the immediate next declaration.
((comment) @_comment
 (#match? @_comment "(sql|name:|language\\=sql)")
 .
 [
   (short_var_declaration
     right: (expression_list
       [
         (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
         (raw_string_literal (raw_string_literal_content) @injection.content)
       ]))
   (const_spec
     value: (expression_list
       [
         (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
         (raw_string_literal (raw_string_literal_content) @injection.content)
       ]))
   (var_spec
     value: (expression_list
       [
         (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
         (raw_string_literal (raw_string_literal_content) @injection.content)
       ]))
 ]
 (#set! injection.language "sql"))

; 3. Variable/Constant name-based SQL detection
; Detects strings assigned to variables containing 'sql', 'query', 'stmt', or 'cmd'.
((short_var_declaration
    left: (expression_list (identifier) @_var)
    right: (expression_list
             [
               (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
               (raw_string_literal (raw_string_literal_content) @injection.content)
             ]))
  (#lua-match? @_var ".*([Ss][Qq][Ll]|[Qq]uery|[Ss]tmt|[Cc]md).*")
  (#set! injection.language "sql"))

((const_spec
  name: (identifier) @_const
  value: (expression_list
           [
             (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
             (raw_string_literal (raw_string_literal_content) @injection.content)
           ]))
 (#lua-match? @_const ".*([Ss][Qq][Ll]|[Qq]uery|[Ss]tmt|[Cc]md).*")
 (#set! injection.language "sql"))

; 4. Method-specific SQL injections (database/sql, sqlx, etc.)
; Comprehensive list of database-related methods that take SQL strings.
((call_expression
  (selector_expression
    field: (field_identifier) @_method)
  (argument_list
    [
      (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
      (raw_string_literal (raw_string_literal_content) @injection.content)
    ]))
 (#any-of? @_method 
    "Exec" "Query" "QueryRow" "ExecContext" "QueryContext" "QueryRowContext" 
    "Get" "Select" "GetContext" "SelectContext" "Queryx" "QueryRowx" 
    "NamedExec" "NamedQuery" "MustExec" "Rebind" "Prepare" "PrepareContext")
 (#set! injection.language "sql"))

; Handle methods where the SQL string is the second argument (after context)
((call_expression
  (selector_expression
    field: (field_identifier) @_method)
  (argument_list
    (_) ; context or similar
    [
      (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
      (raw_string_literal (raw_string_literal_content) @injection.content)
    ]))
 (#any-of? @_method "ExecContext" "QueryContext" "QueryRowContext" "GetContext" "SelectContext" "PrepareContext")
 (#set! injection.language "sql"))

; =============================================================================
;  JSON INJECTIONS
; =============================================================================

; 1. Variables/Constants with "json" in the name
((short_var_declaration
    left: (expression_list (identifier) @_var)
    right: (expression_list
             [
               (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
               (raw_string_literal (raw_string_literal_content) @injection.content)
             ]))
  (#lua-match? @_var ".*[Jj]son.*")
  (#set! injection.language "json"))

((const_spec
  name: (identifier) @_const
  value: (expression_list
           [
             (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
             (raw_string_literal (raw_string_literal_content) @injection.content)
           ]))
 (#lua-match? @_const ".*[Jj]son.*")
 (#set! injection.language "json"))

; 2. Preceding magic comments: // json, /* json */, // language=json
((comment) @_comment
 (#match? @_comment "(json|language\\=json)")
 .
 [
   (short_var_declaration
     right: (expression_list
       [
         (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
         (raw_string_literal (raw_string_literal_content) @injection.content)
       ]))
   (const_spec
     value: (expression_list
       [
         (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
         (raw_string_literal (raw_string_literal_content) @injection.content)
       ]))
   (var_spec
     value: (expression_list
       [
         (interpreted_string_literal (interpreted_string_literal_content) @injection.content)
         (raw_string_literal (raw_string_literal_content) @injection.content)
       ]))
 ]
 (#set! injection.language "json"))

; 3. General JSON-like strings (starts with { or [)
(([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
] @injection.content)
 (#lua-match? @injection.content "^%s*[{%[]")
 (#lua-match? @injection.content "[}%]]%s*$")
 (#set! injection.language "json"))
