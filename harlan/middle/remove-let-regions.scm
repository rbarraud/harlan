(library
  (harlan middle remove-let-regions)
  (export remove-let-regions)
  (import
    (rnrs)
    (harlan helpers)
    (elegant-weapons helpers)
    (elegant-weapons sets))

 (define region-size (expt 2 27)) ;; 128MB
;; (define region-size (expt 2 26)) ;; 64MB
;; (define region-size 16777216) ;; 16MB

(define-match remove-let-regions
  ((module ,[remove-decl -> decl*] ...)
   `(module . ,decl*)))

(define-match remove-decl
  ((fn ,name ,args ,t ,[remove-stmt -> s])
   `(fn ,name ,args ,t ,s))
  ((extern ,name ,args -> ,t)
   `(extern ,name ,args -> ,t)))

(define-match remove-stmt
  ((error ,x) `(error ,x))
  ((let ,b ,[stmt])
   `(let ,b ,stmt))
  ((let-region (,r) ,stmt)
   (let ((br `((do (call
                    (c-expr (((ptr region)) -> void) free_region)
                    (var (ptr region) ,r))))))
     `(let ((,r (ptr region)
                (call
                 (c-expr ((int) -> (ptr region)) create_region)
                 (int ,region-size))))
        ,(remove-stmt ((add-free br) stmt)))))
  ((begin ,[stmt*] ...)
   (make-begin stmt*))
  ((if ,test ,[conseq])
   `(if ,test ,conseq))
  ((if ,test ,[conseq] ,[alt])
   `(if ,test ,conseq ,alt))
  ((while ,e ,[stmt])
   `(while ,e ,stmt))
  ((for (,i ,start ,end ,step) ,[stmt])
   `(for (,i ,start ,end ,step) ,stmt))
  ((set! ,lhs ,rhs) `(set! ,lhs ,rhs))
  ((return)
   `(return))
  ((return ,e)
   `(return ,e))
  ((assert ,e) `(assert ,e))
  ((print ,e ...) `(print . ,e))
  ((kernel ,d ,fv* ,[stmt])
   `(kernel ,d ,fv* ,stmt))
  ((do ,e) `(do ,e)))

(define-match (add-free before-return)
  ((let ,b ,[stmt])
   `(let ,b ,stmt))
  ((let-region (,r) ,[stmt])
   `(let-region (,r) ,stmt))
  ((begin ,stmt* ... ,[stmt])
   `(begin ,@stmt* ,stmt))
  ((if ,test ,[conseq])
   `(if ,test ,conseq))
  ((if ,test ,[conseq] ,[alt])
   `(if ,test ,conseq ,alt))
  ((while ,e ,[stmt])
   `(while ,e ,stmt))
  ((for (,i ,start ,end ,step) ,[stmt])
   `(for (,i ,start ,end ,step) ,stmt))
  ((set! ,lhs ,rhs)
   `(begin (set! ,lhs ,rhs) . ,before-return))
  ((return)
   `(begin ,@before-return (return)))
  ((return ,e)
   (let ((ret (gensym 'ret))
         (t (type-of e)))
     `(let ((,ret ,t ,e))
        (begin
          ,@before-return
          (return (var ,t ,ret))))))
  ((assert ,e)
   `(begin (assert ,e) . ,before-return))
  ((print ,e ...)
   `(begin (print . ,e) . ,before-return))
  ((kernel ,d ,iters ,fv* ,[stmt])
   `(kernel ,d ,iters ,fv* ,stmt))
  ((do ,e)
   `(begin (do ,e) . ,before-return)))

(define-match type-of
  ((,t ,v) (guard (scalar-type? t)) t)
  ((var ,t ,x) t)
  ((int->float ,t) `float)
  ((length ,t) `int)
  ((addressof ,[t]) `(ptr ,t))
  ((deref ,[t]) (cadr t))
  ((if ,t ,[c] ,a) c)
  ((call (var (,argt -> ,rt) ,fn) . ,arg*) rt)
  ((c-expr ,t ,v) t)
  ((vector-ref ,t ,v ,i) t)
  ((,op ,[lhs] ,rhs)
   (guard (binop? op))
   lhs)
  ((,op ,lhs ,rhs)
   (guard (relop? op))
   rhs))

)