(defun take-n (n list)
  (if (or (= n 0) (null list))
      nil
      (cons (car list) (take-n (1- n) (cdr list)))))

(defun join-strings (strs sep)
  "Concatenate STRS together, separated by SEP"
  (mapconcat 'identity strs sep))

(defun any-to-string (any)
  (format "%S" any))

(defun compose (&rest funcs)
  (unless funcs (error "Nothing to compose"))
  `(lambda (&rest args)
     (let ((result args))
       (dolist (func (reverse ',funcs) (car result))
         (setq result (list (apply func result)))))))

(defun f-and (&rest args)
  "Boolean AND, implemented as a proper function"
  (let ((result t))
    (dolist (elem args result)
      (setf result (and result elem)))))

(defun all (lst)
  "Nil iff any element of LST is nil"
  (apply 'f-and lst))

(defun any-which (lst p)
  (let (result)
    (dolist (elem lst result)
      (unless result
        (setf result (funcall p elem))))))

(defun string-split (str sep)
  (split-string str (regexp-quote sep)))

(defun remove-whitespace (string)
  (strip-regexp string "[\s\n\r\t]"))

(defun extract-coq-names-from (str)
  (mapcar (lambda (s)
            (strip-regexp s  (format "\\(%s\\)\\|[\s\n]+" coq-declaration-re)))
          (extract-coq-names-from-aux str)))

(defconst coq-declaration-re
  (join-strings '("Theorem" "Lemma" "Fact" "Remark" "Corollary" "Definition"
                  "Fixpoint" "CoFixpoint" "Example" "Proposition")
                "\\|")
  "A regexp matching Coq declaration keywords")

(defun extract-coq-names-from-aux (str)
  "An unreliable, conservative way to extract some of the names defined in a
   string of Coq vernacular. Note that this does *not* respect Sections and
   Modules, so the names you get back might not be defined globally."
  (re-seq (coq-declaration-re-with-name "[a-zA-Z0-9_]+")
          str))

(defun coq-declaration-re-with-name (name)
  "Produce a regular expression which matches a Coq declaration of NAME"
  (let ((ws "[\s\n]+"))
    (format "\\(%s\\)%s%s%s" coq-declaration-re ws name ws)))

(defun re-seq (regexp string)
  "Get a list of all regexp matches in a string"
  (save-match-data
    (let ((pos 0)
          matches)
      (while (string-match regexp string pos)
        (push (match-string 0 string) matches)
        (setq pos (match-end 0)))
      matches)))

(defun count-occurences (regex string)
  "Count how many times REGEX matches STRING"
  (recursive-count regex string 0))

(defun recursive-count (regex string start)
  "Helper for count-occurences"
  (if (string-match regex string start)
      (+ 1 (recursive-count regex string (match-end 0)))
      0))

(defun balanced-parens (s)
  "Check whether ( and ) are balanced. Doesn't check quotes or other bracket
   types ([, ], {, }, <, >, etc.)"
  (= (count-occurences (regexp-quote "(") s)
     (count-occurences (regexp-quote ")") s)))

(defun strip-regexp (str &rest res)
  (let ((result str))
    (dolist (to-strip res result)
      (setq result (replace-regexp-in-string to-strip "" result)))))

(defun strip-str (str &rest strs)
  (apply 'strip-regexp (cons str (mapcar 'regexp-quote strs))))

(defconst control-chars (append (number-sequence 0 31))
  "ASCII control characters")

(defun strip-control-chars (str)
  (apply 'strip-str (cons str (mapcar 'string control-chars))))

(defun zip-with (func list1 list2)
  (let ((result nil))
    (dotimes (n (min (length list1) (length list2)) result)
      (append-to result (funcall func (nth n list1) (nth n list2))))))

(defun listofp (pred)
  "Predicate: does every element of a given list satisfy PRED?"
  `(lambda (lst)
     (all (mapcar ,pred lst))))

(defun filter-list (pred lst)
  (let ((result nil))
    (dolist (elem lst result)
      (when (funcall pred elem)
        (append-to result elem)))))

(defun drop-n (n lst)
  (if (<= n 0)
      lst
      (drop-n (- n 1)
              (if lst
                  (cdr lst)
                  nil))))

(defun elems-lesseq-than (x lst)
  (filter-list `(lambda (elem) (<= elem x)) lst))

(defun bump-to-above (x n lst)
  "If there are more than N elements in LST which are <= X, iteratively
   increment X."
  (let ((below (length (elems-lesseq-than x lst))))
    (if (equal n below)
        x
        (bump-to-above (+ x (- below n)) below lst))))
