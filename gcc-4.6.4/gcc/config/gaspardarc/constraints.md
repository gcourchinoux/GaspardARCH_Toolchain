;; GPL-3.0-or-later.
(define_constraint "I" "Signed twelve-bit immediate." (and (match_code "const_int") (match_test "IN_RANGE(ival,-2048,2047)")))
(define_constraint "J" "Five-bit shift count." (and (match_code "const_int") (match_test "IN_RANGE(ival,0,31)")))
(define_constraint "K" "Six-bit shift count." (and (match_code "const_int") (match_test "IN_RANGE(ival,0,63)")))
