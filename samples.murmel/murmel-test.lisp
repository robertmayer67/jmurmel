;;;; Tests for core Murmel

;;; This file is valid Common Lisp as well as Murmel
;;; (doesn't need mlib). Some #+/#- feature expressions
;;; are needed, tough.
;;;
;;; It can be run with e.g. sbcl or abcl to test the tests
;;; and after that with jmurmel to test jmurmel.
;;;
;;; Usage:
;;;
;;;     sbcl --script murmel-test.lisp
;;;     abcl --batch --load murmel-test.lisp
;;;
;;;     java -jar jmurmel.jar murmel-test.lisp
;;;
;;; or using the compiler:
;;;
;;;     java -jar jmurmel.jar --run murmel-test.lisp
;;;

#-murmel (defun writeln () (terpri))
#-murmel (defmacro define (n v) `(defparameter ,n ,v))
#-murmel (defun assq (key alist) (assoc key alist :test #'eq))


;;; Test "framework":
;;;
;;; - Global variables to hold test count and failure count.
;;; - The macro "deftest" to define test-name, test-form and expected result.

(define *failed* 0)
(define *count* 0)

(defun inc-failed ()
  (setq *failed* (1+ *failed*)))

(defun inc-count ()
  (setq *count* (1+ *count*)))

(defun tequal (a b)
  (if (eql a b)
        t
    (if (stringp a)
          (if (stringp b)
                (string= a b)
            nil)
      (if (consp a)
            (if (consp b)
                  (if (tequal (car a) (car b))
                        (tequal (cdr a) (cdr b))
                    nil)
              nil)
        nil))))


(defmacro deftest (name form expected-result)
  (let ((result (gensym)))
    `(let ((,result ,form))
       (inc-count)
       #-murmel
       (if (equal ,result ,expected-result) nil
         (progn (inc-failed) (write ',name) (format t " equal test failed") (writeln)))
       (if (tequal ,result ,expected-result) nil
         (progn (inc-failed) (write ',name) (format t " tequal test failed") (writeln))))))



;;; Test the test-framework

(deftest tequal.1 0 0)
(deftest tequal.2 1 1)
(deftest tequal.3 -1 -1)

(deftest tequal.4 0.0 0.0)
(deftest tequal.5 -0.0 -0.0)
(deftest tequal.6 3.4 3.4)

(deftest tequal.7 nil  nil)
(deftest tequal.8 '(a)  '(a))
(deftest tequal.9 '(a (b))  '(a (b)))
(deftest tequal.10 (tequal '(a (b)) '(a (c)))  nil)


;;; Tests for core Murmel w/o mlib

;;; basic special forms: quote, lambda

;;; test lambda
(deftest lambda.1 (#-murmel funcall (lambda nil)) nil)


;;; Additional special forms: define, defun, defmacro, setq, let, if, progn, cond, labels, apply, load, require, provide
;;; todo cond, labels, apply, load, require, provide

;;; test define
(define *a* nil)
(define *b* nil)
(define *c* nil)


;;; test setq
(deftest setq.global   (setq *a* 1) 1)
(deftest setq.global.2 (setq *a* 11 *b* 22 *c* 33) 33)
(deftest setq.param    (#-murmel funcall (lambda (a) (setq a 3)) 1) 3)
(deftest setq.local    (let ((a 1)) (setq a 3)) 3)


;;; test letXX
; no bindings
(deftest let.1 (let () (1+ 1)) 2)
(deftest let.2 (let* () (1+ 2)) 3)
#+murmel (deftest let.3 (letrec () (1+ 3)) 4)

(deftest let.4 (let (a) (list a)) '(nil))
(deftest let.5 (let* (a) (list a)) '(nil))
#+murmel (deftest let.6 (letrec (a) (list a)) '(nil))

(deftest let.4 (let ((a 1) b) (list b a)) '(nil 1))
(deftest let.5 (let* ((a 1) b) (list b a)) '(nil 1))
#+murmel (deftest let.6 (letrec ((a 1) b) (list b a)) '(nil 1))


;;; test named letXX
#+murmel (deftest namedlet.1 (let loop () (if nil (loop)) (1+ 1)) 2)
#+murmel (deftest namedlet.2 (let* loop () (if nil (loop)) (1+ 1)) 2)
#+murmel (deftest namedlet.3 (letrec loop () (if nil (loop)) (1+ 1)) 2)


(setq *a* 1 *b* 2 *c* 3)
(defun globals-as-list ()
  (list *a* *b* *c*)) 

;;; test let dynamic
(deftest letdynamic.1
  (append (let #+murmel dynamic ((*a* 123) (*b* *a*) (*c* (1+ *c*))) (globals-as-list))
          (list *a* *b* *c*))
  '(123 1 4 1 2 3))

; changes to globals in a let dynamic form will be undone
(deftest letdynamic.2
  (append (let #+murmel dynamic ((*a* 123) (*b* *a*) (*c* (1+ *c*)))
            (append (globals-as-list)
                    (setq *a* 1111 *b* 2222 *c* nil)))
          (list *a* *b* *c*))
  '(123 1 4 1 2 3))


;;; test let* dynamic
(deftest let*dynamic.1
  (append (let* #+murmel dynamic ((*a* 123) (*b* 456) (*c* 789)) (globals-as-list))
          (list *a* *b* *c*))
  '(123 456 789 1 2 3))

(deftest let*dynamic.2
  (append (let* #+murmel dynamic ((*a* 123) (*a* 456) (*a* 789)) (globals-as-list))
            (list *a* *b* *c*))
    '(789 2 3 1 2 3))

(deftest let*dynamic.3
  (append (let* #+murmel dynamic ((*a* 123) (*a* 456) (*b* *a*)) (globals-as-list))
            (list *a* *b* *c*))
    '(456 456 3 1 2 3))

(deftest if-number.1
  (if 1 'yes)  'yes)

(deftest if-number.2
  (if 1.0 'yes)  'yes)

(deftest if-char.1
  (if #\1 'yes)  'yes)


;;; let over lambda
#+murmel
(progn
  (define f (let ((ctr 0)) (lambda () (setq ctr (1+ ctr)))))
  (deftest closure.1 (list (f) (f) (f)) '(1 2 3))
)


;;; Primitives
;;; todo remaining primitives

;;; test append
(deftest append.1 (append)                   nil)
(deftest append.2 (append nil)               nil)
(deftest append.3 (append nil '(1 2 3))      '(1 2 3))
(deftest append.4 (append nil '(1 2 3) nil)  '(1 2 3))
(deftest append.5 (append nil '(1 2 3) nil '(4 5 6))  '(1 2 3 4 5 6))
(deftest append.6 (append nil '(1 2 3) nil '(4 5 6))  '(1 2 3 4 5 6))


;;; test eql
(deftest eql.1 (eql 'a 'b)  nil)
(deftest eql.2 (eql 'a 'a)  t)
(deftest eql.3 (eql 3 3)  t)
(deftest eql.4 (eql 3 3.0)  nil)
(deftest eql.5 (eql 3.0 3.0)  t)
;(deftest eql.6 (eql #c(3 -4) #c(3 -4))  t)
;(deftest eql.7 (eql #c(3 -4.0) #c(3 -4))  nil)
(deftest eql.8 (eql (cons 'a 'b) (cons 'a 'c))  nil)
(deftest eql.9 (eql (cons 'a 'b) (cons 'a 'b))  nil)
(deftest eql.10 (eql '(a . b) '(a . b))  nil) ; SBCL: in the repl this is nil, when compiled this is t
(define x nil)
(deftest eql.11 (progn (setq x (cons 'a 'b)) (eql x x))  t)
(deftest eql.12 (progn (setq x '(a . b)) (eql x x))  t)
(deftest eql.13 (eql #\A #\A)  t)
#+murmel (deftest eql.14 (eql "Foo" "Foo")  t) ; sbcl murmel-test.lisp -> nil, sbcl murmel-test.fasl -> t
;(deftest eql.15 (eql "Foo" (copy-seq "Foo"))  nil)
(deftest eql.16 (eql "FOO" "foo")  nil)

(deftest eql.17 (eql -0 -0) t)
(deftest eql.18 (eql -0 0) t)
(deftest eql.18 (eql -0.0 -0) nil)

(deftest eql.17 (eql -0.0 -0.0) t)
(deftest eql.18 (eql -0.0 0.0) nil)


;;; test assq
(deftest assq.1 (assq 'a-key '((key-1 1) (key-2 2) (a-key 3) (key-4 4)))  '(a-key 3))
(deftest assq.2 (assq nil '((key-1 1) nil (nil 2) (a-key 3) (key-4 4)))   '(nil 2))


;;; test assoc
(deftest assoc.1 (assoc 'a-key '((key-1 1) (key-2 2) (a-key 3) (key-4 4)))  '(a-key 3))
(deftest assoc.2 (assoc nil '((key-1 1) nil (nil 2) (a-key 3) (key-4 4)))   '(nil 2))


;;; test number comparison operators
(deftest test-numbereq.1  (= 2 2)       t)
(deftest test-numbereq.2  (= 2 3)       nil)
(deftest test-numbereq.3  (= 1e20 1e20) t)

(deftest test-numbereq.4 (= -0 -0)     t)
(deftest test-numbereq.5 (= -0 0)      t)
(deftest test-numbereq.6 (= -0.0 -0)   t)

(deftest test-numbereq.7 (= -0.0 -0.0) t)
(deftest test-numbereq.8 (= -0.0 0.0)  t)

(deftest test-numbereq.9  (= 1 1 1 1 1)  t)
(deftest test-numbereq.10 (= 1 1 1 1 2)  nil)
(deftest test-numbereq.11 (= 1 1.0 1e0)  t)
(deftest test-numbereq.12 (= 1 1.0 1e1)  nil)

(deftest test-numbereq.13 (= 1)  t)
(deftest test-numbereq.14 (= -0.0)  t)

(deftest test-ne.1  (/= 1 2 3)  t)
(deftest test-ne.2  (/= 1 2 2)  nil)
(deftest test-ne.2  (/= 1 2 2.0)  nil)


;;; test +
(deftest test-add-minus-zero (+ -0.0 -0.0)  -0.0)


;;; test mod, rem
(deftest test-mod-rem
  (list (mod -3.0 -2) (rem -3 -2.0) (mod 3.0 -2) (rem 3 -2.0))
    '(-1.0 -1.0 -1.0 1.0))


;;; Murmel-only tests for various not-a-numbers.
;;; In Common division by zero is signalled as a condition.
#+murmel
(let ((nan (/ 0 0))     ; NaN, not-a-number
      (ninf (/ -1 0))   ; -Infinity, negative infinity
      (pinf (/ 1 0)))   ; Infinity, positive infinity

  (deftest inf.lt (< ninf -1.0 0.0 pinf) t)

  (deftest inf.add1  (+ ninf ninf) ninf)
  (deftest inf.add2  (+ ninf -1.0) ninf)
  (deftest inf.add3  (+ ninf  0.0) ninf)
  (deftest inf.add4  (+ ninf  1.0) ninf)
  (deftest inf.add5  (+ ninf pinf)  nan)
  (deftest inf.add6  (+ ninf  nan)  nan)

  (deftest inf.add7  (+ pinf ninf)  nan)
  (deftest inf.add8  (+ pinf -1.0) pinf)
  (deftest inf.add9  (+ pinf  0.0) pinf)
  (deftest inf.add10 (+ pinf  1.0) pinf)
  (deftest inf.add11 (+ pinf pinf) pinf)
  (deftest inf.add11 (+ pinf  nan)  nan)

  (deftest inf.sub1  (- ninf ninf)  nan)
  (deftest inf.sub2  (- ninf -1.0) ninf)
  (deftest inf.sub3  (- ninf  0.0) ninf)
  (deftest inf.sub4  (- ninf  1.0) ninf)
  (deftest inf.sub5  (- ninf pinf) ninf)
  (deftest inf.sub6  (- ninf  nan)  nan)

  (deftest inf.sub7  (- pinf ninf) pinf)
  (deftest inf.sub8  (- pinf -1.0) pinf)
  (deftest inf.sub9  (- pinf  0.0) pinf)
  (deftest inf.sub10 (- pinf  1.0) pinf)
  (deftest inf.sub11 (- pinf pinf)  nan)
  (deftest inf.sub12 (- pinf  nan)  nan)

  (deftest nan.1 (= nan nan) nil)
  (deftest nan.2 (< nan nan) nil)
  (deftest nan.3 (> nan nan) nil)
  (deftest nan.4 (/= nan nan) t)
)


;;; Print summary
(write *failed*) (format t "/") (write *count*) (format t " test(s) failed")
(writeln)
(if (= 0 *failed*)
      (format t "Success.")
  (format t "Failure."))

#+murmel (if (> *failed* 0) (fatal (format nil "%n%d/%d errors" *failed* *count*)))