;;; build-test-blog.el --- Build test blog with ky-publish. -*- lexical-binding: t -*-

;; Author: Kira Verhovyh <emacs@kyrella.xyz>
;; Maintainer: Kira Verhovyh <emacs@kyrella.xyz>
;; URL: https://github.com/kyrella/ky-publish
;; Version: 0.1.3
;; Package-Requires: ((emacs "29.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Setup packages for local build required by `ky-publish'. Build test blog.

;;; Code:

(require 'package)
(setq package-user-dir (expand-file-name ".packages"))
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))
(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)

(use-package denote
	:ensure t)

(use-package htmlize
  :ensure t)

(use-package gnuplot
	:ensure t)

(use-package org
	:config
	(org-babel-do-load-languages
	 'org-babel-load-languages
	 '((shell . t)
		 (gnuplot . t)
		 ;; (julia . t)
		 ;; (jupyter . t)
		 )))


(load-file "./ky-publish.el")

(defun get-site-projects ()
	`(,(append '("denote-pages") (ky-publish/make-denote-pages-plist))
		,(append '("denote-media") (ky-publish/make-denote-media-plist))))

(defun set-org-export-defaults ()
	(setq org-html-link-use-abs-url nil
				org-html-link-org-files-as-html t
				org-export-with-broken-links 'mark
				org-export-with-sub-superscripts nil
				org-html-html5-fancy t
				org-html-doctype "html5"))

(defun build-test-blog ()
	(setq
	 denote-directory (expand-file-name "./test-blog")
	 ky-publish/destination-directory "/tmp/build-test-blog"
	 ky-publish/backend 'ky-html)
	(message "Denote dir - %s" (denote-directory))
	(message "Output dir - %s" (ky-publish/destination-directory))
	(set-org-export-defaults)
	(ky-publish/publish (get-site-projects) t)
	(message "Done!"))
