%{
open Syntax
%}

%token EXIT
%token PERIOD QUESTION QUESTIONQUESTION COLONDASH
%token COMMA SEMICOLON NOT EQUAL LPAR RPAR
%token LBRKT RBRKT CONS
%token TRUE FALSE
%token <int> NUM
%token PLUS
%token <string> ID VAR
%token WILDCARD

%left SEMICOLON
%left COMMA
%nonassoc UNARY_NOT

%start toplevel
%type <Syntax.cmd> toplevel
%%

toplevel:
  | EXIT { CmdExit }
  | prop QUESTION { CmdQuery $1 }
  | prop QUESTIONQUESTION { CmdQueryAll $1 }
  | ID LPAR pats RPAR PERIOD { CmdDef ($1, $3, PropTrue) }
  | ID LPAR pats RPAR COLONDASH prop PERIOD { CmdDef ($1, $3, $6) }

prop:
  | prop SEMICOLON prop { PropOr ($1, $3) }
  | prop COMMA prop { PropAnd ($1, $3) }
  | NOT prop %prec UNARY_NOT { PropNot $2 }
  | LPAR prop RPAR { $2 }
  | ID LPAR pats RPAR { PropPred ($1, $3) }
  | EQUAL LPAR pat COMMA pat RPAR { PropEq ($3, $5) }
  | TRUE { PropTrue }
  | FALSE { PropFalse }

pat:
  | WILDCARD { PatWildcard }
  | VAR { PatVar $1 }
  | ID { PatConst $1 }
  | NUM { let rec go n = if n = 0 then PatConst "z" else PatApp ("s", [go (n - 1)]) in go $1 }
  | NUM PLUS pat { let rec go n = if n = 0 then $3 else PatApp ("s", [go (n - 1)]) in go $1 }
  | ID LPAR pats RPAR { PatApp ($1, $3) }
  | LPAR pats RPAR { if List.length $2 = 1 then List.hd $2 else PatApp ("tuple", $2) }
  | LBRKT pats RBRKT {
      List.fold_right (fun pat acc -> PatApp ("cons", [pat; acc])) $2 (PatConst "nil")
    }
  | LBRKT pats_plus CONS pat RBRKT {
      List.fold_right (fun pat acc -> PatApp ("cons", [pat; acc])) $2 $4
    }

pats:
  | { [] }
  | pats_plus { $1 }

pats_plus:
  | pat { [$1] }
  | pat COMMA pats_plus { $1 :: $3 }
