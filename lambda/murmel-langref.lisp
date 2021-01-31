;;;
;;; === Murmel Language Reference ====
;;;
;;; This file is an executable language reference manual
;;; for Murmel, a single-namespace Lisp dialect.
;;;
;;; You can read this file or run it with:
;;; java -jar jmurmel.jar --repl --echo < murmel-langref.lisp
;;; or:
;;; java -jar jmurmel.jar --repl --echo < murmel-langref.lisp > murmel.txt
;;;
;;; Note the section "Known issues" at the end of this files.
;;;
;;; See also:
;;; java -jar jmurmel.jar --help ... will print usage information
;;;
;;; In JMurmels REPL:
;;; JMurmel> :h                  ... will print REPL command help


;;; == Introduction ===================
;;;
;;; "Hello, World!" program:

(write "Hello, World!")

;;; the program text above when run in the REPL should print the famous
;;; "Hello, World!"
;;; followed by the result
;;; ==> t
;;; and the prompt "JMurmel>"


;;; == Disclaimer =====================
;;;
;;; In order to understand and make use of this Reference Manual
;;; you should probably at least know some Lisp.
;;; This manual does not attempt to be a Lisp or Murmel tutorial.
;;;


;;; == Terminology ====================
;;;
;;; = Murmel vs. JMurmel =
;;; Murmel is a programming language and JMurmel is program
;;; that consists of I/O functions and a Murmel interpreter.
;;;
;;; = S-expressions vs. forms =
;;; Murmel is a Lisp dialect. As such the language isn't
;;; really defined in terms of program text but in terms
;;; of in-memory objects (lists, symbols and other atoms)
;;; that are acceptable to eval.
;;;
;;; That said, JMurmel's default reader turns S-expressions
;;; from the input stream into equivalent in-memory objects. So
;;; for this reference we'll use S-expressions to describe
;;; programs that are valid Murmel, i.e. are acceptable to eval.
;;;
;;; In this reference in-memory objects that are valid Murmel
;;; (as well as their textual representation as S-expressions)
;;; are referred to as "forms".
;;;
;;; = Surface representation vs. internal representation =
;;; This is really the same discussion as "S-expressions vs. forms".
;;; JMurmel adds S-Expressions as a surface representation
;;; to Murmel.
;;;


;;; == S-expressions ==================

;;; The following are S-expressions that JMurmel's reader
;;; will accept and transform into in-memory objects.
;;; Valid S-expressions may or may not be "forms" (eval w/o error),
;;; see "Terminology" for a discussion of form vs. S-expression.

; atoms that are not symbols
1
1.0
"a string"

'(

; atoms that are symbols
a-symbol
|a symbol|            ; |a symbol|
a\ symbol             ; a\ symbol

)

; a single quote is a shorthand for (quote an-expression)
'an-expression

; a dotted pair
'(a . b)              ;(a . b)

; a dotted list
'(a . (b . (c . d)))  ;(a . (b . (c . d)))

; shorthand for dotted list   ==> (a b c . d)
'(a b c . d)          ;(a b c . d)

; a proper list       ==> (a b c)
'(a . (b . (c . ()))) ;(a . (b . (c . ())))

; shorthand for a proper list ==> (a b c)
'(a b c)              ;(a b c)

