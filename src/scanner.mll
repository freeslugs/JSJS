{ open Parser }

let digit = ['0'-'9']
let id = ['a'-'z'] ['a'-'z' 'A'-'Z' '0'-'9' '_']* ['?']?
let ws = [' ' '\r' '\n' '\t']
let number = digit+ '.'? digit*
let module_lit = ['A'-'Z'] ['a'-'z' 'A'-'Z']*
let string_lit = (([' '-'!' '#'-'[' ']'-'~'] | '\\' ['\\' '"' 'n' 'r' 't'])* as s)

rule token = 
    parse
    | ws                        { token lexbuf; }
    | '+'                       { PLUS }
    | '-'                       { MINUS }
    | '*'                       { MULTIPLY }
    | '/'                       { DIVIDE }
    | '%'                       { MODULUS }
    | '<'                       { LT }
    | '>'                       { GT }
    | '='                       { ASSIGN }
    | '!'                       { NOT }
    | '^'                       { CARET }
    | "<="                      { LTE }
    | ">="                      { GTE }
    | "=="                      { EQUALS }
    | "!="                      { NEQ }
    | "&&"                      { AND }
    | "||"                      { OR }
    | "//"                      { comment lexbuf; }
    | "val"                     { VAL }
    | "if"                      { IF }
    | "else"                    { ELSE }
    | "then"                    { THEN }
    | "def"                     { DEF }
    | "true"                    { TRUE }
    | "false"                   { FALSE }
    | "num"                     { NUM }
    | "bool"                    { BOOL }
    | "unit"                    { UNIT }
    | "string"                  { STRING }
    | "list"                    { LIST }
    | ':'                       { COLON }
    | '('                       { LPAREN }
    | ')'                       { RPAREN }
    | '.'                       { DOT }
    | '{'                       { LBRACE }
    | '}'                       { RBRACE }
    | ';'                       { SEMICOLON }
    | '['                       { LSQUARE }
    | ']'                       { RSQUARE }
    | ','                       { COMMA }
    | "=>"                      { FATARROW }
    | "->"                      { THINARROW }
    | number as num             { NUM_LIT(float_of_string num); }
    | '"' (string_lit as s) '"' { STR_LIT(s); }
    | id     as ident           { ID(ident); }
    | module_lit  as m_lit      { MOD_LIT(m_lit); }
    | _                         { failwith "Syntax error" }
    | eof                       { raise End_of_file }

and comment = 
    parse
    | '\n' { token lexbuf }
    | _  { comment lexbuf }

{
    let rec parse lexbuf = 
        let _ = token lexbuf in parse lexbuf
    ;;

    let main () = 
        (* checks for a file as the first argument
         * else defaults to stdin *)
        let cin = 
            if Array.length Sys.argv > 1
            then open_in Sys.argv.(1)
            else stdin
        in
        let lexbuf = Lexing.from_channel cin in
        try parse lexbuf with
        | End_of_file -> ()
    ;;

    main ();;
}
