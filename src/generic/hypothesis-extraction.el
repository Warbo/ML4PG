;; Keep a record of the available hypotheses at each proof step, for use by
;; other tools

(defvar proof-hypotheses nil
  "Build up the hypotheses available at each step in each proof")

(defvar hypotheses-file (getenv "HYPOTHESES_FILE")
  "File to write hypotheses to")

(defconst example-hypotheses
  '(("app_nil_l"
     (() ("l") ("l") ("l") ("l" "a0" "l0")))

    ("app_nil_l_shorter"
     (() ("l")))

    ("app_nil_l_shorterb"
     (() ("l") ("l")))

    ("app_nil_l2"
     (() ("l") () ("a" "l" "IHl") ("a" "l" "IHl") ("a" "l" "IHl")))

    ("app_nil_l2b"
     (() () ("a" "l" "IHl") ("a" "l" "IHl") ("a" "l" "IHl")))

    ("mult_n_O"
     (() () ("n" "IHn"))))
  "These are some hypotheses extracted from ml4pg.v, to give some idea of what
   we're doing. The test suite ensures these examples are up to date.")

(defun set-hypotheses-file (f)
  "Set the file to write hypotheses to"
  (setq hypotheses-file f))

(defun get-hypotheses ()
  ;; Die if there's no *goals* buffer
  (unless proof-goals-buffer
    (error "No 'goals' buffer to get hypotheses from: %S" (buffer-list)))

  ;; Switch to *goals* buffer
  (with-current-buffer proof-goals-buffer
    (let ((str (buffer-substring-no-properties (point-min) (point-max))))
      (get-hypotheses-from str))))

(defun get-hypotheses-from (str)
  (let ((hypotheses  nil)
        (accumulator nil))
    (dolist (line (split-string str "\n" t) hypotheses)

      ;; When the line contains ":", keep the preceding text
      (let ((colon   (search ":" line))
            (subgoal (search "subgoal" line)))
        (when (and colon (not subgoal))
          (test-msg (format "HYP: %s" line))
          (append-to accumulator
                     (remove-whitespace (subseq line 0 colon)))))

      ;; If the line only contains "=", we've run out of hypotheses
      (when (equal "=" (remove-duplicates (remove-whitespace line)))
        (setq hypotheses accumulator)))))

(defun add-hypotheses (name)
  (test-msg (format "ADDING HYPOTHESES FOR %s" name))
  (unless (equal "" name)
    (setq proof-hypotheses (append-to-hypotheses name
                                                 (get-hypotheses)
                                                 proof-hypotheses))))

(defun append-to-hypotheses (name new-hyps hypotheses)
  (if (equal name "")
      hypotheses
      (let ((result nil)
            (found  nil))
        (dolist (def hypotheses)
          (if (equal name (car def))
              (progn (setq found t)
                     (append-to result (cons name (list (append (cadr def) (list new-hyps))))))
            (append-to result def)))
        (unless found
          (append-to result (list name (list new-hyps))))
        result)))

(defun write-hypotheses ()
  "Write the hypothesis usage we've discovered to hypotheses-file, if set"
  (when hypotheses-file
    (with-temp-file hypotheses-file
      (erase-buffer)
      (insert (format-hypotheses proof-hypotheses)))))

(defun format-hypotheses (hyps)
  "Format the given hypotheses as a text string"
  (with-output-to-string
    (pp hyps)))
