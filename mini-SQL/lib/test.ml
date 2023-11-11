open Parser
open Ast

(* Запускает парсер на строке *)
let run p = Angstrom.parse_string ~consume:All p

let assert_equal parser input expected =
  match run parser input with
  | Ok res when res = expected -> true
  | _ -> false
;;

let assert_eq_output f parser input expected =
  let res = run parser input in
  match res with
  | Ok res when res <> expected ->
    Format.printf "Parsing result: %s!!!\n" (f res);
    false
  | Ok _ -> true
  | Error x ->
    Format.printf "Parsing error: %s!!!\n" x;
    false
;;

let assert_raise parser input =
  let tryRun p i =
    match run p i with
    | Ok _ -> true
    | _ -> false
  in
  try not (tryRun parser input) with
  | _ -> true
;;

(* String *)
let%test _ = assert_equal value_p "\'1a2b3c 7\'" (String "1a2b3c 7")
let%test _ = assert_equal value_p "\"1a2b3c 7\"" (String "1a2b3c 7")
let%test _ = assert_raise value_p "\"1a2b3c 7\'"

(* Name *)
let%test _ = assert_eq_output show_value value_p "User" (Name "User")
let%test _ = assert_equal value_p "table1.age" (Name "table1.age")
let%test _ = assert_raise value_p "1name"

(* Bool *)
let%test _ = assert_equal value_p "True" (Bool true)
let%test _ = assert_equal value_p "true" (Bool true)
let%test _ = assert_equal value_p "False" (Bool false)
let%test _ = assert_equal value_p "false" (Bool false)

(* Digit *)
let%test _ = assert_equal value_p "10" (Digit 10)
let%test _ = assert_equal value_p "+10" (Digit 10)
let%test _ = assert_equal value_p "-10" (Digit (-10))
let%test _ = assert_equal value_p "+10.5" (Float_Digit 10.5)
let%test _ = assert_equal value_p "-10.0000" (Float_Digit (-10.0))
let%test _ = assert_equal value_p "10.015" (Float_Digit 10.015)
let%test _ = assert_equal value_p "8." (Float_Digit 8.)
let%test _ = assert_raise value_p "-12a3"

(* Join *)

let%test _ =
  assert_equal
    join_p
    "table1 FULL OUTER JOIN table2 ON table1.column_name >= table2.column_name"
    (Join {jtype = Full; left = Table "table1"; table = "table2"; on = (Binary_operation (Greater_Than_Or_Equal, Const (Name "table1.column_name" ), Const (Name "table2.column_name" )))})
;;

let%test _ = 
  assert_raise
  on_p
  "ON table1+table2"

  let%test _ =
  assert_equal
    join_p
    "(table1 FULL OUTER JOIN table2 ON table1.column_name >= table2.column_name) INNER JOIN table3 ON table2.column_name = table3.column_name"
    (Join {jtype = Inner;
    left =
    Join {jtype = Full; left = (Table "table1"); table = "table2";
      on =
      (Binary_operation (Greater_Than_Or_Equal,
         (Const (Name "table1.column_name")),
         (Const (Name "table2.column_name"))))};
    table = "table3";
    on =
    (Binary_operation (Equal, (Const (Name "table2.column_name")),
       (Const (Name "table3.column_name"))))})
;;

let%test _ = assert_equal on_p "ON table1=table2" (Binary_operation(Equal, Const (Name "table1"), Const (Name "table2")))


(* arithm_p *)

let%test _ =
  assert_equal arithm_p "2+2" (Binary_operation (Add, Const (Digit 2), Const (Digit 2)))
;;

let%test _ =
  assert_equal
    arithm_p
    "( 2 + 2)"
    (Binary_operation (Add, Const (Digit 2), Const (Digit 2)))
;;

let%test _ =
  assert_equal
    arithm_p
    "2 / -2"
    (Binary_operation (Divide, Const (Digit 2), Const (Digit (-2))))
;;

let%test _ =
  assert_equal
    arithm_p
    "-2 - -2"
    (Binary_operation (Substract, Const (Digit (-2)), Const (Digit (-2))))
;;

let%test _ =
  assert_equal
    arithm_p
    "-2 * +2"
    (Binary_operation (Multiply, Const (Digit (-2)), Const (Digit 2)))
;;

let%test _ =
  assert_equal
    arithm_p
    "123 % 10"
    (Binary_operation (Modulo, Const (Digit 123), Const (Digit 10)))
;;

let%test _ =
  assert_equal
    arithm_p
    "(1 + 1) * 2"
    (Binary_operation
       ( Multiply
       , Binary_operation (Add, Const (Digit 1), Const (Digit 1))
       , Const (Digit 2) ))
;;

let%test _ =
  assert_equal
    arithm_p
    "(1 + 1) * (123 % 10)"
    (Binary_operation
       ( Multiply
       , Binary_operation (Add, Const (Digit 1), Const (Digit 1))
       , Binary_operation (Modulo, Const (Digit 123), Const (Digit 10)) ))
;;

(* logic *)

let%test _ =
  assert_equal
    cmp_p
    "1 + 1 != 2.5 + 2"
    (Binary_operation
       ( Not_Equal
       , Binary_operation (Add, Const (Digit 1), Const (Digit 1))
       , Binary_operation (Add, Const (Float_Digit 2.5), Const (Digit 2)) ))
;;

let%test _ =
  assert_equal
    cmp_p
    "1 = 2 - 1 = 0 + 1"
    (Binary_operation
       ( Equal
       , Binary_operation
           ( Equal
           , Const (Digit 1)
           , Binary_operation (Substract, Const (Digit 2), Const (Digit 1)) )
       , Binary_operation (Add, Const (Digit 0), Const (Digit 1)) ))
;;

let%test _ =
  assert_equal
    logic_p
    "1 = 2 AND 0 = 1"
    (Binary_operation
       ( And
       , Binary_operation (Equal, Const (Digit 1), Const (Digit 2))
       , Binary_operation (Equal, Const (Digit 0), Const (Digit 1)) ))
;;

let%test _ =
  assert_eq_output
    show_expr
    logic_p
    "NOT 0 = 1"
    (Unary_operation (Not, (Binary_operation (Equal, (Const (Digit 0)), (Const (Digit 1))))))
;;

let%test _ =
  assert_equal
    logic_p
    "\'123\' = 2 AND ID > 1 OR 1 + 1 = 2"
    (Binary_operation
       ( Or
       , Binary_operation
           ( And
           , Binary_operation (Equal, Const (String "123"), Const (Digit 2))
           , Binary_operation (Greater_Than, Const (Name "ID"), Const (Digit 1))
           )
       , Binary_operation
           ( Equal
           , Binary_operation (Add, Const (Digit 1), Const (Digit 1))
           , Const (Digit 2) ) ))
;;

let%test _ =
  assert_eq_output
    show_request
    parse
    "SELECT name, age, phone_number FROM User WHERE age > 18"
    { select =
        [ Expression (Const (Name "name"))
        ; Expression (Const (Name "age"))
        ; Expression (Const (Name "phone_number"))
        ]
    ; from = Table "User"
    ; where =
        Some
          (Binary_operation (Greater_Than, Const (Name "age"), Const (Digit 18)))
    }
;;

let%test _ = assert_raise arithm_p "-2 x 2"
