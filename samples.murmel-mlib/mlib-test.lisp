;;;; Tests for Murmel's default library "mlib".

;;; This file is valid Common Lisp as well as Murmel
;;; with mlib.lisp. Some #+/#- feature expressions
;;; are needed, tough, and some tests e.g. for threading
;;; macros are murmel-only.
;;;
;;; It can be run with e.g. sbcl or abcl to test the tests
;;; and after that with jmurmel to test mlib/jmurmel.
;;;
;;; Usage:
;;;
;;;     sbcl --script mlib-test.lisp
;;;     abcl --batch --load mlib-test.lisp
;;;
;;;     java -jar jmurmel.jar mlib-test.lisp
;;;
;;; Notes:
;;;
;;; - contains some occurrences of #'. These are needed
;;;   for CL compatibility, #' is ignored by murmel.
;;; - may contain some mutation of quoted forms which will break some tests
;;;   when compiling with SBCL (and mutating quoted forms i.e. constants
;;;   is bad style...), I think I fixed all, though.

#+murmel (require "mlib")


#-murmel (progn

(defmacro define (n v) `(defparameter ,n ,v))

(defun writeln (&optional (o nil) (escape t))
  (when o (funcall (if escape #'print #'princ) o))
  (terpri)
  o)

(defmacro sref (str idx) `(aref ,str ,idx))

