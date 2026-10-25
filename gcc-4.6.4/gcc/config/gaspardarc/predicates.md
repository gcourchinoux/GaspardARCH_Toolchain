;; GPL-3.0-or-later.
(define_predicate "ga_arith_operand" (ior (match_operand 0 "register_operand") (and (match_code "const_int") (match_test "IN_RANGE(INTVAL(op),-2048,2047)"))))
(define_predicate "ga_shift_operand" (ior (match_operand 0 "register_operand") (and (match_code "const_int") (match_test "IN_RANGE(INTVAL(op),0,mode==SImode?31:63)"))))
(define_predicate "ga_comparison" (match_code "eq,ne,lt,le,gt,ge,ltu,leu,gtu,geu"))
(define_predicate "ga_call_operand" (match_code "reg,symbol_ref"))
