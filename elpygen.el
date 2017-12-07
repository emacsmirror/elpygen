;;; -*- lexical-binding: t; -*-

(require 'yasnippet)
(require 'python)

(require 'cl)
(require 'subr-x)

(defconst elpygen-varname-re "[a-zA-Z]\\w*")

(defconst elpygen-funcall-re "[[:alnum:]_.]*[[:space:]]*(")

(defconst elpygen-function-template "def ${1:`fun`}(${2:`args`}):
    ${0:pass}
")

(defun elpygen-implement ()
  (interactive)
  (when (python-syntax-comment-or-string-p)
    (user-error "Cannot extract symbols in comments/strings "))
  (when (not (looking-at-p elpygen-funcall-re))
    (user-error "This doesn't look like a function/method call"))
  (when-let (name (elpygen-get-def-name))
    (if (elpygen-symbol-method-p name)
        (elpygen-implement-method name)
      (elpygen-implement-function name))))

(defun elpygen-symbol-method-p (symbol-name)
  (string-prefix-p "self." symbol-name t))

(defun elpygen-implement-function (name)
  (let ((arglist (elpygen-get-arglist)))
    (elpygen-prepare-function-insert-point)
    (elpygen-insert-template name arglist)))

(defun elpygen-implement-method (name)
  (let ((arglist (elpygen-get-arglist)))
    (elpygen-prepare-method-insert-point)
    (elpygen-insert-template (seq-subseq name 5)
                             (cons "self" arglist))))


(defun elpygen-insert-template (name arglist)
  (yas-expand-snippet elpygen-function-template nil nil
                      `((fun ,name)
                        (args ,(elpygen-format-args arglist)))))

(defun elpygen-get-def-name ()
  (with-syntax-table python-dotty-syntax-table
    (when-let ((funname (thing-at-point 'symbol)))
      (substring-no-properties funname))))

(defun elpygen-get-arglist ()
  (save-excursion
    (with-syntax-table python-dotty-syntax-table
      (when (symbol-at-point)
        (end-of-thing 'symbol)
        (skip-chars-forward "[:blank:]")
        (when (looking-at-p "(")
          (when-let (sexp (thing-at-point 'sexp))
            (elpygen-parse-arg-str sexp)))))))

(defun elpygen-parse-arg-str (arg-str)
  (split-string (substring-no-properties arg-str 1 -1)
                "," t split-string-default-separators))

(defun elpygen-format-args (arg-list)
  (let ((counter 0))
    (cl-flet
        ((format-arg (arg)
                     (if (string-match-p elpygen-varname-re arg)
                         arg
                       (incf counter)
                       (concat "arg" (number-to-string counter)))))
      (string-join (mapcar #'format-arg arg-list) ", "))))

(defun elpygen-prepare-function-insert-point ()
  (while (not (equal 0 (current-indentation)))
    (if (python-info-current-defun)
        (end-of-defun)
      (python-nav-end-of-block)))
  (beginning-of-line)
  (open-line 2))

(defun elpygen-prepare-method-insert-point ()
  (end-of-defun)
  (open-line 1)
  (python-indent-line-function))


(provide 'elpygen)
