;; extends

; ----------------------------------------------------------------
; SQLC-specific injections (highest priority)
; Matches constants with "-- name:" comments from sqlc
; ----------------------------------------------------------------

((const_spec
  name: (identifier)
  value: (expression_list
    (raw_string_literal
      (raw_string_literal_content) @injection.content)))
 (#match? @injection.content "^-- name:")
 (#set! injection.language "sql"))

; ----------------------------------------------------------------
; Primary SQL injection via pattern matching
; Matches common SQL statements (case-insensitive via multiple patterns)
; ----------------------------------------------------------------

([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
] @injection.content
 (#match? @injection.content "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete|CREATE|create|DROP|drop|ALTER|alter|TRUNCATE|truncate).+(FROM|from|INTO|into|VALUES|values|SET|set|TABLE|table|DATABASE|database|INDEX|index)")
 (#set! injection.language "sql"))

; ----------------------------------------------------------------
; Fallback: SQL keywords and comments
; Catches DDL and other SQL that might not match the main pattern
; ----------------------------------------------------------------

([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
] @injection.content
 (#contains? @injection.content 
    "-- sql" "--sql" "/* sql */" "/*sql*/"
    "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN"
    "CREATE TABLE" "DROP TABLE" "CREATE DATABASE" "DROP DATABASE"
    "FOREIGN KEY" "PRIMARY KEY" "NOT NULL" "UNIQUE"
    "CREATE INDEX" "DROP INDEX" "LEFT JOIN" "RIGHT JOIN" "INNER JOIN"
    "GROUP BY" "ORDER BY" "HAVING" "RETURNING"
    "add constraint" "alter table" "alter column"
    "create table" "drop table" "create database" "drop database"
    "foreign key" "primary key" "not null" "unique"
    "create index" "drop index" "left join" "right join" "inner join"
    "group by" "order by" "having" "returning")
 (#set! injection.language "sql"))

; ----------------------------------------------------------------
; Method-specific SQL injections
; Inject SQL in database method calls like ExecContext, QueryRowContext
; ----------------------------------------------------------------

((call_expression
  (selector_expression
    field: (field_identifier) @_method)
  (argument_list
    .
    (identifier)  ; Skip context argument
    .
    (identifier) @_sql_var))  ; The SQL variable
 (#any-of? @_method 
    "ExecContext" "QueryContext" "QueryRowContext" 
    "Exec" "Query" "QueryRow"
    "GetContext" "SelectContext" "Get" "Select"
    "Queryx" "QueryRowx" "NamedExec" "NamedQuery" "MustExec"))

; Also match when SQL string is passed directly
((call_expression
  (selector_expression
    field: (field_identifier) @_method
    (#any-of? @_method 
      "Exec" "Query" "QueryRow" "QueryContext" "ExecContext" "QueryRowContext"
      "Get" "Select" "Queryx" "QueryRowx" "GetContext" "SelectContext"
      "NamedExec" "NamedQuery" "MustExec" "Rebind" "RebindNamed"))
  (argument_list
    [
      (interpreted_string_literal
        (interpreted_string_literal_content) @injection.content)
      (raw_string_literal
        (raw_string_literal_content) @injection.content)
    ]))
 (#set! injection.language "sql"))

; ----------------------------------------------------------------
; JSON injections
; ----------------------------------------------------------------

; Variables with "json" in the name
((short_var_declaration
    left: (expression_list (identifier) @_var)
    right: (expression_list
             (raw_string_literal
               (raw_string_literal_content) @injection.content)))
  (#lua-match? @_var ".*[Jj]son.*")
  (#lua-match? @injection.content "^%s*[{%[]")
  (#set! injection.language "json"))

; Constants with "json" in the name
((const_spec
  name: (identifier) @_const
  value: (expression_list
           (raw_string_literal
             (raw_string_literal_content) @injection.content)))
 (#lua-match? @_const ".*[Jj]son.*")
 (#lua-match? @injection.content "^%s*[{%[]")
 (#set! injection.language "json"))

; General JSON-like strings (stricter pattern)
((raw_string_literal
  (raw_string_literal_content) @injection.content)
 (#lua-match? @injection.content "^%s*{%s*\"")
 (#lua-match? @injection.content "}%s*$")
 (#set! injection.language "json"))
