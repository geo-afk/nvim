; ;; extends
;
; ; ----------------------------------------------------------------
; ; SQLC-specific injections (highest priority)
; ; Matches constants with "-- name:" comments from sqlc
; ; ----------------------------------------------------------------
;
; ((const_spec
;   name: (identifier)
;   value: (expression_list
;     (raw_string_literal
;       (raw_string_literal_content) @injection.content)))
;  (#match? @injection.content "^-- name:")
;  (#set! injection.language "sql"))
;
; ; ----------------------------------------------------------------
; ; Primary SQL injection via pattern matching
; ; Matches common SQL statements (case-insensitive via multiple patterns)
; ; ----------------------------------------------------------------
;
; ([
;   (interpreted_string_literal_content)
;   (raw_string_literal_content)
; ] @injection.content
;  (#match? @injection.content "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete|CREATE|create|DROP|drop|ALTER|alter|TRUNCATE|truncate).+(FROM|from|INTO|into|VALUES|values|SET|set|TABLE|table|DATABASE|database|INDEX|index)")
;  (#set! injection.language "sql"))
;
; ; ----------------------------------------------------------------
; ; Fallback: SQL keywords and comments
; ; Catches DDL and other SQL that might not match the main pattern
; ; ----------------------------------------------------------------
;
; ([
;   (interpreted_string_literal_content)
;   (raw_string_literal_content)
; ] @injection.content
;  (#contains? @injection.content 
;     "-- sql" "--sql" "/* sql */" "/*sql*/"
;     "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN"
;     "CREATE TABLE" "DROP TABLE" "CREATE DATABASE" "DROP DATABASE"
;     "FOREIGN KEY" "PRIMARY KEY" "NOT NULL" "UNIQUE"
;     "CREATE INDEX" "DROP INDEX" "LEFT JOIN" "RIGHT JOIN" "INNER JOIN"
;     "GROUP BY" "ORDER BY" "HAVING" "RETURNING"
;     "add constraint" "alter table" "alter column"
;     "create table" "drop table" "create database" "drop database"
;     "foreign key" "primary key" "not null" "unique"
;     "create index" "drop index" "left join" "right join" "inner join"
;     "group by" "order by" "having" "returning")
;  (#set! injection.language "sql"))
;
; ; ----------------------------------------------------------------
; ; Method-specific SQL injections
; ; Inject SQL in database method calls like ExecContext, QueryRowContext
; ; ----------------------------------------------------------------
;
; ((call_expression
;   (selector_expression
;     field: (field_identifier) @_method)
;   (argument_list
;     .
;     (identifier)  ; Skip context argument
;     .
;     (identifier) @_sql_var))  ; The SQL variable
;  (#any-of? @_method 
;     "ExecContext" "QueryContext" "QueryRowContext" 
;     "Exec" "Query" "QueryRow"
;     "GetContext" "SelectContext" "Get" "Select"
;     "Queryx" "QueryRowx" "NamedExec" "NamedQuery" "MustExec"))
;
; ; Also match when SQL string is passed directly
; ((call_expression
;   (selector_expression
;     field: (field_identifier) @_method
;     (#any-of? @_method 
;       "Exec" "Query" "QueryRow" "QueryContext" "ExecContext" "QueryRowContext"
;       "Get" "Select" "Queryx" "QueryRowx" "GetContext" "SelectContext"
;       "NamedExec" "NamedQuery" "MustExec" "Rebind" "RebindNamed"))
;   (argument_list
;     [
;       (interpreted_string_literal
;         (interpreted_string_literal_content) @injection.content)
;       (raw_string_literal
;         (raw_string_literal_content) @injection.content)
;     ]))
;  (#set! injection.language "sql"))
;
; ; ----------------------------------------------------------------
; ; JSON injections
; ; ----------------------------------------------------------------
;
; ; Variables with "json" in the name
; ((short_var_declaration
;     left: (expression_list (identifier) @_var)
;     right: (expression_list
;              (raw_string_literal
;                (raw_string_literal_content) @injection.content)))
;   (#lua-match? @_var ".*[Jj]son.*")
;   (#lua-match? @injection.content "^%s*[{%[]")
;   (#set! injection.language "json"))
;
; ; Constants with "json" in the name
; ((const_spec
;   name: (identifier) @_const
;   value: (expression_list
;            (raw_string_literal
;              (raw_string_literal_content) @injection.content)))
;  (#lua-match? @_const ".*[Jj]son.*")
;  (#lua-match? @injection.content "^%s*[{%[]")
;  (#set! injection.language "json"))
;
; ; General JSON-like strings (stricter pattern)
; ((raw_string_literal
;   (raw_string_literal_content) @injection.content)
;  (#lua-match? @injection.content "^%s*{%s*\"")
;  (#lua-match? @injection.content "}%s*$")
;  (#set! injection.language "json"))




;; extends

; inject sql in single line strings
; e.g. db.GetContext(ctx, "SELECT * FROM users WHERE name = 'John'")
; following no longer works after https://github.com/tree-sitter/tree-sitter-go/commit/47e8b1fae7541f6e01cead97201be19321ec362a
; ((call_expression
;   (selector_expression
;     field: (field_identifier) @_field)
;   (argument_list
;     (interpreted_string_literal) @sql))
;   (#any-of? @_field "Exec" "GetContext" "ExecContext" "SelectContext" "In"
; 				            "RebindNamed" "Rebind" "Query" "QueryRow" "QueryRowxContext" "NamedExec" "MustExec" "Get" "Queryx")
;   (#offset! @sql 0 1 0 -1))
;
; ; still buggy for nvim 0.10
; ((call_expression
;   (selector_expression
;     field: (field_identifier) @_field (#any-of? @_field "Exec" "GetContext" "ExecContext" "SelectContext" "In" "RebindNamed" "Rebind" "Query" "QueryRow" "QueryRowxContext" "NamedExec" "MustExec" "Get" "Queryx"))
;   (argument_list
;     (interpreted_string_literal) @injection.content))
;   (#offset! @injection.content 0 1 0 -1)
;   (#set! injection.language "sql"))

; neovim nightly 0.10
([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
  ] @injection.content
 (#match? @injection.content "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete).+(FROM|from|INTO|into|VALUES|values|SET|set).*(WHERE|where|GROUP BY|group by)?")
(#set! injection.language "sql"))

; a general query injection
([
   (interpreted_string_literal_content)
   (raw_string_literal_content)
 ] @sql
 (#match? @sql "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete).+(FROM|from|INTO|into|VALUES|values|SET|set).*(WHERE|where|GROUP BY|group by)?")
)

; ----------------------------------------------------------------
; fallback keyword and comment based injection

([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
 ] @sql
 (#contains? @sql "-- sql" "--sql" "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN"
                  "DATABASE" "FOREIGN KEY" "GROUP BY" "HAVING" "CREATE INDEX" "INSERT INTO"
                  "NOT NULL" "PRIMARY KEY" "UPDATE SET" "TRUNCATE TABLE" "LEFT JOIN" "add constraint" "alter table" "alter column" "database" "foreign key" "group by" "having" "create index" "insert into"
                  "not null" "primary key" "update set" "truncate table" "left join")
 )

; nvim 0.10
([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
 ] @injection.content
 (#contains? @injection.content "-- sql" "--sql" "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN"
                  "DATABASE" "FOREIGN KEY" "GROUP BY" "HAVING" "CREATE INDEX" "INSERT INTO"
                  "NOT NULL" "PRIMARY KEY" "UPDATE SET" "TRUNCATE TABLE" "LEFT JOIN" "add constraint" "alter table" "alter column" "database" "foreign key" "group by" "having" "create index" "insert into"
                  "not null" "primary key" "update set" "truncate table" "left join")
 (#set! injection.language "sql"))


; should I use a more exhaustive list of keywords?
;  "ADD" "ADD CONSTRAINT" "ALL" "ALTER" "AND" "ASC" "COLUMN" "CONSTRAINT" "CREATE" "DATABASE" "DELETE" "DESC" "DISTINCT" "DROP" "EXISTS" "FOREIGN KEY" "FROM" "JOIN" "GROUP BY" "HAVING" "IN" "INDEX" "INSERT INTO" "LIKE" "LIMIT" "NOT" "NOT NULL" "OR" "ORDER BY" "PRIMARY KEY" "SELECT" "SET" "TABLE" "TRUNCATE TABLE" "UNION" "UNIQUE" "UPDATE" "VALUES" "WHERE"

; json

((const_spec
  name: (identifier) @_const
  value: (expression_list (raw_string_literal) @json))
 (#lua-match? @_const ".*[J|j]son.*"))

; jsonStr := `{"foo": "bar"}`

((short_var_declaration
    left: (expression_list
            (identifier) @_var)
    right: (expression_list
             (raw_string_literal) @json))
  (#lua-match? @_var ".*[J|j]son.*")
  (#offset! @json 0 1 0 -1))

; nvim 0.10
(const_spec
  name: (identifier)
  value: (expression_list
	   (raw_string_literal
	     (raw_string_literal_content) @injection.content
             (#lua-match? @injection.content "^[\n|\t| ]*\{.*\}[\n|\t| ]*$")
             (#set! injection.language "json")
	    )
  )
)

(short_var_declaration
    left: (expression_list (identifier))
    right: (expression_list
             (raw_string_literal
               (raw_string_literal_content) @injection.content
               (#lua-match? @injection.content "^[\n|\t| ]*\{.*\}[\n|\t| ]*$")
               (#set! injection.language "json")
             )
    )
)

(var_spec
  name: (identifier)
  value: (expression_list
           (raw_string_literal
             (raw_string_literal_content) @injection.content
             (#lua-match? @injection.content "^[\n|\t| ]*\{.*\}[\n|\t| ]*$")
             (#set! injection.language "json")
           )
  )
)
