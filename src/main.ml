open Syntax
open Lexing
open Lexer
open Parsing
open Parser

exception Var_in_neg

type 'a stream =
| Cons of 'a * 'a stream Lazy.t
| Nil

let rec smap f xs = match xs with
| Cons (x, lxs') -> Cons (f x, lazy (smap f (Lazy.force lxs')))
| Nil -> Nil

let omap f ox = match ox with
| Some x -> Some (f x)
| None -> None

let id_ref = ref 0
let new_id () = id_ref := !id_ref + 1; !id_ref
let reset_id () = id_ref := 0

let print_list left right delim print_elem xs =
match xs with
| [] -> print_string left; print_string right
| x :: xs' -> print_string left; print_elem x; List.iter (fun x -> print_string delim; print_elem x) xs'; print_string right

let rec print_prop prop = match prop with
| PropOr (prop1, prop2) ->
  print_string "(";
  print_prop prop1;
  print_string ";";
  print_prop prop2;
  print_string ")"
| PropAnd (prop1, prop2) ->
  print_string "(";
  print_prop prop1;
  print_string ",";
  print_prop prop2;
  print_string ")"
| PropNot prop ->
  print_string "!";
  print_prop prop
| PropEq (pat1, pat2) ->
  print_string "=(";
  print_pat pat1;
  print_string ",";
  print_pat pat2;
  print_string ")"
| PropPred (name, pats) ->
  print_list (name ^ "(") ")" "," print_pat pats
| PropTrue -> print_string "true"
| PropFalse -> print_string "false"
| PropCxt (sol, prop) ->
  print_string "(";
  print_prop prop;
  print_string " where ";
  print_sol sol;
  print_string ")"
and print_pat pat = match pat with
| PatWildcard -> print_string "_"
| PatConst "z" -> print_int 0
| PatConst "nil" -> print_string "[]"
| PatConst name -> print_string name
| PatVar name -> print_string name
| PatApp ("s", [_]) -> print_nat_pat 0 pat
| PatApp ("cons", [pat1; pat2]) ->
  print_string "[";
  print_pat pat1;
  print_tail_pat pat2;
  print_string "]"
| PatApp (name, pats) ->
  print_list (name ^ "(") ")" "," print_pat pats
