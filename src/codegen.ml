open Ast
open Stringify

module NameMap = Map.Make(String);;

let block_template ret_expr = function
  | None ->
    let template = format_of_string "(function() { return %s })()"
    in Printf.sprintf template ret_expr
  | Some(xs) ->
    let template = format_of_string "
    (function() {
        %s
        return %s
    })()"
    in Printf.sprintf template xs ret_expr
;;

let if_template pred e1 e2 =
  let name = "res_" ^ string_of_int(Random.int 1000000)
  and template = format_of_string "(function() {
        let %s
        if (%s) {
            %s = %s
        } else {
            %s = %s
        }
        return %s
    })()"
  in
  Printf.sprintf template name pred name e1 name e2 name
;;

(* removes all ? from string and replaces with __. used for codegen
   since JS doesnt support ? in var names *)
let remove_qmark s =
  Str.global_replace (Str.regexp_string "?") "__" s
;;

let rec js_of_expr name map = function
  | NumLit(x) -> Printf.sprintf "%s" (string_of_float x)
  | StrLit(s) -> Printf.sprintf "\"%s\"" s
  | BoolLit(b) -> Printf.sprintf "%s" (string_of_bool b)
  | UnitLit -> "null"
  | Unop(o, e) ->
    let s1 = string_of_op o and s2 = js_of_expr name map e in
    Printf.sprintf "%s%s" s1 s2
  | Binop(e1, o, e2) ->
    let s2 = js_of_expr name map e1
    and s3 = js_of_expr name map e2 in
    (match o with
      | Cons -> Printf.sprintf "(%s).insert(0, %s)" s3 s2
      | Caret -> Printf.sprintf "(%s + %s)" s2 s3
      | _ -> Printf.sprintf "(%s %s %s)" s2 (string_of_op o) s3)
  | Val(s) ->
    if NameMap.mem s map
    then Printf.sprintf "%s.%s" name (remove_qmark s)
    else (remove_qmark s)
  | Assign(id, _, e) ->
    if NameMap.mem id map
    then Printf.sprintf "%s.%s = %s" name (remove_qmark id) (js_of_expr name map e)
    else Printf.sprintf "let %s = %s" (remove_qmark id) (js_of_expr name map e)
  | Block(es) ->
    let es = List.rev (List.map (fun e -> js_of_expr name map e) es) in
    (match es with
    | [] -> "" (* will never be reached *)
    | x :: [] -> block_template x None
    | x :: xs ->
      let es = String.concat "\n" (List.rev xs) in
      block_template x (Some es))
  | If(p, e1, e2) ->
    let pred_s = js_of_expr name map p
    and s1 = js_of_expr name map e1
    and s2 = js_of_expr name map e2 in
    if_template pred_s s1 s2
  | FunLit(fdecl) ->
    let formals = List.map (fun (x, _) -> x) fdecl.formals in
    let string_forms = String.concat "," formals in
    let string_body = js_of_expr name map fdecl.body in
    let template = format_of_string "(function(%s) { return (%s) })" in
    Printf.sprintf template string_forms string_body
  | Call(id, es) ->
    let id = if NameMap.mem id map
    then Printf.sprintf "%s.%s" name (remove_qmark id)
    else (remove_qmark id) in
    let es = List.map (fun e -> js_of_expr name map e) es in
    (match id with
     | "print" -> Printf.sprintf "console.log(%s)" (String.concat "," es)
     | "hd" -> Printf.sprintf "(%s).get(0)" (List.hd es)
     | "tl" -> Printf.sprintf "(%s).delete(0)" (List.hd es)
     | "empty__" -> Printf.sprintf "(%s).isEmpty()" (List.hd es)
     | "get" -> Printf.sprintf "(%s).get((%s).toString())" (List.hd es) (List.nth es 1)
     | "set" -> Printf.sprintf "(%s).set((%s).toString(), %s)" (List.hd es) (List.nth es 1) (List.nth es 2)
     | "has__" -> Printf.sprintf "(%s).has((%s).toString())" (List.hd es) (List.nth es 1)
     | "keys" -> Printf.sprintf "Immutable.fromJS(Array.from((%s).keys()))" (List.hd es)
     | "del" -> Printf.sprintf "(%s).remove((%s).toString())" (List.hd es) (List.nth es 1)
     | _ -> Printf.sprintf "%s(%s)" id (String.concat "," es))
  | ListLit(es) -> let es = String.concat ", " (List.map (fun e -> js_of_expr name map e) es) in
    Printf.sprintf "Immutable.List.of(%s)" es
  | ModuleLit(id, e) -> Printf.sprintf "%s.%s" id (js_of_expr name map e)
  | MapLit(kvpairs) ->
    let pairs = List.map (fun (k, v) ->
        Printf.sprintf "%s:%s" (js_of_expr name map k)
          (js_of_expr name map v)) kvpairs in
    Printf.sprintf "Immutable.Map({ %s })" (String.concat "," pairs)
;;
