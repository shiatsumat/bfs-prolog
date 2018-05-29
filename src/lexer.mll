{
open Lexing
exception Lex_error of char * int
}

let space = ' ' | '\t' | '\r' | '\n'
let digit = ['0'-'9']
let small = ['a'-'z']
let capital = ['A'-'Z']
let alpha = small | capital | ['_']

rule lexer = parse

| space+ { lexer lexbuf }

| "@" { Parser.EXIT }

| "." { Parser.PERIOD }
| "??" { Parser.QUESTIONQUESTION }
| "?" { Parser.QUESTION }
| ":-" { Parser.COLONDASH }

| "," { Parser.COMMA }
| ";" { Parser.SEMICOLON }
| "!" { Parser.NOT }
| "(" { Parser.LPAR }
| ")" { Parser.RPAR }
| "=" { Parser.EQUAL }

| "[" { Parser.LBRKT }
| "]" { Parser.RBRKT }
| "|" { Parser.CONS }

| "true" { Parser.TRUE }
| "false" { Parser.FALSE }

| digit+ as num { Parser.NUM (int_of_string num) }
| "+" { Parser.PLUS }

| small alpha* as id { Parser.ID id }
| capital alpha* | '_' alpha+ as var { Parser.VAR var }
| '_' { Parser.WILDCARD }

| _ { raise (Lex_error (lexeme_char lexbuf 0, lexeme_start lexbuf)) }
