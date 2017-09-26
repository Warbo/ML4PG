(defun ml4pg-reload (type)
  (load (concat (if (boundp 'home-dir)
                    home-dir
                    (getenv "ML4PG_HOME"))
                "/ml4pg.el"))
  (select-mode))

(defun ml4pg-in-test-dir (x)
  (when (equal "" (getenv "ML4PG_TEST"))
    (error "No ML4PG_TEST env var set; this should be the 'test/' dir of ML4PG"))

  (concat (getenv "ML4PG_TEST") "/" x))

(defun ml4pg-load-tests (type)
  (mapcar  (lambda (f) (load (ml4pg-in-test-dir f)))
           '("harness.el" "generators.el"))
  (let ((load-test `(lambda (f) (load  (ml4pg-in-test-dir
                                                (concat ,type "/" f))))))
    (mapcar load-test (directory-files (ml4pg-in-test-dir type)
                                       nil
                                       ".*-tests\.el"))))

(defun ml4pg-run-tests (&optional test)
  (interactive)
  (let ((debug-on-error t))
    (funcall (if noninteractive 'ert-run-tests-batch 'ert) (or test "^ml4pg-"))))

(defun ml4pg-reload-and-test (type &optional test)
  (interactive)
  (ml4pg-reload type)
  (ml4pg-load-tests type)
  (ml4pg-run-tests test))

(setenv "ML4PG_TYPE" (or (getenv "ML4PG_TYPE") (getenv "TEST_SUITE") "coq"))
(ml4pg-reload-and-test (getenv "ML4PG_TYPE") (getenv "ML4PG_TEST_PATTERN"))