and print_nat_pat n pat = match pat with
| PatApp ("s", [pat']) -> print_nat_pat (n + 1) pat'
| PatConst "z" -> print_int n
| _ -> print_int n; print_string " + "; print_pat pat
and print_tail_pat pat = match pat with
| PatApp ("cons", [pat1; pat2]) ->
  print_string ", ";
  print_pat pat1;
  print_tail_pat pat2
| PatConst "nil" -> ()
| _ -> print_string " | "; print_pat pat
and print_sol sol =
  print_list "(" ")" ", " (fun (pat1, pat2) ->
    print_pat pat1; print_string " = "; print_pat pat2)
    (List.filter (fun (pat1, _) -> match pat1 with
  | PatVar name -> not (String.contains name '@')
  | _ -> failwith "invalid solution") sol)

let rec update_id_pat id pat = match pat with
| PatWildcard | PatConst _ -> pat
| PatVar name -> PatVar (name^"@"^string_of_int id)
| PatApp (name', pats) -> PatApp (name', List.map (update_id_pat id) pats)
and update_id_prop id prop = match prop with
| PropOr (prop1, prop2) -> PropOr (update_id_prop id prop1, update_id_prop id prop2)
| PropAnd (prop1, prop2) -> PropAnd (update_id_prop id prop1, update_id_prop id prop2)
| PropNot prop -> PropNot (update_id_prop id prop)
| PropEq (pat1, pat2) -> PropEq (update_id_pat id pat1, update_id_pat id pat2)
| PropPred (name, pats) -> PropPred (name, List.map (update_id_pat id) pats)
| PropTrue | PropFalse -> prop
| PropCxt (_, _) -> failwith "PropCxt should not come here"

let rec occur name pat = match pat with
| PatWildcard | PatConst _ -> false
| PatVar name' -> name = name'
| PatApp (_, pats) -> List.exists (occur name) pats
and subst_pat sol pat = match pat with
| PatWildcard | PatConst _ -> pat
| PatVar _ -> (try List.assoc pat sol with Not_found -> pat)
| PatApp (name, pats) -> PatApp (name, List.map (subst_pat sol) pats)
and subst_sol sol sol' = List.map (fun (pat1, pat2) ->
  subst_pat sol pat1, subst_pat sol pat2) sol'
and unify sol = match sol with
| [] -> Some []
| (pat1, pat2) :: sol' when pat1 = pat2 -> unify sol'
| (PatWildcard, _) :: sol' | (_, PatWildcard) :: sol' -> unify sol'
| (PatVar name, pat) :: sol' | (pat, PatVar name) :: sol' ->
  if occur name pat then None
  else (
    match unify (subst_sol [(PatVar name, pat)] sol') with
    | Some sol'' -> Some ((PatVar name, subst_pat sol'' pat) :: sol'')
    | None -> None)
| (PatApp (name1, pats1), PatApp (name2, pats2)) :: sol'
  when name1 = name2 && List.length pats1 = List.length pats2 ->
  unify (List.fold_right2 (fun pat1 pat2 sol'' -> (pat1, pat2) :: sol'') pats1 pats2 sol')
| _ -> None

let rec query env cxt prop = match prop with
| PropOr (prop1, prop2) ->
  let rec zip_or osols1 osols2 = match osols1, osols2 with
  | Nil, _ -> osols2
  | _, Nil -> osols1
  | Cons (osol1, losols1'), Cons (osol2, losols2') ->
    Cons (osol1, lazy (Cons (osol2, (lazy (zip_or (Lazy.force losols1') (Lazy.force losols2')))))) in
  zip_or (query env cxt prop1) (query env cxt prop2)
| PropAnd (prop1, prop2) ->
  let rec simple_and hsols osol lnosols = match hsols with
  | [] -> Lazy.force lnosols
  | hsol :: hsols' ->
    Cons ((match osol with Some sol -> unify (hsol @ sol) | None -> None),
      lazy (simple_and hsols' osol lnosols))
  and finite_or hsols prop = query env [] (List.fold_right (fun hsol acc ->
    PropOr (PropCxt (hsol, prop), acc)) hsols PropFalse)
  and zip_and hsols1 hsols2 osols1 osols2 = match osols1, osols2 with
  | Nil, _ -> finite_or hsols1 prop2
  | _, Nil -> finite_or hsols2 prop1
  | Cons (osol1, losols1'), Cons (osol2, losols2') ->
    let osol = match osol1, osol2 with
    | Some sol1, Some sol2 -> unify (sol1 @ sol2)
    | _ -> None in
    let xsnoc hsols osol = match osol with
    | Some sol -> hsols @ [sol]
    | None -> hsols in
    simple_and hsols1 osol2 (lazy (simple_and hsols2 osol1 (lazy (Cons (osol,
      (lazy (zip_and (xsnoc hsols1 osol1) (xsnoc hsols2 osol2)
        (Lazy.force losols1') (Lazy.force losols2')))))))) in
  zip_and [] [] (query env cxt prop1) (query env cxt prop2)
| PropNot prop ->
  let rec prop_has_var prop = match prop with
  | PropOr (prop1, prop2) | PropAnd (prop1, prop2) -> prop_has_var prop1 || prop_has_var prop2
  | PropNot prop -> prop_has_var prop
  | PropEq (pat1, pat2) -> pat_has_var pat1 || pat_has_var pat2
  | PropPred (_, pats) -> List.exists pat_has_var pats
  | PropTrue | PropFalse -> false
  | PropCxt (_, _) -> failwith "PropCxt should not come here"
  and pat_has_var pat = match pat with
  | PatWildcard | PatConst _ -> false
  | PatVar _ -> true
  | PatApp (_, pats) -> List.exists pat_has_var pats in
  if prop_has_var prop then raise Var_in_neg else
  let rec go oss = match oss with
  | Nil -> Cons (Some cxt, lazy Nil)
  | Cons (Some _, _) -> Nil
  | Cons (None, lazy oss') -> go oss' in
  go (query env cxt prop)
| PropEq (pat1, pat2) -> (match unify [(pat1, pat2)] with
  | Some sol -> Cons (Some sol, lazy Nil)
  | None -> Nil)
| PropPred (name, pats) ->
  let id = new_id () in
  let new_prop = List.fold_right (fun (name', pats', prop') acc_prop ->
    if name = name' && List.length pats = List.length pats' then
      let patpats = List.map2 (fun pat pat' -> pat, update_id_pat id pat') pats pats' in
      match unify (cxt @ patpats) with
      | None -> acc_prop
      | Some cxt' -> PropOr (PropCxt (cxt', update_id_prop id prop'), acc_prop)
    else acc_prop) env PropFalse in
  Cons (None, lazy (smap (omap (List.filter (fun (pat1, _) -> match pat1 with
  | PatVar name -> let names = String.split_on_char '@' name in
    List.length names = 1 || int_of_string (List.hd (List.tl names)) < id
  | _ -> failwith "invalid solution"))) (query env [] new_prop)))
| PropTrue -> Cons (Some cxt, lazy Nil)
| PropFalse -> Nil
| PropCxt (cxt', prop) -> if cxt <> [] then failwith "cxt should be null for PropCxt"
  else query env cxt' prop

let rec loop env =
  print_string "- ";
  flush stdout;
  loop (try
    match toplevel lexer (from_channel stdin) with
    | CmdExit ->
      print_endline "Goodbye.";
      exit 0
    | CmdQuery prop ->
      let rec go found osols = match osols with
      | Nil ->
        if found then print_endline "No other solution."
        else print_endline "No solution at all."
      | Cons (Some sol, losols') ->
        print_sol sol; print_newline ();
        print_endline "Do you want another solution? (\"y\"/otherwise)";
        let reply = input_line stdin in
        if reply = "y" then go true (Lazy.force losols') else ()
      | Cons (None, losols') ->
        go found (Lazy.force losols') in
      reset_id ();
      go false (query env [] prop);
      env
    | CmdQueryAll prop ->
      let rec go found osols = match osols with
      | Nil ->
        if found then print_endline "No other solution."
        else print_endline "No solution at all."
      | Cons (Some sol, losols') ->
        print_sol sol; print_newline ();
        go true (Lazy.force losols')
      | Cons (None, losols') ->
        go found (Lazy.force losols') in
      reset_id ();
      go false (query env [] prop);
      env
    | CmdDef (name, pats, prop) -> env @ [(name, pats, prop)]
  with
  | Failure sol when sol = "lexing: empty token" -> print_endline "Error: Empty Token"; env
  | Lex_error (c, i) -> print_endline (
      "Error: Lexing error at position "^string_of_int i^" starting with "^Char.escaped c
    ); env
  | Parse_error -> print_endline "Error: Syntax error"; env
  | Var_in_neg -> print_endline "Error: Variable in negation"; env
  | Sys.Break -> print_endline "Interrupted."; env
  | Stack_overflow -> print_endline "Error: Stack overflow"; env
  | e -> print_endline ("Error: Unknown error: "^Printexc.to_string e); env)

let _ = Sys.catch_break true; loop []
