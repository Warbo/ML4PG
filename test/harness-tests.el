(ert-deftest ml4pg-test-with-defines-tests ()
  "Make sure our testing macro actually defines tests"
  ;; Make sure our example isn't defined yet
  (ert-delete-test 'ml4pg-macro-test)
  (should-not (ert-test-boundp 'ml4pg-macro-test))

  ;; Define an example test then check it exists
  (test-with macro-test
    "Testing the test-with macro"
    (lambda () '(t))
    (lambda (x) (should x)))

  (should (ert-test-boundp 'ml4pg-macro-test))

  ;; Clean up
  (ert-delete-test 'ml4pg-macro-test)
  (should-not (ert-test-boundp 'ml4pg-macro-test)))

(ert-deftest ml4pg-test-with-passes-tests ()
  "Make sure tests defined by our macro can pass"
  (test-with macro-test
    "Testing the test-with macro"
    (lambda () '(t))
    (lambda (x) (should x)))

  (should (ert-test-passed-p (ml4pg-run-test)))

  (ert-delete-test 'ml4pg-macro-test))

(ert-deftest ml4pg-test-with-fails-tests ()
  "Make sure tests defined by our macro can fail"
  (test-with macro-test
    "Testing a failing test"
    (lambda () '(nil))
    (lambda (x) (should x)))

  (should (ert-test-failed-p (let ((ert-debug-on-error nil)
                                   (debug-on-error     nil))
                               (ml4pg-run-test))))

  (ert-delete-test 'ml4pg-macro-test))

(ert-deftest ml4pg-test-with-runs-multiple ()
  "Make sure tests defined by our macro are run multiple times, with different
   generated arguments each time."
  (test-with macro-test
    "Testing iteration"
    (lambda () (list iteration))
    (lambda (gen-it)
      (ml4pg-test-accumulate (cons gen-it iteration))))

  (let ((ml4pg-test-accumulator nil))
    (ml4pg-run-test)
    (should (equal (length ml4pg-test-accumulator) test-iterations))
    (dotimes (i test-iterations)
      (should (member (cons i i) ml4pg-test-accumulator))))

  (ert-delete-test 'ml4pg-macro-test))

(test-with simplify-numbers
   "Make sure numbers get smaller"
   (lambda ()
     (let ((n (gen-num)))
       (list n (ml4pg-simplify-data n))))
   (lambda (n alts)
     (dolist (alt alts nil)
       (should (simpler alt n)))))

(test-with simplify-lists
  "Lists get simpler"
  (lambda ()
    (let ((lst (gen-list 'gen-num)))
      (list lst (ml4pg-simplify-data lst))))
  (lambda (lst alts)
    (dolist (alt alts nil)
      (should (simpler alt lst)))))
