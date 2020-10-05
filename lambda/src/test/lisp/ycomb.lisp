; from https://github.com/carld/micro-lisp/blob/master/examples/reverse.lisp

; GNU CLISP v2.49+ (Common Lisp) gives an error, Gauche v0.9.3.3 (Scheme) runs it fine (after replacing eq -> eq?)
 
; LambdaJ gives an error: cannot eval expression
; outputt: (1 2 3)
; result: t

(((lambda (fn)
          ((lambda (h) (h h))
           (lambda (g)
                   (fn (lambda (x)
                               ((g g) x))))))

 (lambda (f)
   (lambda (lst)
     (cond
       ((null? lst) (quote ()))
       ((eq (car lst) (quote a)) (cons (quote 1) (f (cdr lst))))
       ((eq (car lst) (quote b)) (cons (quote 2) (f (cdr lst))))
       ((eq (car lst) (quote c)) (cons (quote 3) (f (cdr lst))))
       ((quote t) (cons (car lst) (f (cdr lst))))))))

  (cons (quote a) (cons (quote b) (cons (quote c) (quote ())))))
