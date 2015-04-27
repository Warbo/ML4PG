(require 'cl)

(defun obtain-theorem (name)
  "Obtain definition and clean the term"
  (unless (equal (replace-regexp-in-string "[\t\n ]" "" name) "")
    (let ((thm (send-coq-cmd (format "About %s" name))))
      (subseq thm 0 (search "\n\n" thm)))))


(defun clean-goal (goal)
  (let* ((clean-term (remove-whitespaces (remove-jumps (subseq goal (+ 28 (search "============================" goal))
                                                               (search "(dependent " goal)))))
         (arr (search "->" clean-term :from-end t))
         (comma (search "," clean-term :from-end t))
         (obj (cond ((and arr comma (< arr comma))  (subseq clean-term (+ 1 comma)))
                    (arr (subseq clean-term (+ 2 arr)))
                    (comma (subseq clean-term (+ 1 comma)))
                    (t clean-term))))
    (replace-questionmark (replace-quote obj))))

(defun vars-goal (goal)
  (let* ((clean-vars (remove-jumps (replace-quote (subseq goal (+ 1 (search ")" goal :start2 ( + 1 (search ")" goal)))) (search "============================" goal)) ))))
    (search-vars clean-vars)))

(defun addcurrentgoal ()
  (interactive)
  (send-coq-cmd "Unset Printing All.")
  (send-coq-cmd "Unset Printing Notations.")
  (let ((iftable (send-coq-cmd "Print Table Printing If."))
        (term nil))
    (unless (search "None" iftable)
      (send-coq-cmd (format "Remove Printing If %s."
                            (subseq iftable (+ 1 (search ":" iftable))))))

    (setf term (send-coq-cmd "Focus"))
    (setf listofstatements (append (list (list 'theorem (make-symbol "temp") (thm-to-list (clean-goal term)))) listofstatements))
    (setf listofthmvariables (append (list (list (vars-goal term) )) listofthmvariables)    )
    (unless (search "None" iftable)
      (send-coq-cmd (format "Add Printing If %s."
                            (subseq iftable (+ 1 (search ":" iftable))))))
    (send-coq-cmd "Set Printing Notations.")
    (send-coq-cmd "Set Printing All.")))

(defvar varstypes nil)

(defun gettype (object)
  (if (assoc object varstypes)
      (cdr (assoc object varstypes))
      (remove-whitespaces (remove-jumps (send-coq-cmd (format "Check %s" object))))))

(defun transform-types (l)
  (do ((temp l (cdr temp))
       (res nil)
       (flag nil))
      ((or flag (endp temp)) (if flag res (reverse res)))
    (if (listp (car temp))
    (setf res (cons (transform-types (car temp)) res))
      (if (member (car temp) '(forall exists -> fun))
      (if (equal (car temp) 'fun)
          (progn (setf res (varsterms (concat "foo : fun " (replace=>withcomma (listtostring (cdr temp))))))
             (setf flag t))
        (setf res (cons (car temp) res)))
    (setf res (cons (gettype (car temp)) res))))))

(defun listtostring (l)
  (do ((temp l (cdr temp))
       (res ""))
      ((endp temp) res)
    (setf res (concat res (format "%s " (car temp))))))

(defun replace=>withcomma (text)
  (concat (subseq text 0 (search "=>" text))
      ","
      (subseq text (+ 2(search "=>" text)))))

(defun transformvars (vars)
  (let ((type (nthcdr (1+ (position ': vars)) vars))
    (v (butlast vars (- (length vars) (position ': vars)))))
    (do ((temp v (cdr temp))
     (res nil))
    ((endp temp) res)
      (progn (setf varstypes (append varstypes (list (cons (car temp) (format "%s : %s" (car temp) (listtostring type))))))
         (setf res (cons (format "%s : %s" (car temp) (listtostring type))  res))))))

(defun split-vars (term)
  (let ((m (car (read-from-string  (subseq term 0 (search " " term)))))
    (t1 (car (read-from-string (concat "(" (subseq term (1+ (search " " term))) ")")))))
    (if (not (listp (car t1)))
    (cons m (transformvars t1))
      (do ((temp t1 (cdr temp))
       (res nil))
      ((endp temp) (cons (format "%s" m) (reverse res)))
    (setf res (append (transformvars (car temp)) res))))))

(defun split-term-> (term)
  (let ((trm (split-term->-aux term)))
    (if trm (car trm)
            (error "FAILED TO PARSE: %s" term))))

(defun split-term->-aux (term)
  (condition-case nil
      (list (if (not (search "->" term))
                (cons (car (read-from-string (concat "(" term ")"))) nil)
              (cons (car (read-from-string (concat "(" (subseq term 0 (search "->" term)) ")")))
                    (split-term-> (subseq term (+ 2 (search "->" term)))))))
      (error nil)))

(defun varsterms (term1)
  (let* ((term2 (subseq term1 (1+ (search ":" term1))))
         (term3 (remove-whitespaces (remove-jumps term2)))
         (term  (subseq term3 1)))
    (if (search "," term)
        (append (split-vars (subseq term 0 (search "," term :from-end t)))
                (transform-types (introduce-> (split-term-> (subseq term (1+ (search "," term :from-end t)))))))
        (transform-types (split-term-> term)))))

(defun introduce->aux (l)
  (if (or (endp l) (equal (length l) 1))
      (car l)
    (list '-> (car l)
      (introduce->aux (cdr l)))))

(defun introduce-> (l)
  (if (equal (length l) 1)
      l
    (list (introduce->aux l))))

(defun thm-for-tree (name)
  (interactive)
  (setf varstypes nil)
  (send-coq-cmd "Unset Printing All.")
  (send-coq-cmd "Unset Printing Notations.")
  (let* ((iftable (send-coq-cmd "Print Table Printing If."))
         (term    nil)
         (colon   (search ":" iftable))
         (ifs     (subseq iftable (+ 1 colon))))
    (unless (search "None" iftable)
      (send-coq-cmd (format "Remove Printing If %s" ifs)))

    (setf term (replace-regexp-in-string "'" "1" (obtain-theorem name)))
    (unless (search "None" iftable)
      (send-coq-cmd (format "Add Printing If %s" ifs)))
    (send-coq-cmd "Set Printing Notations.")
    (send-coq-cmd "Set Printing All.")
    (unless (search "not a defined object" term)
      (if (= 1 (length (varsterms term)))
          (car (varsterms term))
        (varsterms term)))))

(defun showtreegraphthm-aux (thm)
  (unless (equal thm "")
    (if (search "Error" (obtain-theorem thm))
        (message "Theorem %s is undefined" thm)
        (let ((t2 (thm-for-tree thm)))
          (if t2
              (showtreegraph t2)
              (message "Theorem %s isn't defined" thm))))))

(defun showtreegraphthm ()
  (interactive)
  (showtreegraphthm-aux (read-string "Introduce the name of a theorem that you have previously defined: ")))