(defmacro try (form &optional errorobj)
  (let ((ex (gensym)))
    `(handler-case ,form
                   (condition (,ex) (values ,errorobj ,ex)))))

(defun circular-list (&rest elements)
  (let ((cycle (copy-list elements)))
    (nconc cycle cycle)))
)


(define *success-count* 0)
(define *error-count* 0)


;;; Macro to check whether "form" eval's to "expected".
;;; Comparison is done using "equal".
(defmacro assert-equal (expected form . msg)
  `(do-assert-equal
     ,expected
     ,form
     ,(if (car msg)
          (car msg)
          (append (list 'equal) (list expected) (list form)))))

; helper function for assert-equal macro
(defun do-assert-equal (expected actual msg)
  (setq *success-count* (1+ *success-count*))
  (unless (equal expected actual)
    (writeln)
    (format t "assert-equal failed: ") (writeln msg)
    (format t "expected: ") (writeln expected t)
    (format t "actual:   ") (writeln actual t)
    (setq *error-count* (1+ *error-count*))
    nil))


;;; Macro to run some tests
;;;
;;; The format is so that examples form the CLHS can be copy&pasted.
;;; `expected-result`s will not be evaluated.
;;;
;;; Usage:
;;;     (tests test-name
;;;       form1 => expected-result1
;;;       form2 => expected-result2
;;;       ...)
(defmacro tests (name . l)
  (when l
    `(append (assert-equal ',(caddr l) ,(car l) ',name)
             (tests ,name ,@(cdddr l)))))


;;; Macro to run one test
;;;
;;; Modeled after https://github.com/pfdietz/ansi-test.
;;; `expected-result` will not be evaluated.
;;;
;;; Usage:
;;;     (deftest test-name
;;;       form1 expected-result)
(defmacro deftest (name form expected-result)
  `(append (assert-equal ',(caddr l) ,(cadr l))))


;;; Macro to check if given condition is thrown
;;;
;;; Modeled after https://github.com/pfdietz/ansi-test.
;;;
;;; Usage:
;;;     (tests test-name
;;;       (signals-error (/) program-error) => t
;;;       (signals-error (read-from-string "") end-of-file) => t
;;;       ...)
;;;
(defmacro signals-error (form cnd)
  (let ((v (gensym))
        (e (gensym)))
    `(multiple-value-bind (,v ,e) (try ,form) (typep ,e ',cnd))))



;;; Begin of the actual tests. Tests mostly follow the order of the TOC given in mlib.lisp.

;;; tests for CL inspired functions and macros

;;; - logic, program structure

;; test not
(tests not
  (not nil) => t
  (not '()) => t
  (not (integerp 'sss)) => t
  (not (integerp 1)) => nil
  (not 3.7) => nil
  (not 'apple) => nil
)


;; test logical and/ or macros
(tests and
  (and (= 1 1)
       (or (< 1 2)
           (> 1 2))
       (and (<= 1 2 3 4)
            (> 5 3 1))) => t
)

(defmacro inc-var (var) `(setq ,var (1+ ,var)))
(defmacro dec-var (var) `(setq ,var (1- ,var)))
(define temp0 nil) (define temp1 1) (define temp2 1) (define temp3 1)

(tests and.2
  (and (inc-var temp1) (inc-var temp2) (inc-var temp3)) => 2
  (and (eql 2 temp1) (eql 2 temp2) (eql 2 temp3)) => t
  (dec-var temp3) => 1
  (and (dec-var temp1) (dec-var temp2) (eq temp3 'nil) (dec-var temp3)) => nil
  (and (eql temp1 temp2) (eql temp2 temp3)) => t
  (and) => t
)


(tests or
  (or) => nil
  (setq temp0 nil temp1 10 temp2 20 temp3 30) => 30
  (or temp0 temp1 (setq temp2 37)) => 10
  temp2 => 20
  (or (inc-var temp1) (inc-var temp2) (inc-var temp3)) => 11
  temp1 => 11
  temp2 => 20
  temp3 => 30
  (or (values) temp1) => 11
  (or (values temp1 temp2) temp3) => 11
  (multiple-value-list (or temp0 (values temp1 temp2))) => (11 20)
  (multiple-value-list (or (values temp0 temp1) (values temp2 temp3))) => (20 30)
)


;; test prog1, prog2
(define temp 1) ; =>  temp
(tests prog
  (prog1 temp (print temp) (incf temp) (print temp))
  ; >>  1
  ; >>  2
  =>  1
  (prog1 temp (setq temp nil)) =>  2
  temp =>  NIL
  (prog1 (values 1 2 3) 4) =>  1
  (setq temp (list 'a 'b 'c)) => (a b c)
  (prog1 (car temp) (setf (car temp) 'alpha)) =>  A
  temp =>  (ALPHA B C)
  ;(flet ((swap-symbol-values (x y)
  ;         (setf (symbol-value x)
  ;               (prog1 (symbol-value y)
  ;                      (setf (symbol-value y) (symbol-value x))))))
  ;  (let ((*foo* 1) (*bar* 2))
  ;    (declare (special *foo* *bar*))
  ;    (swap-symbol-values '*foo* '*bar*)
  ;    (values *foo* *bar*)))
  ;=>  2, 1
  (setq temp 1) =>  1
  (prog2 (incf temp) (incf temp) (incf temp)) =>  3
  temp =>  4
  (prog2 1 (values 2 3 4) 5) =>  2
)


;; test when, unless
(tests when-unless
  (when t 'hello) => hello
  (unless t 'hello) => nil
  (when nil 'hello) => nil
  (unless nil 'hello) => hello
  (when t) => nil
  (unless nil) => nil
  (when t (prin1 1) (prin1 2) (prin1 3)) => 3 ; >>  123, => 3
  (unless t (prin1 1) (prin1 2) (prin1 3)) => nil
  (when nil (prin1 1) (prin1 2) (prin1 3)) => nil
  (unless nil (prin1 1) (prin1 2) (prin1 3)) => 3 ; >>  123, => 3
  (let ((x 3))
    (list (when (oddp x) (inc-var x) (list x))
          (when (oddp x) (inc-var x) (list x))
          (unless (oddp x) (inc-var x) (list x))
          (unless (oddp x) (inc-var x) (list x))
          (if (oddp x) (inc-var x) (list x))
          (if (oddp x) (inc-var x) (list x))
          (if (not (oddp x)) (inc-var x) (list x))
          (if (not (oddp x)) (inc-var x) (list x)))) => ((4) NIL (5) NIL 6 (6) 7 (7))
)


;; test case
(define res nil)

(defun decode (x)
  (case x
    ((i uno) 1.0)
    ((ii dos) 2.0)
    ((iii tres) 3.0)
    ((iv cuatro) 4.0))) ; =>  DECODE

(defun add-em (x) (apply #'+ (mapcar #'decode x))) ; =>  ADD-EM

(tests case
  (dolist (k '(1 2 3 :four #\v () t 'other))
    (setq res (append res (list
       (case k ((1 2) 'clause1)
               (3 'clause2)
               (nil 'no-keys-so-never-seen)
               ((nil) 'nilslot)
               ((:four #\v) 'clause4)
               ((t) 'tslot)
               (t 'others))
       ))))
  =>  NIL
  res => (CLAUSE1 CLAUSE1 CLAUSE2 CLAUSE4 CLAUSE4 NILSLOT TSLOT OTHERS)
  (add-em '(uno iii)) =>  4.0
)



;;; - conses and lists

;; test endp
(tests endp
  (endp nil) =>  t
  (endp '(1 2)) =>  nil
  (endp (cddr '(1 2))) =>  t
)


;; test copy-list
(let (lst slst clst)
  (tests copy-list
    (setq lst (list 1 (list 2 3))) =>  (1 (2 3))
    (setq slst lst) =>  (1 (2 3))
    (setq clst (copy-list lst)) =>  (1 (2 3))
    (eq slst lst) =>  t
    (eq clst lst) =>  nil
    (equal clst lst) =>  t
    (rplaca lst "one") =>  ("one" (2 3))
    slst =>  ("one" (2 3))
    clst =>  (1 (2 3))
    (setf (caadr lst) "two") =>  "two"
    lst =>  ("one" ("two" 3))
    slst =>  ("one" ("two" 3))
    clst =>  (1 ("two" 3))

    (setq lst '(1 2 . 3)) => (1 2 . 3)
    (setq clst (copy-list lst)) => (1 2 . 3)
    (eq lst clst) => nil
))


;; test copy-alist
(define *alist* (acons 1 "one" (acons 2 "two" '())))
(define *list-copy* nil)
(define *alist-copy* nil)
(tests copy-alist
  *alist* =>  ((1 . "one") (2 . "two"))
  (setq *list-copy* (copy-list *alist*)) =>  ((1 . "one") (2 . "two"))
  (setq *alist-copy* (copy-alist *alist*)) =>  ((1 . "one") (2 . "two"))
  (setf (cdr (assoc 2 *alist-copy*)) "deux") =>  "deux"
  *alist-copy* =>  ((1 . "one") (2 . "deux"))
  *alist* =>  ((1 . "one") (2 . "two"))
  (setf (cdr (assoc 1 *list-copy*)) "uno") =>  "uno"
  *list-copy* =>  ((1 . "uno") (2 . "two"))
  *alist* =>  ((1 . "uno") (2 . "two"))
)


;; test copy-tree
(let ((object (list (cons 1 "one")
                    (cons 2 (list 'a 'b 'c))))
      object-too copy-as-list copy-as-alist copy-as-tree)
  (tests copy-tree
    object =>  ((1 . "one") (2 A B C))

    (setq object-too object)                  =>  #1=((1 . "one") (2 A B C))
    (setq copy-as-list (copy-list object))    =>  #1#
    (setq copy-as-alist (copy-alist object))  =>  #1#
    (setq copy-as-tree (copy-tree object))    =>  #1#

    (eq object object-too)      =>  t
    (eq copy-as-tree object)    =>  nil
    (eql copy-as-tree object)   =>  nil
    (equal copy-as-tree object) =>  t

    (setf (car (cdr (cadr object))) "a"
          (car (cadr object)) "two"
          (car object) '(one . 1))            =>  (ONE . 1)

    object        =>  ((ONE . 1) ("two" "a" B C))
    object-too    =>  ((ONE . 1) ("two" "a" B C))
    copy-as-list  =>  ((1 . "one") ("two" "a" B C))
    copy-as-alist =>  ((1 . "one") (2 "a" B C))
    copy-as-tree  =>  ((1 . "one") (2 A B C))
  )
) 
 
 
;; test list-length
(tests list-length
  (list-length '(a b c d)) =>  4
  (list-length '(a (b c) d)) =>  3
  (list-length '()) =>  0
  (list-length nil) =>  0
  (list-length (circular-list 'a 'b)) =>  NIL
  (list-length (circular-list 'a)) =>  NIL
  (list-length (circular-list)) =>  0
)


;; test last
(define x nil)

(tests last
  (last nil) => nil
  (last '(1 2 3)) => (3)
  (last '(1 2 3 4 . 5)) => (4 . 5)

  (setq x (list 'a 'b 'c 'd)) =>  (A B C D)
  (last x) =>  (D)
  (progn (rplacd (last x) (list 'e 'f)) x) =>  (A B C D E F)
  (last x) =>  (F)

  (last '(a b c))   =>  (C)

  (last '(a b c) 0) =>  ()
  (last '(a b c) 1) =>  (C)
  (last '(a b c) 2) =>  (B C)
  (last '(a b c) 3) =>  (A B C)
  (last '(a b c) 4) =>  (A B C)

  (last '(a . b) 0) =>  B
  (last '(a . b) 1) =>  (A . B)
  (last '(a . b) 2) =>  (A . B)

  (apply #'last '((a . b) 0)) =>  B
  (apply #'last '((a . b) 1)) =>  (A . B)
  (apply #'last '((a . b) 2)) =>  (A . B)
)


;; test butlast
(tests butlast
  (butlast (list 1 2 3 4 5))     => (1 2 3 4)
  (butlast (list 1 2 3 4 5) 1)   => (1 2 3 4)
  (butlast (list 1 2 3 4 5) 0)   => (1 2 3 4 5)
  (butlast (list 1 2 3 4 5) 5)   => nil
  (butlast (list 1 2 3 4 5) 20)  => nil
)


;; test nbutlast
(tests nbutlast
  (nbutlast (list 1 2 3 4 5))     => (1 2 3 4)
  (nbutlast (list 1 2 3 4 5) 1)   => (1 2 3 4)
  (nbutlast (list 1 2 3 4 5) 0)   => (1 2 3 4 5)
  (nbutlast (list 1 2 3 4 5) 5)   => nil
  (nbutlast (list 1 2 3 4 5) 20)  => nil
)

(define foo nil)
(define lst nil)
(tests xbutlast
 (setq lst '(1 2 3 4 5 6 7 8 9)) =>  (1 2 3 4 5 6 7 8 9)
 (butlast lst) =>  (1 2 3 4 5 6 7 8)
 (butlast lst 5) =>  (1 2 3 4)
 (butlast lst (+ 5 5)) =>  NIL
 lst =>  (1 2 3 4 5 6 7 8 9)
 (nbutlast lst 3) =>  (1 2 3 4 5 6)
 lst =>  (1 2 3 4 5 6)
 (nbutlast lst 99) =>  NIL
 lst =>  (1 2 3 4 5 6)
 (butlast '(a b c d)) =>  (A B C)
 (butlast '((a b) (c d))) =>  ((A B))
 (butlast '(a)) =>  NIL
 (butlast nil) =>  NIL
 (setq foo (list 'a 'b 'c 'd)) =>  (A B C D)
 (nbutlast foo) =>  (A B C)
 foo =>  (A B C)
 (nbutlast (list 'a)) =>  NIL
 (nbutlast '()) =>  NIL
)


;; test ldiff
(tests ldiff
  (let* ((obj (list  4 5)) (lst (list* 1 2 3 obj))) (list lst obj (ldiff lst obj))) => ((1 2 3 4 5)   (4 5)   (1 2 3))
  (let* ((obj (list* 4 5)) (lst (list* 1 2 3 obj))) (list lst obj (ldiff lst obj))) => ((1 2 3 4 . 5) (4 . 5) (1 2 3))
  (let* ((obj 4)           (lst (list* 1 2 3 obj))) (list lst obj (ldiff lst obj))) => ((1 2 3 . 4)   4       (1 2 3))
)


;; test tailp
(tests tailp
  (let* ((obj (list  4 5)) (lst (list* 1 2 3 obj))) (list lst obj (tailp obj lst))) => ((1 2 3 4 5)   (4 5)   t)
  (let* ((obj (list* 4 5)) (lst (list* 1 2 3 obj))) (list lst obj (tailp obj lst))) => ((1 2 3 4 . 5) (4 . 5) t)
  (let* ((obj 4)           (lst (list* 1 2 3 obj))) (list lst obj (tailp obj lst))) => ((1 2 3 . 4)   4       t)
)


;; test subst
(define tree1 nil)
(tests subst
  (setq tree1 (copy-tree '(1 (1 2) (1 2 3) (1 2 3 4)))) =>  (1 (1 2) (1 2 3) (1 2 3 4))
  (subst "two" 2 tree1) =>  (1 (1 "two") (1 "two" 3) (1 "two" 3 4))
  (subst "five" 5 tree1) =>  (1 (1 2) (1 2 3) (1 2 3 4))
;  (eq tree1 (subst "five" 5 tree1)) =>  implementation-dependent
  (subst 'tempest 'hurricane
         '(shakespeare wrote (the hurricane)))
  =>  (SHAKESPEARE WROTE (THE TEMPEST))
  (subst 'foo 'nil '(shakespeare wrote (twelfth night)))
  =>  (SHAKESPEARE WROTE (TWELFTH NIGHT . FOO) . FOO)
  (subst '(a . cons) '(old . pair)
         '((old . spice) ((old . shoes) old . pair) (old . pair))
         #-murmel :test #'equal)
  =>  ((OLD . SPICE) ((OLD . SHOES) A . CONS) (A . CONS))

  (subst-if 5 #'listp tree1) =>  5
;  (subst-if-not '(x) #'consp tree1)  =>  (1 X)

  tree1 =>  (1 (1 2) (1 2 3) (1 2 3 4))
  (nsubst 'x 3 tree1 #-murmel :test #'eql #-murmel :key #'(lambda (y) (and (listp y) (caddr y))))
  =>  (1 (1 2) X X)
  tree1 =>  (1 (1 2) X X)

  (nsubst-if 'Y (lambda (x) (eql x 'x)) tree1) -> (1 (1 2) Y Y)
)


;; test nconc
(define y nil)
(define bar nil)
(define baz nil)

(tests nconc
  (nconc) =>  NIL
  (setq x (list 'a 'b 'c)) =>  (A B C)
  (setq y '(d e f)) =>  (D E F)
  (nconc x y) =>  (A B C D E F)
  x =>  (A B C D E F)

  (setq foo (list 'a 'b 'c 'd 'e)
        bar (list 'f 'g 'h 'i 'j)
        baz (list 'k 'l 'm)) =>  (K L M)
  (setq foo (nconc foo bar baz)) =>  (A B C D E F G H I J K L M)
  foo =>  (A B C D E F G H I J K L M)
  bar =>  (F G H I J K L M)
  baz =>  (K L M)

  (setq foo (list 'a 'b 'c 'd 'e)
        bar (list 'f 'g 'h 'i 'j)
        baz (list 'k 'l 'm)) =>  (K L M)
  (setq foo (nconc nil foo bar nil baz)) =>  (A B C D E F G H I J K L M)
  foo =>  (A B C D E F G H I J K L M)
  bar =>  (F G H I J K L M)
  baz =>  (K L M)

  (nconc nil (list 1 2 3) nil) => (1 2 3)

  (nconc (list* 1 2 3) (list* 11 22 33)) => (1 2 11 22 . 33)


  (nconc (list* 1 2 3) nil) => (1 2)
  (nconc nil nil nil (list* 1 2 3) (list* 11 22 33) 'a) => (1 2 11 22 . a)
)


;; test revappend, nreconc
(setq x nil)
(tests revappend
 (let ((list-1 (list 1 2 3))
       (list-2 (list 'a 'b 'c)))
   (push (revappend list-1 list-2) x)
   (push list-1 x)
   (push list-2 x)
   x) => ((a b c) (1 2 3) (3 2 1 A B C))

 (revappend '(1 2 3) '()) =>  (3 2 1)
 (revappend '(1 2 3) '(a . b)) =>  (3 2 1 A . B)
 (revappend '() '(a b c)) =>  (A B C)
 (revappend '(1 2 3) 'a) =>  (3 2 1 . A)
 (revappend '() 'a) =>  A   ;degenerate case
)

(setq x nil)
(tests nreconc
 (let ((list-1 (list 1 2 3))
       (list-2 (list 'a 'b 'c)))
   (push (nreconc list-1 list-2) x)
   (push (equal list-1 '(1 2 3)) x)
   (push (equal list-2 '(a b c)) x)
   (reverse x)) => ((3 2 1 A B C) nil t)
)


;; test member
(tests member
  (member 2 '(1 2 3)) => (2 3)
  (member 'e '(a b c d)) => NIL
  (member '(1 . 1) '((a . a) (b . b) (c . c) (1 . 1) (2 . 2) (3 . 3)) #-murmel :test #'equal) => ((1 . 1) (2 . 2) (3 . 3))
  (member 'c '(a b c 1 2 3) #-murmel :test #'eq) => (c 1 2 3)
  (member 'b '(a b c 1 2 3) #-murmel :test (lambda (a b) (eq a b))) => (b c 1 2 3)
)


;; test adjoin
(define slist nil)
(tests adjoin
  (setq slist '()) =>  NIL
  (adjoin 'a slist) =>  (A)
  slist =>  NIL
  (setq slist (adjoin (list 'test-item 1) slist)) =>  ((TEST-ITEM 1))
  (adjoin (list 'test-item 1) slist) =>  ((TEST-ITEM 1) (TEST-ITEM 1))

  ;(adjoin '(test-item 1) slist #-murmel :test 'equal) =>  ((TEST-ITEM 1))   ; CL accepts a symbol as a test, Murmel does not
  (adjoin (list 'test-item 1) slist #-murmel :test #'equal) =>  ((TEST-ITEM 1))

  ;(adjoin '(new-test-item 1) slist :key #'cadr) =>  ((TEST-ITEM 1))         ; CL supports :key, Murmel does not
  (adjoin '(new-test-item 1) slist #-murmel :test (lambda (l r) (eql (cadr l) (cadr r)))) =>  ((TEST-ITEM 1))

  (adjoin (list 'new-test-item 1) slist) =>  ((NEW-TEST-ITEM 1) (TEST-ITEM 1))

  (signals-error (adjoin) program-error) => t
)


;; test acons
(define alist '()) ; => alist
(tests acons
  (acons 1 "one" alist) => ((1 . "one"))
  alist => NIL
  (setq alist (acons 1 "one" (acons 2 "two" alist))) => ((1 . "one") (2 . "two"))
  (assoc 1 alist) => (1 . "one")
  (setq alist (acons 1 "uno" alist)) => ((1 . "uno") (1 . "one") (2 . "two"))
  (assoc 1 alist) => (1 . "uno")
)


;; test mapcar
(tests mapcar
  (mapcar #'car '((1 a) (2 b) (3 c))) => (1 2 3)
  (mapcar #'abs '(3.0 -4.0 2.0 -5.0 -6.0)) => (3.0 4.0 2.0 5.0 6.0)
  (mapcar #'cons '(a b c) '(1 2 3)) => ((A . 1) (B . 2) (C . 3))
)


;; test maplist
(tests maplist
  (maplist #'append '(1 2 3 4) '(1 2) '(1 2 3)) => ((1 2 3 4 1 2 1 2 3) (2 3 4 2 2 3))
  (maplist (lambda (x) (cons 'foo x)) '(a b c d)) => ((FOO A B C D) (FOO B C D) (FOO C D) (FOO D))
  (maplist (lambda (x) (if (member (car x) (cdr x)) 0 1)) '(a b a c d b c)) => (0 0 1 0 1 1 1)
  ;An entry is 1 if the corresponding element of the input
  ;  list was the last instance of that element in the input list.
)


;; test mapc
(define dummy nil) ; => dummy
(tests mapc
  (mapc (lambda #+murmel x #-murmel (&rest x) (setq dummy (append dummy x)))
        '(1 2 3 4)
        '(a b c d e)
        '(x y z)) => (1 2 3 4)
  dummy => (1 A X 2 B Y 3 C Z)
)


;; test mapl
(tests mapl
  (setq dummy nil) => nil
  (mapl (lambda (x) (push x dummy)) '(1 2 3 4)) => (1 2 3 4)
  dummy => ((4) (3 4) (2 3 4) (1 2 3 4))
)


;; test mapcan
(tests mapcan
  (mapcan (lambda (x y) (if (null x) nil (list x y)))
          '(nil nil nil d e)
          '(1 2 3 4 5 6))
    =>  (D 4 E 5)

  (mapcan (lambda (x) (and (numberp x) (list x)))
          '(a 1 b c 3 4 d 5))
    =>  (1 3 4 5)

  (mapcan (lambda (x) (cons x x)) '(1 2 3 4 5))
   => (1 2 3 4 5 . 5)

  ; not sure if the function returning an atom is valid
  ; but SBCL and ABCL accept this, too
  ; SBCL 2.4.0 gives an error
  (mapcan (lambda (x) x) '(1 2 3 4 5))
   => 5
)


;; test mapcon
(tests mapcon
  (mapcon #'list '(1 2 3 4)) =>  ((1 2 3 4) (2 3 4) (3 4) (4))
)



;;; - iteration

;; test do, do*
(tests do
  (do ((temp-one 1 (1+ temp-one))
       (temp-two 0 (1- temp-two)))
      ((> (- temp-one temp-two) 5) temp-one)) =>  4

  (do ((temp-one 1 (1+ temp-one))
       (temp-two 0 (1+ temp-one)))
      ((= 3 temp-two) temp-one)) =>  3

  (do* ((temp-one 1 (1+ temp-one))
        (temp-two 0 (1+ temp-one)))
       ((= 3 temp-two) temp-one)) =>  2
)


;; test dotimes
(define temp-two 0) ; => temp-two
(tests dotimes
  (dotimes (temp-one 10 temp-one)) => 10
  (dotimes (temp-one 10 t) (inc-var temp-two)) => t
  temp-two => 10
  (let ((loop "loop") (result nil)) (dotimes (i 3 result) (setq result (cons loop result))))
    => ("loop" "loop" "loop")
  
  (dotimes (i 0 i)) => 0
)

#+murmel
(tests dotimes.2
  (dotimes (i 10 (incf i) i) 1 2 3) => 11
)


;; test dolist
(tests dolist
  (setq temp-two '()) => nil
  (dolist (temp-one '(1 2 3 4) temp-two) (push temp-one temp-two)) => (4 3 2 1)

  (setq temp-two 0) => 0
  (dolist (temp-one '(1 2 3 4)) #-murmel (declare (ignore temp-one)) (inc-var temp-two)) => nil
  temp-two => 4

  (dolist (x '(a b c d)) (write x) (format t " ")) => nil ; >>  A B C D , => NIL

  (dolist (x '(1 2 3)) 'last-form)         => nil
  (dolist (x '(1 2 3) 'result) 'last-form) => result
  (dolist (x '(1 2 3) x) 'last-form)       => nil
)

#+murmel
(tests dolist.2
  (let ((n 0))
    (dolist (x '(1 2 3 4 5) (incf n) n)
      (incf n))) => 6
)



;;; - places

;; test destructuring-bind
(tests destructuring-bind
  (destructuring-bind (a b c) '(1.0 2 3) (+ a b c)) => 6.0
)


(define ctr nil)
(defun place (l) (setq ctr (1+ ctr)) l) ; return arg, incr number of invocations

;; test setf, psetf
(tests setf
  (setq x (cons 'a 'b) y (list 1 2 3)) =>  (1 2 3)
  (setf (car x) 'x (cadr y) (car x) (cdr x) y) =>  (1 X 3)
  x =>  (X 1 X 3)
  y =>  (1 X 3)
  (setq x (cons 'a 'b) y (list 1 2 3)) =>  (1 2 3)

  (setq x (list 1 2 3)) => (1 2 3)
  (setf (car x) 11) => 11

  (setq x '(0 1 2 3)) => (0 1 2 3)
  (setq ctr 0) => 0
  (setf (nth 2 (place x)) 222) => 222
  x => (0 1 222 3)
  ctr => 1


  (let ((v (vector 0 1 2)))
    (list (setf (svref v 1) 11) (svref v 1)))
  => (11 11)

  (let ((bv (make-array 3 #-murmel :element-type 'bit)))
    (list (setf (bit bv 1) 1) (bit bv 1)))
  => (1 1)

  (let ((str (#+murmel string #-murmel copy-seq "abc")))
    (list (setf (sref str 1) #\X) (sref str 1)))
  => (#\X #\X)

  (let (a b)
    (setf (values a b) (values 1 2 3 4))
    (list a b))
  => (1 2)

  (let (a b (lst (list 11 22 33)))
    (setf (values a (car lst) b (caddr lst)) (values 1 2 3 4 5))
    (list a b lst))
  => (1 3 (2 22 4))

  (let (a b c)
    (setq a 1)
    (setf a (1+ a) b a c b)
    (list a b c))
  => (2 2 2)

  (let (a b)
    (setf (values a b) 1)
    (list a b))
  => (1 nil)

  (let ((a 11) (b 22))
    (setf (values a b) 1)
    (list a b))
  => (1 nil)

  (labels ((mv () (values 1 2 3)))
    (let (a b)
      (setf (values a b) (mv))
      (list a b)))
  => (1 2)

  (let (a b)
    (multiple-value-bind (x y z) (setf (values a b) 1)
      (list x y z)))
  => (1 nil nil)

  (labels ((mv () (values 1 2 3)))
    (let (a b)
      (multiple-value-bind (x y z) (setf (values a b) (mv))
        (list x y z))))
  => (1 2 nil)
)


;#+broken
(tests psetf
  (let (a b c)
    (setq a 1)
    (psetf a (1+ a) b a c b)
    (list a b c))
  => (2 1 nil)

  (labels ((mv () (values 1 2 3)))
    (let ((a 11) (b 22))
      (multiple-value-bind (x y z) (psetf (values a b) (mv) b a)
        (list a b x y z))))
  => #+murmel (1 11 11 nil nil)
     #-murmel (1 11 nil nil nil)

  (labels ((mv () (values 1 2 3)))
    (let ((a 11) (b 22))
      (multiple-value-bind (x y z) (psetf a 111 b 222 (values a b) (mv))
        (list a b x y z))))
  => #+murmel (1 2 1   2   nil)
     #-murmel (1 2 nil nil nil)
)


;; test incf, decf
(define n 0)
(tests inplace
  (incf n) =>  1
  n =>  1
  (decf n 3.0) =>  -2.0
  n =>  -2.0
  (decf n -5.0) =>  3.0
  (decf n) =>  2.0
  (incf n 0.5) =>  2.5
  (decf n) =>  1.5
  n =>  1.5

  (setq x '(0)) => (0)
  (setq ctr 0) => 0
  (incf (car (place x))) => 1
  ctr => 1

  (setq ctr 0) => 0
  (incf (car (place x)) 2.0) => 3.0
  ctr => 1


  (let ((v (vector 0 1 2)))
    (list (incf (svref v 1)) (svref v 1)))
  => (2 2)

  (let ((bv (make-array 3 #-murmel :element-type 'bit)))
    (list (incf (bit bv 1)) (bit bv 1)))
  => (1 1)
)


;; test push, pop
(define llst nil)

(tests push-pop
  (setq llst '(nil)) =>  (NIL)
  (push 1 (car llst)) =>  (1)
  llst =>  ((1))
  (push 1 (car llst)) =>  (1 1)
  llst =>  ((1 1))
  (setq x '(a (b c) d)) =>  (A (B C) D)
  (push 5 (cadr x)) =>  (5 B C)
  x =>  (A (5 B C) D)

  (setq llst (list 1 2 3)) => (1 2 3)
  (setq ctr 0) => 0
  (push 11 (cdr (place llst))) => (11 2 3)
  llst => (1 11 2 3)
  ctr => 1

  (setq llst (list '(1 11) 2 3)) => ((1 11) 2 3)
  (setq ctr 0) => 0
  (pop (car (place llst))) => 1
  llst => ((11) 2 3)
  ctr => 1

  (setq llst '(((1 11) 22) 2 3)) => (((1 11) 22) 2 3)
  (setq ctr 0) => 0
  (pop (caar (place llst))) => 1
  llst => (((11) 22) 2 3)
  ctr => 1

  (setq llst '(1 (2 22) 3)) => (1 (2 22) 3)
  (setq ctr 0) => 0
  (pop (cadr (place llst))) => 2
  llst => (1 (22) 3)
  ctr => 1

  (setq llst '((((1 11))) 2 3)) => ((((1 11))) 2 3)
  (pop (caaar (place llst))) => 1
  llst => ((((11))) 2 3)

  (setq llst '((0 (1 11)) 2 3)) => ((0 (1 11)) 2 3)
  (pop (cadar (place llst))) => 1
  llst => ((0 (11)) 2 3)

  (setq llst '(-1 0 (1 11) 2 3)) => (-1 0 (1 11) 2 3)
  (pop (caddr (place llst))) => 1
  llst => (-1 0 (11) 2 3)

  (setq llst (list 1 11 2 3)) => (1 11 2 3)
  (setq ctr 0) => 0
  (pop (cdr (place llst))) => 11
  llst => (1 2 3)
  ctr => 1

  (setq llst '((1 11) 2 3)) => ((1 11) 2 3)
  (setq ctr 0) => 0
  (pop (cdar (place llst))) => 11
  llst => ((1) 2 3)
  ctr => 1

  (setq llst '(1 11 2 3)) => (1 11 2 3)
  (setq ctr 0) => 0
  (pop (cddr (place llst))) => 2
  llst => (1 11 3)
  ctr => 1
)


(tests push-pop.2
  (setq llst '((1))) => ((1))
  (setq ctr 0) => 0
  (push 11 (cdr (car (place llst)))) => (11)
  llst => ((1 11))
  ctr => 1
)


(tests pushnew
 (setq x '(a (b c) d)) =>  (A (B C) D)
 (pushnew 5 (cadr x)) =>  (5 B C)
 x =>  (A (5 B C) D)
 (pushnew 'b (cadr x)) =>  (5 B C)
 x =>  (A (5 B C) D)
 (setq lst '((1) (1 2) (1 2 3))) =>  ((1) (1 2) (1 2 3))
 (pushnew '(2) lst) =>  ((2) (1) (1 2) (1 2 3))
 (pushnew '(1) lst) =>  ((1) (2) (1) (1 2) (1 2 3))

 ;(pushnew '(1) lst :test 'equal) =>  ((1) (2) (1) (1 2) (1 2 3))           ; CL supports symbols as :test, Murmel does not
 (pushnew '(1) lst #-murmel :test #'equal) =>  ((1) (2) (1) (1 2) (1 2 3))

 ;(pushnew '(1) lst :key #'car) =>  ((1) (2) (1) (1 2) (1 2 3))             ; CL has :key, Murmel does not
 (pushnew '(1) lst #-murmel :test (lambda (l r) (eql (car l) (car r)))) =>  ((1) (2) (1) (1 2) (1 2 3))
)


;;; - numbers, characters

; todo abs
; todo zerop, evenp, oddp
; todo char=, char, sbit


;; test equal
(tests equal
  (equal 'a 'b) => nil
  (equal 'a 'a) => t
  (equal 3 3) => t
  (equal 3 3.0) => nil
  (equal 3.0 3.0) => t
  ;(equal #c(3 -4) #c(3 -4)) => t
  ;(equal #c(3 -4.0) #c(3 -4)) => nil
  (equal (cons 'a 'b) (cons 'a 'c)) => nil
  (equal (cons 'a 'b) (cons 'a 'b)) => t
  (equal #\A #\A) => t
  (equal #\A #\a) => nil
  (equal "Foo" "Foo") => t
  ;(equal "Foo" (copy-seq "Foo")) => t
  (equal "FOO" "foo") => nil
  (equal "This-string" "This-string") => t
  (equal "This-string" "this-string") => nil
)



;;; - sequences

(define *seq* nil)
(defun cp (seq-to lst-from)
  (do ((i 0 (1+ i)) (from lst-from (cdr from)))
      ((null from) seq-to)
    (setf (elt seq-to i) (car from))))

(defun mkarry (n element-type)
  (let ((arry (make-array n #-murmel :element-type element-type #-murmel :adjustable t)))
    (dotimes (i n)
      (setf (elt arry i) i))
    arry))

(defun copy-vec (from)
  (let ((arry (make-array (length from)
                          #-murmel :element-type (typecase from
                                                   (string 'character)
                                                   (bit 'bit)
                                                   (t t)))))
    (dotimes (i (length from) arry)
      (setf (elt arry i) (elt from i)))))


;; test copy-seq
(let (str)
  (tests copy-seq
    (setq str "a string")      => "a string"
    (equal str (copy-seq str)) => t
    (eql str (copy-seq str))   => nil
))


;; test elt
(tests elt
  (elt '(0 1 2) 1) => 1
  (elt #(0 1 2) 1) => 1
  (elt "012" 1)    => #\1
  (elt #*0101 3)   => 1

  (elt (cp (make-array 3 #-murmel :element-type t #-murmel :adjustable t) '(0 1 2)) 1) => 1
  (elt (cp (make-array 3 #-murmel :element-type 'character #-murmel :adjustable t) '(#\0 #\1 #\2)) 1) => #\1
)


;; test setf elt
(let (v)
  (tests setf-elt
    (null (setq v (make-array 3 #-murmel :element-type t #-murmel :adjustable t #-murmel :initial-contents #-murmel '(nil nil nil)))) => nil
    (setf (elt v 1) 11)   => 11
    (elt v 0) => nil
    (elt v 1) => 11

    (null (setq v (make-array 3 #-murmel :element-type 'character #-murmel :adjustable t))) => nil
    (setf (elt v 1) #\A)  => #\A
    (elt v 1) => #\A
  ))


;; test length
(tests length
  (length nil) => 0
  (length (list)) => 0
  (length (list 1 2 3)) => 3
  (length (vector)) => 0
  (length (vector 1 2 3)) => 3
  (length "abc") => 3
  (length #*010) => 3

  (length (make-array 3 #-murmel :element-type t #-murmel :adjustable t)) => 3
  (length (make-array 3 #-murmel :element-type 'character #-murmel :adjustable t)) => 3
  (length (make-array 3 #-murmel :element-type 'bit #-murmel :adjustable t)) => 3
)


;; test reverse, nreverse
(let ((str nil) (l nil))
  (tests reverse-nreverse
    (setq str "abc") =>  "abc"
    (reverse str) => "cba"
    str =>  "abc"

    (setq str (copy-vec str)) => "abc"
    (nreverse str) => "cba"
    ; str => implementation-dependant

    (setq l (list 1 2 3)) =>  (1 2 3)
    (nreverse l) =>  (3 2 1)
    ; l => implementation-dependant

    (setq l (list 1 2 3)) =>  (1 2 3)
    (reverse l) =>  (3 2 1)
    l => (1 2 3)

    (setq l #*0101) => #*0101
    (reverse l) => #*1010
    l => #*0101

    (elt (reverse (cp (make-array 3 #-murmel :element-type t #-murmel :adjustable t) '(1 2 3))) 0)  => 3
    (elt (nreverse (cp (make-array 3 #-murmel :element-type t #-murmel :adjustable t) '(1 2 3))) 0) => 3
  ))


;; test remove-if, remove
(tests remove
  (remove-if #'oddp '(1 2 4 1 3 4 5)) => (2 4 4)
  (remove-if (complement #'evenp) '(1 2 4 1 3 4 5)) => (2 4 4)

  (remove 4 '(1 3 4 5 9)) => (1 3 5 9)
  (remove 4 '(1 2 4 1 3 4 5)) => (1 2 1 3 5)


  (length (remove 1 (mkarry 5 t))) => 4
)


;; test map
(tests map
  (map 'string #'(lambda (x y)
                   (char "01234567890ABCDEF" (mod (+ x y) 16)))
       '(1 2 3 4)
       '(10 9 8 7)) =>  "AAAA"

  ;(setq *seq* '("lower" "UPPER" "" "123")) =>  ("lower" "UPPER" "" "123")
  ;(map nil #'nstring-upcase *seq*) =>  NIL
  ;*seq* =>  ("LOWER" "UPPER" "" "123")

  (map 'list #'- '(1.0 2.0 3.0 4.0)) =>  (-1.0 -2.0 -3.0 -4.0)

  (map 'string
       #'(lambda (x) (if (oddp x) #\1 #\0))
       '(1 2 3 4)) =>  "1010"

  (map 'string
       #'(lambda (x) (if (oddp x) #\1 #\0))
       (cp (make-array 4 #-murmel :element-type t #-murmel :adjustable t) '(1 2 3 4))) =>  "1010"
)

(let ((seq (list (vector 1) (vector 2) (vector 3))))
  (tests map

    (map nil (lambda (v) (setf (svref v 0) (1+ (svref v 0)))) seq) => nil
    ;seq => (#(2) #(3) #(4))
    (svref (cadr seq) 0) => 3
  ))


;; test map-into
(let ((l (list 0 0 0 0 0)) (k '(one two three)) (n 0))
  (tests map-into
    (map-into l #'1+ l) => (1 1 1 1 1)
    l => (1 1 1 1 1)
    (map-into l #'+ l '(10.0 20.0 30.0)) => (11.0 21.0 31.0 1 1)
    (map-into l #'truncate l) => (11 21 31 1 1)
    (map-into l #'cons k l) => ((one . 11) (two . 21) (three . 31) 1 1)
    k => (one two three)
    (map-into l (lambda () (setq n (1+ n)))) => (1 2 3 4 5)
    n => 5

    (map-into l (lambda #+murmel ignore #-murmel (&rest ignore) (setq n (1+ n))) nil) => (1 2 3 4 5)
    n => 5
    (map-into l #'+ l #(10.0 20.0 30.0)) => (11.0 22.0 33.0 4 5)
  ))

(tests map-into.vector
  (map-into (make-array 5 #-murmel :element-type 'character) (lambda () #\A)) => "AAAAA"
  (map-into (make-array 5 #-murmel :element-type 'bit) (let ((b 0)) (lambda () (setq b (- 1 b)) b))) => #*10101
)


;; test reduce
(tests reduce
  (reduce #'* '(1.0 2 3 4 5)) =>  120.0

  ;(reduce append '((1) (2)) :initial-value '(i n i t)) =>  (I N I T 1 2)
  (reduce #'append (cons '(i n i t) '((1) (2)))) =>  (I N I T 1 2)

  ;(reduce append '((1) (2)) :from-end t :initial-value '(i n i t)) =>  (1 2 I N I T)
  (reduce #'append (append '((1) (2)) (list '(i n i t))) #-murmel :from-end t) =>  (1 2 I N I T)

  (reduce #'- '(1.0 2 3 4)) ;==  (- (- (- 1 2) 3) 4)
    =>  -8.0
  (reduce #'- '(1.0 2 3 4) #-murmel :from-end t)    ;Alternating sum: ==  (- 1 (- 2 (- 3 4)))
    =>  -2.0
  (reduce #'+ '()) =>  #+murmel 0.0 #-murmel 0
  (reduce #'+ '(3)) =>  3
  (reduce #'+ '(foo)) =>  FOO
  (reduce #'list '(1 2 3 4)) =>  (((1 2) 3) 4)
  (reduce #'list '(1 2 3 4) #-murmel :from-end t) =>  (1 (2 (3 4)))

  ;(reduce list '(1 2 3 4) :initial-value 'foo) =>  ((((foo 1) 2) 3) 4)
  (reduce #'list (cons 'foo '(1 2 3 4))) =>  ((((foo 1) 2) 3) 4)

  ;(reduce #'list '(1 2 3 4)
  ;     :from-end t :initial-value 'foo) =>  (1 (2 (3 (4 foo))))
  (reduce #'list (append '(1 2 3 4) (list 'foo)) #-murmel :from-end t) =>  (1 (2 (3 (4 foo))))



  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) '() #-murmel :from-end t) x))
    => (0 nil)
  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) '(1) #-murmel :from-end t) x))
    => (1)
  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) '(1 2) #-murmel :from-end t) x))
    => (3 (1 2))
  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) '(1 2 3 4 5) #-murmel :from-end t) x))
    => (15 (1 14) (2 12) (3 9) (4 5))

  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) #() #-murmel :from-end t) x))
    => (0 nil)
  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) #(1) #-murmel :from-end t) x))
    => (1)
  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) #(1 2) #-murmel :from-end t) x))
    => (3 (1 2))
  (let (x) (cons (reduce (lambda #+murmel args #-murmel (&rest args) (push args x) (truncate (apply #'+ args))) #(1 2 3 4 5) #-murmel :from-end t) x))
    => (15 (1 14) (2 12) (3 9) (4 5))

  (reduce #'* (cp (make-array 5 #-murmel :element-type t #-murmel :adjustable t) '(1.0 2 3 4 5))) => 120.0
)



;;; - hash tables
(tests setf.hash
  (let ((h (make-hash-table)))
    (setf (gethash 1 h) 11)
    (gethash 1 h)) => 11

  (let ((h (make-hash-table)))
    (setf (gethash 1 h) 11)
    (list (hash-table-count h)
          (remhash 1 h)
          (remhash 1 h)
          (hash-table-count h))) => (1 t nil 0)
)

(tests maphash.1
  (let ((table (make-hash-table)))
    (dotimes (i 10) (setf (gethash i table) i))  ;  =>  NIL
    (let ((sum-of-squares 0))
       (maphash #'(lambda (key val)
                    (let ((square (* val val)))
                      (incf sum-of-squares square)
                      (setf (gethash key table) square)))
                table)
       (list (floor sum-of-squares) (hash-table-count table)))) =>  (285 10)

;  (maphash #'(lambda (key val)
;                (when (oddp val) (remhash key table)))
;            table) =>  NIL
;  (hash-table-count table) =>  5
;  (maphash #'(lambda (k v) (print (list k v))) table)
; (0 0)
; (8 64)
; (2 4)
; (6 36)
; (4 16)
; =>  NIL
)


;;; - higher order

;; test identity
(tests identity
  (identity 101) =>  101
  (mapcan #'identity (list (list 1 2 3) '(4 5 6))) =>  (1 2 3 4 5 6)
)


;; test constantly
(defmacro with-vars (vars . forms)
  `((lambda ,vars ,@forms) ,@(mapcar (constantly nil) vars))) ; => WITH-VARS
(tests constantly
  (mapcar (constantly 3) '(a b c d)) =>  (3 3 3 3)

  (macroexpand-1 '(with-vars (a b) (setq a 3 b (* a a)) (list a b)))
    => ((LAMBDA (A B) (SETQ A 3 B (* A A)) (LIST A B)) NIL NIL)
)


;; test complement
(tests complement
  (#-murmel funcall (complement #'zerop) 1) => t
  (#-murmel funcall (complement #'characterp) #\a) => nil
  (#-murmel funcall (complement #'member) 'a '(a b c)) =>  nil
  (#-murmel funcall (complement #'member) 'd '(a b c)) =>  t
)


;; test every, some, notevery, notany
(tests predicates
  (every #'characterp "abc") =>  t
  (every #'char= "abcdefg" '(#\a #\b)) => t

  (some     #'= '(1 2 3 4 5) '(5 4 3 2 1)) =>  t

  (notevery #'< '(1 2 3 4) '(5 6 7 8) '(9 10 11 12)) =>  nil
  (notevery #'< '(1 2 3 4) '(5 6 7 2) '(9 10 11 12)) =>  t

  (notany   #'> '(1 2 3 4) '(5 6 7 8) '(9 10 11 12)) =>  t
  (notany   #'> '(1 2 3 4) '(5 6 2 8) '(9 10 1 12)) =>  nil
)



;;; tests for Alexandria inspired functions and macros

;;; - Alexandria: conses and lists

;; test circular-list
#+murmel
(tests circular-list
  (circular-list) => nil
  ; (circular-list nil) => (nil #<circular-list>)  ; reader chokes on #<circular-list>
  (nth 21 (circular-list 1 2 3)) => 1
)



;;; - Alexandria: iteration

;; test doplist
#+murmel
(tests doplist
  (setq temp-two nil) => nil
  (doplist (k v '(k1 1 k2 2 k3 3) temp-two)
    (push (cons k v) temp-two)) => ((k3 . 3) (k2 . 2) (k1 . 1))
  temp-two => ((k3 . 3) (k2 . 2) (k1 . 1))

  (setq temp-two nil) => nil
  (doplist (k v '(k1 1 k2 2 k3 3) (pop temp-two) (incf (cdar temp-two)) temp-two)
    (push (cons k v) temp-two)) => ((k2 . 3) (k1 . 1))
  temp-two => ((k2 . 3) (k1 . 1))
)



;;; - Alexandria: higher order

;; test compose
#+murmel
(tests compose
  ((compose - sqrt) 10) => -3.1622776601683795
  ((compose 1+ 1+ truncate +) 1 2 3) => 8
)


;; test multiple-value-compose
#+murmel
(tests multiple-value-compose
  (let ((comp (multiple-value-compose truncate (lambda (a b) (values b a)))))
    (comp 4 5))  => 1
)


;; test conjoin
#+murmel
(tests conjoin
    (let ((conjunction (conjoin #'consp
                                (lambda (x)
                                  (stringp (car x)))
                                (lambda (x)
                                  (char (car x) 0)))))
      (list (#-murmel funcall conjunction 'zot)
            (#-murmel funcall conjunction '(foo))
            (#-murmel funcall conjunction '("foo"))))
    => (nil nil #\f)

    (let ((conjunction (conjoin #'zerop)))
      (list (#-murmel funcall conjunction 0)
            (#-murmel funcall conjunction 1)))
    => (t nil))


;; test disjoin
#+murmel (define :cons ':cons)
#+murmel (define :string ':string)

#+murmel
(tests disjoin
    (let ((disjunction (disjoin (lambda (x)
                                  (and (consp x) :cons))
                                (lambda (x)
                                  (and (stringp x) :string)))))
      (list (#-murmel funcall disjunction 'zot)
            (#-murmel funcall disjunction '(foo bar))
            (#-murmel funcall disjunction "test")))
  => (nil :cons :string)


    (let ((disjunction (disjoin #'zerop)))
      (list (#-murmel funcall disjunction 0)
            (#-murmel funcall disjunction 1)))
  => (t nil))


;; test curry and rcurry
#+murmel
(tests curry
  ((curry - 3 2) 1) => 0.0
  ((rcurry - 3 2) 1) => -4.0
)


;;; - Alexandria: misc

;; test with-gensyms
;; define a "non-shortcircuiting logical and" as a macro
;; uses "with-gensyms" so that the macro expansion does NOT contain a variable "result"
#+murmel
(progn
(defmacro logical-and-3 (a b c)
  (with-gensyms (result)
    `(let ((,result t))
       (if ,a nil (setq ,result nil))
       (if ,b nil (setq ,result nil))
       (if ,c nil (setq ,result nil))
       ,result)))

(define result 1) ; => result; the symbol "result" is used in the macro, name-capturing must be avoided
(tests with-gensyms
  (logical-and-3 result 2 3) => t
  result => 1 ; global variable is not affected by the macro
))



;;; tests for SRFI-1 inspired functions and macros
#+murmel
(tests srfi-1
  (unzip '((1 2) (11 22) (111 222 333))) => (1 11 111)
  (unzip '(nil nil nil)) => (nil nil nil)
  (unzip nil) => nil

  (unzip-tails '((1 2) (11 22) (111 222 333))) => ((2) (22) (222 333))
  (unzip-tails '(nil nil nil)) => (nil nil nil)
  (unzip-tails nil) => nil
)



;;; tests for serapeum inspired functions and macros

#+murmel
(tests serapeum
  (plist-keys '(a 1 b 2 c 3))         => (a b c)

  (plist-values '(a 1 b 2 c 3))       => (1 2 3)

  (with-accumulator mult * 1
    (dotimes (i 5) (mult (1+ i))))    => 120.0

  (summing (dotimes (i 10) (sum i)))  => 45.0

  (collecting
    (dotimes (i 10) (collect i)))     => (0 1 2 3 4 5 6 7 8 9)

  (reverse-collecting
    (dotimes (i 10) (collect i)))     => (9 8 7 6 5 4 3 2 1 0)
)



;;; tests for Murmel functions and macros

;;; - logic and program structure

;; test thread-first
#+murmel
(tests thread-first
  (->) => nil
  (-> 200 (/ 2) (+ 7)) => 107.0
  (macroexpand-1 '(-> 200 (/ 2) (+ 7)))
    => (+ (/ 200 2) 7)
  (-> 107 code-char char-code) => 107
)


;; test thread-last
#+murmel
(tests thread-last
  (->>) => nil
  (->> 200 (/ 2) (+ 7)) => 7.01
  (macroexpand-1 '(->> 200 (/ 2) (+ 7)))
    => (+ 7 (/ 2 200))
  (->> 107 code-char char-code) => 107
  (->> '(1 2 3) (mapcar (lambda (n) (expt n 2))) (reduce +)) => 14.0
  (->> '(1 2 3) (mapcar 1+) (reduce +)) => 9.0
  (->> '(1 2 3 4 5) (remove-if evenp) (mapcar 1+) (reduce +)) => 12.0

  (->> 30
    1+              ; (1+ 30)                  => 31
    (+ 1 2 3)       ; (+ 1 2 3 31)             => 37.0
    (+ 2 2)         ; (+ 2 2 37.0)             => 41.0
    (+)             ; (+ 41.0)                 => 41.0
    list            ; (list 41.0)              => (41.0)
    (append '(1 1)) ; (append (1 1) (41.0))    => (1 1 41.0)
    (apply vector)  ; (apply vector (1 1 41.0) => #(1 1 41.0)
    (reduce +)      ; (reduce + #(1 1 41.0))   => 43.0
    (- 1)           ; (- 1 43.0)               => -42.0
    (* -1)          ; (* -1 -42.0)             => 42.0
    truncate)
    => 42
)


;; test short-circuiting thread first
#+murmel
(let* ((mk-nil-args nil)
       (mk-nil (lambda args (setq mk-nil-args args) nil))
       (fail (lambda (args) (assert-equal t nil "function fail should not be called!"))))
  (tests short-circuiting-thread-first
    (and-> 1 1+ (+ 2 3) (mk-nil 'a 'b 'c) fail) => nil
    mk-nil-args => (7.0 a b c)
  ))


;; test short-circuiting thread last
#+murmel
(tests short-circuiting-thread-last
  (and->> '(1 3 5) (mapcar 1+) (remove-if evenp) (reduce -)) => nil
    ; ->> would throw an error: "-" needs at least one arg
)


;; more threading macros tests
#+murmel
(tests more-threading-macros-tests
  (->) => nil
  (->>) => nil
  (and->) => nil
  (and->>) => nil

  (-> 1) => 1
  (->> 1) => 1
  (and-> 1) => 1
  (and->> 1) => 1

  (-> 1 identity) => 1
  (->> 1 identity) => 1
  (and-> 1 identity) => 1
  (and->> 1 identity) => 1

  (-> 1 1+) => 2
  (->> 1 1+) => 2
  (and-> 1 1+) => 2
  (and->> 1 1+) => 2
)

#+murmel
(let* ((f-args nil)
       (f (lambda (a1 a2 a3) (setq f-args (list a1 a2 a3)) a1)) ; f passes 1st arg and records args
       (l-args nil)
       (l (lambda (a1 a2 a3) (setq l-args (list a1 a2 a3)) a3))) ; l passes last arg and records args
  (tests more-threading-macros-tests.2
    (-> 11 (f 1 2)) => 11
    f-args => (11 1 2)
    (setq f-args nil) => nil

    (and-> 11 (f 1 2)) => 11
    f-args => (11 1 2)
    (setq f-args nil) => nil

    (->> 11 (l 1 2)) => 11
    l-args => (1 2 11)
    (setq l-args nil) => nil

    (and->> 11 (l 1 2)) => 11
    l-args => (1 2 11)
    (setq l-args nil) => nil
  ))



;;; - iteration

;; test dovector
#+murmel
(tests dovector
  (let (x) (list (dovector (elem #(1 2 3 4 5) (push "all done" x) 'done) (push elem x)) x))
  => (done ("all done" 5 4 3 2 1))

  (let (x) (list (dovector (elem "12345" (push "all done" x) 'done) (push elem x)) x))
  => (done ("all done" #\5 #\4 #\3 #\2 #\1))
  (let (x) (list (dovector (elem ((jmethod "java.lang.StringBuilder" "new" "String") "12345") (push "all done" x) 'done) (push elem x)) x))
  => (done ("all done" #\5 #\4 #\3 #\2 #\1))

  (let (x) (list (dovector (elem #*010101 (push "all done" x) 'done) (push elem x)) x))
  => (done ("all done" 1 0 1 0 1 0))
)


;; test dogenerator
#+murmel
(tests dogenerator
  (let (result)
    (dogenerator (x (multiple-value-compose (lambda (v more) (if more (values (1+ v) more) (values nil nil)))
                                            (scan 1 1 5)))
      (push x result))
    result) => (6 5 4 3 2)

  (let (result)
    (dogenerator (x (scan #H(eql 1 11 2 22 3 33)))
      (push x result))
    result) => ((3 . 33) (2 . 22) (1 . 11))
)



;;; - places
;  todo: *f, /f, +f and -f



;;; - generators

;; test generator functions
#+murmel
(tests scan
  (let (result (g (scan 1 1.0 4)))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => (4 3 2 1)

  (let (result (g (scan 1.0 1.0 4)))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => (4.0 3.0 2.0 1.0)

  (let (result (g (scan 1 2 5)))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => (nil 5.0 3.0 1.0)


  (let (result (g (scan '(1 3 5))))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => (nil 5 3 1)


  (let (result (g (scan '(-1 1 3 5) 1 3)))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => (nil nil 3 1)


  (let (result (g (scan #(-1 1 3 5) 1)))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => (nil 5 3 1)

  (let (result (g (scan #(-1 1 3 5) 1 3)))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => (nil nil 3 1)

  (let (result) (dogenerator (i (scan (scan 0 1 10) 0)) (push i result)) (reverse result))
    ==> (0 1 2 3 4 5 6 7 8 9 10)

  (let (result) (dogenerator (i (scan (scan 0 1 10) 2 5)) (push i result)) (reverse result))
    ==> (2 3 4)
)

#+murmel
(tests scan-multiple
  (let (result (g (scan-multiple (scan 1 1.0 4) (scan '(11 22 33 44 55)) (scan #(111 222 333 444)))))
    (push (g) result)
    (push (g) result)
    (push (g) result)
    (push (g) result)) => ((4 44 444)  (3 33 333) (2 22 222) (1 11 111))

  (let (result (g (scan-multiple (scan '(1 2 3 4)) (scan '(11 22 33)))))
    (dotimes (i 6 result)
      (push (g) result))) => (nil nil (4) (3 33) (2 22) (1 11))

  (let (result (g (scan-multiple (scan '(1 2 3)) (scan '(11 22)) (scan '(111 222 333)))))
    (dotimes (i 6 result)
      (push (g) result))) => (nil nil nil (3) (2 22 222) (1 11 111))

  (let (result (g (scan-multiple (scan '(1 2 3)) (scan '(11 22 33)) (scan '(111 222 333)))))
    (dotimes (i 6 result)
      (push (g) result))) => (nil nil nil (3 33 333) (2 22 222) (1 11 111))

  (let (result (g (scan-multiple (scan 1 1 3))))
    (dotimes (i 6 result)
      (push (g) result))) => (nil nil nil (3) (2) (1))
)

#+murmel
(tests scan-concat
  (let (result (g (scan-concat (scan #(1 2 3)))))
    (dotimes (i 6 result)
      (push (g) result))) => (nil nil nil 3 2 1)

  (let (result (g (scan-concat (scan #(1 2 3)) (scan #(11 22 33)))))
    (dotimes (i 10 result)
      (push (g) result))) => (nil nil nil nil 33 22 11 3 2 1)

  (let (result (g (scan-concat (scan #(1 2 3)) (scan #(11 22 33)) (lambda () (values 111 t)))))
    (dotimes (i 10 result)
      (push (g) result))) => (111 111 111 111 33 22 11 3 2 1)
)



;;; Summary
;;; print succeeded and failed tests if any

(writeln) (writeln)
(write *error-count*) (format t "/") (write *success-count*) (format t " test(s) failed")
(writeln)
(if (= 0 *error-count*)
      (format t "Success.")
  (format t "Failure."))
(writeln)


#+murmel
(unless (zerop *error-count*)
  (error "mlib-test.lisp: %d/%d asserts failed.%n" *error-count* *success-count*))