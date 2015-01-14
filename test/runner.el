(defun ml4pg-reload ()
  (load (concat (if (boundp 'home-dir)
                    home-dir
                  (getenv "ML4PG_HOME"))
                "ml4pg.el"))
  (ml4pg-load-coq))

(defun ml4pg-load-tests ()
  (let ((load-test     (lambda (f) (load (concat home-dir "test/" f)))))
    (mapcar load-test '("harness.el" "generators.el"))
    (mapcar load-test (directory-files (concat home-dir "test/")
                                       nil
                                       ".*-tests\.el"))))

(defun ml4pg-run-tests ()
  (interactive)
  (let ((debug-on-error t))
    (funcall (if noninteractive 'ert-run-tests-batch 'ert) "^ml4pg-")))

(defun ml4pg-reload-and-test ()
  (interactive)
  (ml4pg-reload)
  (ml4pg-load-tests)
  (ml4pg-run-tests))

(ml4pg-reload-and-test)
