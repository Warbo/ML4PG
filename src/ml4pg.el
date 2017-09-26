(require 'cl)

(unless (getenv "ML4PG_HOME")
  (error "ML4PG_HOME environment variable must be set"))

(defconst home-dir (let ((raw (getenv "ML4PG_HOME")))
                     (if (string= "/" (substring raw (1- (length raw))))
                         raw
                         (concat raw "/"))))

(defconst *weka-dir* (concat home-dir "weka.jar"))
(defvar *matlab-program* nil)
(defvar mode (getenv "ML4PG_TYPE"))

(defun load-els (dir)
  `(lambda (f)
     (load-file (concat home-dir ,dir "/" f (if (search ".el" f) "" ".el")))))

(defun ml4pg-load-coq ()
  (load-file (concat home-dir "coq/auxiliary_files.el"))
  (load-file (concat home-dir "coq/feature_extractionv2.el"))
  (load-file (concat home-dir "coq/matlab_interaction.el"))
  (load-file (concat home-dir "coq/shortcuts.el"))
  (load-file (concat home-dir "coq/menus.el"))
  (load-file (concat home-dir "coq/storage.el"))
  (load-file (concat home-dir "coq/save_lemmas.el"))
  (load-file (concat home-dir "coq/weka.el"))
  (load-file (concat home-dir "ssreflect/term-tree-definition.el"))
  (load-file (concat home-dir "ssreflect/term-tree-theorem.el"))
  (load-file (concat home-dir "ssreflect/extraction.el"))
  (load-file (concat home-dir "ssreflect/table-to-feature-vector.el"))
  (load-file (concat home-dir "ssreflect/weka-definitions.el"))
  (load-file (concat home-dir "ssreflect/storage-defs.el"))
  (load-file (concat home-dir "coq/automaton.el"))
  (load-file (concat home-dir "ssreflect/diagraph.el"))
  (load-file (concat home-dir "ssreflect/clusterdigraph.el"))
  (load-file (concat home-dir "ssreflect/trees.el")))

(defun ml4pg-load-ss ()
  (load-file (concat home-dir "ssreflect/auxiliary_files.el"))
  (load-file (concat home-dir "ssreflect/feature_extraction_2.el"))
  (load-file (concat home-dir "ssreflect/matlab_interaction.el"))
  (load-file (concat home-dir "ssreflect/shortcuts.el"))
  (load-file (concat home-dir "ssreflect/menus.el"))
  (load-file (concat home-dir "ssreflect/storage.el"))
  (load-file (concat home-dir "ssreflect/save_lemmas.el"))
  (load-file (concat home-dir "ssreflect/weka.el"))
  (load-file (concat home-dir "ssreflect/term-tree-definition.el"))
  (load-file (concat home-dir "ssreflect/term-tree-theorem.el"))
  (load-file (concat home-dir "ssreflect/extraction.el"))
  (load-file (concat home-dir "ssreflect/table-to-feature-vector.el"))
  (load-file (concat home-dir "ssreflect/weka-definitions.el"))
  (load-file (concat home-dir "ssreflect/storage-defs.el"))
  (load-file (concat home-dir "ssreflect/automaton.el"))
  (load-file (concat home-dir "ssreflect/diagraph.el"))
  (load-file (concat home-dir "ssreflect/clusterdigraph.el"))
  (load-file (concat home-dir "ssreflect/trees.el")))

(defun select-mode ()
  (interactive)
  (mapc (load-els "generic")
        (directory-files (concat home-dir "generic/") nil ".*\.el"))
  (unless (or noninteractive mode)
    (setq mode (case (read-string "What mode do you want to use (Coq -> c (default), SSReflect -> s, None -> n) : ")
                 ("s" "ssreflect")
                 ("n" nil)
                 (t   "coq"))))
  (cond ((string= mode "ssreflect") (ml4pg-load-ss))
        ((string= mode "n")         nil)
        (t                          (ml4pg-load-coq))))

(defun ml4pg-mode-aux ()
  (when noninteractive
    ;; Hack Proof General for noninteractive use
    (coq-build-prog-args)  ;; PG assumes coqtop will never run non-interactively
    (setq proof-shell-fiddle-frames nil)  ;; Don't alter non-existent windows
    (setq proof-three-window-enable nil)
    (add-hook 'proof-shell-handle-error-or-interrupt-hook 'ml4pg-bail-out)))

(defun ml4pg-mode ()
  (ml4pg-mode-aux)
  (select-mode))

(defun use-nix-if-present ()
  (dolist (path '("~/.nix-profile/share/emacs/site-lisp"
                  "/run/current-system/sw/share/emacs/site-lisp"))
    (when (and (file-exists-p path)
               (not (member path load-path)))
      (message "Adding %s to load path" path)
      (setq load-path (append load-path (list path))))))

(defun load-proof-general ()
  (unless (fboundp 'coq-build-prog-args)
    (message "Loading Proof General")
    (load "ProofGeneral/generic/proof-site")
    (with-temp-buffer
      (coq-mode))))

(defun test-msg (s)
  "Writes a message, only displaying it when verbose"
  (write-to-messages `(lambda ()
                        (insert ,s))))

(defun write-to-messages (f)
  "Run F in the context of a writable *Messages* buffer"
  ;; FIXME: Make a LISP variable, which initialises to this env var, so we can
  ;; override it from LISP without altering the environment
  (if (equal "t" (getenv "TEST_VERBOSE"))
      ;; Regular message output, including to minibuffer/stdout
      (message (with-temp-buffer
                 (funcall f)
                 (replace-regexp-in-string "%" "%%" (buffer-string))))
    ;; Only write the *Messages*, not to minibuffer/stdout
    (save-excursion
      (set-buffer "*Messages*")
      (goto-char (point-max))
      (let ((buffer-read-only nil))
        (funcall f)))))

(add-hook 'coq-mode-hook 'ml4pg-mode)
(use-nix-if-present)
(load-proof-general)