; backquote starts "fill-in templates":
; Backquote, comma and comma-at work similar to CL,
; except: currently nested backquotes are not supported,
; comma-dot is also not supported.
(define a 'a-val) (define c 'c-val) (define d '(d-val1 d-val2))
`((,a b) ,c ,@d)      ; ==> ((a-val b) c-val d-val1 d-val2)

(define x '(1 2 3))
`(normal= ,x splicing= ,@x see?) ; ==> (normal= (1 2 3) splicing= 1 2 3 see?)

`(normal= ,x fakesplicing= . ,x) ; ==> (normal= (1 2 3) fakesplicing= 1 2 3)


;;; == Predefined Symbols =============

; "nil" and "t" are pre-defined self-evaluating symbols
nil
t

; "dynamic" is a self-evaluating symbol that may be used
; in the lambda form, see below
dynamic

; Resolution of the time related functions, see below.
internal-time-units-per-second


;;; == Basic Special Forms ============

;;; (quote symbol) -> symbol
; quote returns an expression w/o evaluating it
(quote a-symbol)

;;; (lambda (params...) forms...) -> closure
; When a lambda is created by the special form "lambda"
; the lexical environment is captured at the time of lambda creation.
;
; Arguments to the special form "lambda" are not evaluated.
(lambda (p1 p2) p1)

; lambda with varargs:
; If paramlist is a symbol then all arguments will be
; packed into a list and bound to the symbol.
; If paramlist is a dotted list then remaining arguments
; will be bound to the last parameter.
(lambda popt (write popt)) ; no mandatory arguments
(lambda (p1 p2 . prest) (write prest)) ; two mandatory arguments


;;; == Data types =====================
;;;
;;; Murmel supports symbols, lists as well as other atoms
;;; that are not symbols.
;;;
;;; These other atoms are double precision floating point numbers,
;;; 64bit integer numbers and strings. Custom primitives
;;; may support additional atoms.

; A symbol. Murmel treats symbols case-insensitive.
; Symbol names are of arbitrary length, however only the
; first 30 chars are significant.
;
; Implementation note: JMurmel preserves the
; capitalization of the first encounter of a symbol
; for printing, e.g.:
; '(AbC . dEf) -> (AbC . dEf)
; but
; '(AbC . abc) -> (AbC . AbC)

'*a-sample-symbol*
'a\ symbol\ with\ spaces!

; empty list, printed as "nil"
()

; shorthand for empty list
nil

; an integer number
; tokens that consist of a sign or digit followed by digits
; are interpreted as 64bit integer numbers (java.lang.Long)
1

; a number in double precision
; numbers that contain the characters '.eE' are interpreted
; as double precision (java.lang.Double)
1.

; a number in scientific notation
1e3

; strings literals are max length 2000 chars
"a string literal"
"another 'literal' \"string literal\""


;;; == NIL and T ======================

; Murmel treats the symbols NIL and T the same way
; as Mr. Moon specified them in a Memo (see "The Evolution
; of Lisp pp 62):
;
; "NIL is a symbol, the empty list, and the distinguished
; "false" value. SYMBOLP, ATOM, and LISTP are true of it;
; CONSP is not. CAR, CDR, and EVAL of NIL are NIL.
; NIL may not be used as a function, nor as a variable."
;
; "T is a symbol and the default "true" value used by predicates that
; are not semi-predicates (i.e., that don’t return "meaningful" values
; when they are true.) EVAL of T is T. T may not be used as a variable.
; T is a keyword recognized by certain functions, such as FORMAT."


;;; == Reserved words =================

; In addition to NIL and T some symbols are reserved, i.e.
; may not be used as a function nor as a variable:
;
; nil, t,
; lambda, quote, cond, labels, if, define, defun, let, let*, letrec,
; apply, progn


;;; == Variables and Scope ============

; Symbols are bound to global variables using define or defun
; (see below), and to local variables using let, let*, letrec or
; lambda parameter lists.
;
; Murmel's global bindings are dynamic, i.e. a symbol is bound to
; a newly created variable when define or defun are actually executed.
; The symbol's binding as well as the variable's extent (lifetime)
; last to the end of the program (the symbol's binding may be
; temporarily replaced by a local binding, though).
;
; Murmel's local bindings are lexical, i.e. a symbol is bound to
; a newly created variable when a let/let*/letrec/lambda form
; is executed. The symbol's binding as well as the associated variable
; are removed when leaving the lexical scope of the let/let*/letrec/lambda
; form, restoring any previously existing binding (which may have
; been local or global).


;;; == Additional Special Forms =======

;;; (define symbol object) -> symbol
; define binds symbols in the global environment with
; memory locations that hold values.
; Murmel's define is somewhat similar to Common Lisp's defvar
; except:
; * CL's defvar creates special global variables while
;   Murmel's define creates global variables that can be
;   lexically hidden by e.g. a let-binding.
; * Redefining already defined symbols is an error in Murmel.
; The first argument is not evaluated, the second is
(define *global-var* 42)
(define f1 (lambda (p1 p2) (+ p1 p2)))

;;; (defun symbol (params...) forms...) -> symbol
; defun is a shorthand for defining functions
; (defun symbol (params...) forms...)
;    <=>
; (define symbol (lambda (params...) forms...))
; arguments to defun are not evaluated
(defun f2 (p1 p2) (+ p1 p2))

;;; (defmacro (params...) forms...) -> symbol
; Defines a macro, similar to CL's defmacro.
; Macros are somewhat similar to functions:
; On a function application the functions's arguments
; are eval'd and the result of the function will be used as is.
; On a macro application the macro's arguments are
; NOT eval'd, but the result of the macro is.
; IOW a function produces a value, a macro application
; produces code that will be eval'd.
(defmacro twice (arg) (list '* arg 2))  ; ==> twice
(twice 3) ; ==> 6.0

;;; (if condform form optionalform) -> object

;;; (progn expr...) -> object
(if t (progn (write 'abc) (write 'def)))

;;; (cond (condform forms...)... ) -> object

;;; (labels ((symbol (params...) forms...)...) forms...) -> object

;;; (let optsymbol? ((symbol bindingform)...) bodyforms...) -> object
; Works like you would expect from "let" with the addition
; of Scheme's "named let".
; The let-bound variables "symbol" as well as "optsymbol"
; - if given - are bound inside bodyforms.
; "optsymbol" will be bound inside "bodyforms" to a lambda
; whose parameters are the let-variables and whose code is
; "bodyforms". Therefore "optsymbol" can be used for
; recursive calls within "bodyforms".
(let loop ((x 3)
           (msg "hi"))
  (if (= x 0)
      (write msg)
    (progn (write (floor x)) (loop (- x 1) msg))))

;;; (let* optsymbol? ((symbol bindingform)...) bodyforms...) -> object
; Works like let (see above) with the addition:
; each bindingform "sees" the previous symbols. If multiple
; let-bindings use the same symbol the last one hides
; preceeding ones.
(let* loop ((y 10)
            (x (+ y 20))
            (x (floor (/ x 10)))
            (msg 'hi))
  (if (= x 0)
      (write msg)
    (progn (write (floor x)) (loop 0 0 (- x 1) msg))))

;;; (letrec ((symbol bindingform)...) bodyforms...) -> object
; works like let and let* except each bindingform "sees"
; all other let symbols as well as it's own symbol.
; All symbols are bound, but only the preceeding bindings
; are defined (have a value) while eval'ing the bindingform.
; That way a let-bound variable could be a recursive lambda.
(letrec ((x 1) (y (+ x 1))) (write y))

;;; (apply form argform) -> object
; form must return a primitive or lambda
; argform must eval to a proper list
; e.g. apply the function + to the arguments 1 and 2
(apply + '(1 2))

;;; function call
; applies the operator returned by operatorform to
; the eval'd operands
; (operatorform operands...)


;;; == Predefined Primitives ==========

; (cons 'a 'b) ==> (a . b)
(cons 'a 'b)

; (car '(a b c)) ==> a
(car '(a b c))
(car "abc") ; ==> 'a'

; (cdr '(a b c)) ==> (b c)
(cdr '(a b c))
(cdr "abc") ; ==> "bc"

;;; (eval form) -> object
;;; (eval form env) -> object
; "form" will be eval'd, it must return a form.
; The optional argument "env" will be eval'd, it must return a list of (symbol . value).
; If the optional argument "env" is omitted or nil
; then the environment for the recursive eval is "all predefined global symbols"
; else it is the concatenation of "env" and all predefined globals
(eval '(+ 1 2)) ; ==> 3.0
(eval '(+ x y) (list '(x . 2) '(y . 3))) ; ==> 5.0
(eval '(+ x y) (list (cons 'x 2) (cons 'y 3))) ; ==> 5.0

; eq, null, atom, consp, listp, symbolp, numberp, stringp, characterp,

; assoc takes a key and a list of key/value tupels (lists or conses)
(assoc 'a-key '((key-1 1) (key-2 2) (a-key 3) (key-4 4)))
(cdr (assoc 'a-key '((key-1 . 1) (key-2 . 2) (a-key . 3) (key-4 . 4))))

; append nondestructively append it's arguments. All arguments expcept the last
; are shallow copied, all arguments except the last must be lists.
(append)                    ; ==> nil
(append 'a)                 ; ==> a
(append '(a b) 'c)          ; ==> (a b . c)
(append '(a b) '(c d))      ; ==> (a b c d)
(append '(a . b) '(c d))    ; ==> (a b c d)
(append '(a . b) '(c . d))  ; ==> (a b c . d)

; +, -, *, /, mod, sqrt, log, log10, exp, expt
; The math operators accept numbers only, log only takes 1 argument,
; but otherwise should work as expected.
; All numeric operators return a double.
; eg. (+ number number) -> double
(+ 1 1)

; round, floor, ceiling
; These operators return an integer (java.lang.Long)
; eg. (floor number) -> integer
(floor 1.)

; = < > <= >=
(= 1 1.0)

; (macroexpand-1 quoted-form)
; macroexpand-1 is a simplified version of CL's macroexpand-1.
; It is only supported in interpreted code.
; If the operator of the list "quoted-form" is a macroname then
; the macrocall will be expanded, e.g.:
(defmacro add2 (a) `(+ ,a 2))  ; ==> add2
(macroexpand-1 '(add2 3))      ; ==> (+ 3 2)

; Both expressions as well as data are read from stdin.
; The following expression reads the expression immediately following it
; (in this case the expression to be read is the string "Hello!").
(write (read)) "Hello!"

; writeln and lnwrite accept one optional argument
; writeln will write the argument if given and non-nil followed by a newline
; lnwrite will write a newline followed by the argument if given and non-nil
; followed by a ' ', i.e. writeln is C-style, lnwrite is Lisp-style.
(writeln "Hello, ")
(writeln)
(writeln "World!")

; Walltime in internal time units, relative to an arbitrary time base
(get-internal-real-time)

; User cpu time in internal time units
(get-internal-run-time)

; User + system cpu time in internal time units
(get-internal-cpu-time)

; Pause execution for x internal time units, returns actually slept
; wall time in internal time units.
; This example code will pause execution for approx. 1 second.
(sleep (* 1 internal-time-units-per-second))

; get-universal-time <no arguments> => seconds since 1.1.1900 00:00:00 UTC
; This example code will return approx. years since 1.1.1900
(/ (get-universal-time) 60 60 24 365)

; get-decoded-time <no arguments> => second, minute, hour, date, month, year, day, daylight-p, zone
: NOTE: In Common Lisp zone is given as a a rational multiple of 1/3600 of hours
        offset from Greenwich Mean Time.
        In Murmel zone is given as a double, e.g. Vienna in winter is -1.0.
        The result type of Murmel's (get-decoded-time) is a list
        while CL's returns an ordered sequence.
(get-decoded-time)

; format t writes a formatted string to stdout and returns nil.
; format's parameters work as java.lang.String.format().
(format t "a string: %s, a number: %g, a newline:%n" "The String" 3.14)

; format-locale works similar to format except it has an additional
; first string parameter that should be a locale, nil means use Java's
; default locale.
(format-locale t
   "de-DE" "a string: %s, a number: %g, a newline:%n" "The String" 3.14)

; format nil and format-locale nil work similar
; to format and format-locale except they don't write to stdout
; but return the string
(format-locale nil
   "de-DE" "a string: %s, a number: %g, a newline:%n" "The String" 3.14)

;;; --- End of Murmel reference ---


;;; == Extensions =====================

; JMurmel adds some extra features to Murmel which are listed below.

; lambda dynamic - only supported in the interpreter:
;
; When the optional keyword "dynamic" is given then
; no environment is captured, and lambdas - when applied -
; get the dynamic environment.
; (lambda dynamic (params...) forms...) -> anonymous function with
;                                          dynamic environment

; In embedded use primitives may be added, also Java methods
; created by the primitive :: (see below) act as builtins.
; As far as the language is concerned, all primitives are variadic functions.
; The primitives themselves may have parameter checks, tough.
; In case you call them with the wrong type(s) or number of parameters
; the primitives may throw an error.

; JMurmel supports commandline parameters that can be used to
; disable many of Murmel's forms, predefined variables, ... .
; These commandline parameters can be used if you want to play
; with an even more reduced Lisp.
; See 'jmurmel --help-features'


;;; == Additional JMurmel special forms and primitives ==========

; (trace function-name*) -> trace-result
; (untrace function-name*) -> untrace-result
; Arguments to trace/ untrace are eval'd.
; In interpreted code these work similar to CL's trace/ untrace macros,
; see http://clhs.lisp.se/Body/m_tracec.htm.
; Only interpreted code will be traced (user code as well as
; interpreter primities).
(trace 'write '+)

; (:: classname methodname paramclass...) -> primitive
; The primitive "::" will return a newly created primitive
; that is implemented by the method "methodname" of the Java class
; "classname" that has the formal parameters "paramclass...".
; Parameters to "::" must be strings.
(:: "java.lang.System" "currentTimeMillis")

; When invoking primitives created by "::" the first argument must be
; a Java object of the primitive's method's class or nil for static methods:
; invoke static method:
(define ctm (:: "java.lang.System" "currentTimeMillis"))
(ctm nil)

; invoke method on an object
(define my-hash ((:: "java.util.HashMap" "new")))
(write ((:: "java.util.HashMap" "toString") my-hash))


;;; == Known issues ===================
;
; Murmel language:
; - at least globals should be mutable 
; - globals should be special (dynamic)
; - support for packages should be added
;
; Compiler issues:
; - define/ defun only work as top level forms, use as non-toplevel form
;   will throw a "not-yet-implemented" error.
; - support for macros should be added
;
; The todo list for features is way too long.


;;; == Copyright ======================
;;;
;;; Murmel and JMurmel are Copyright (C) 2020 Robert Mayer.
;;; All rights reserved.
;;;
;;; This work is licensed under the terms of the MIT license.
;;; For a copy, see https://opensource.org/licenses/MIT.

;;; At the end of the input file JMurmel will print "bye." and exit.

;;; $Id: murmel-langref.lisp,v 1.65 2021/01/25 19:49:53 Robert Exp $