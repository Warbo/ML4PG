(defun extract-feature-theorems ()
  (interactive)
  (setq proof-hypotheses nil)
  (condition-case err
      (extract-feature-theorems-aux)
    (error (message "ERROR: %S" err)))
  (write-hypotheses))
