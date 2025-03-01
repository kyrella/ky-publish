;;; ky-publish.el --- Static site generator based on Org/Denote. -*- lexical-binding: t -*-

;; Author: Kira Verhovyh <emacs@kyrella.xyz>
;; Maintainer: Kira Verhovyh <emacs@kyrella.xyz>
;; URL: https://github.com/kyrella/ky-publish
;; Version: 0.1.3
;; Package-Requires: ((emacs "29.1") (denote "3.1.0"))

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
;; Given a directory with `denote' notes publish a (subset) of them as a static site.
;; `ky-publish/publish' is the entry point, provided correctly setup Org Publish projects, it should
;; do the magic. See `ky-publish/make-denote-pages-plist' and friends for what correct settings look
;; like. Defaults for all defined custom variables are provided except for
;; `ky-publish/destination-directory', you must set it before publishing. For more information see
;; the repository - https://github.com/kyrella/ky-publish.

;;; Code:

(require 'ox)
(require 'ox-html)
(require 'ox-publish)
(require 'denote)

(defgroup ky-publish ()
	"Generate static  site from Denote directory with [slightly tweaked] Org publish system."
	:group 'applications
	:link '(url-link :tag "Homepage" "https://kyrella.xyz/denote-publish"))

(defcustom ky-publish/backend
	'ky-html
	"Export backend to use.

Will be picked up by `ky-publish/publish-denote-to-html', so
there is no need to override this function for a derived backend."
	:group 'ky-publish
	:package-version '(ky-publish . "0.1.0")
	:type 'symbol)

(defcustom ky-publish/destination-directory
	nil
	"Destination directory for generated site pages and resources.

Use the `ky-publish/destination-directory' function to get the value."
	:group 'ky-publish
	:package-version '(ky-publish . "0.1.0")
	:type 'directory)

(defun ky-publish/destination-directory ()
	"Return expanded path of `ky-publish/destination-directory' variable.
See variable documentation."
	(if ky-publish/destination-directory
			(directory-file-name (expand-file-name ky-publish/destination-directory))
		(user-error "Please provide value for `ky-publish/destination-directory'")))

(defcustom ky-publish/media-destination-dirname
	"media"
	"Directory for media resources under `ky-publish/destination-directory'.

This directory is only used for static resources that are either
linked as Denote resources in Org pages or included in
`org-publish-project-alist'. Resources that are generated from
Org SRC blocks are put under a page's directory, e.g.
<my_page_with_src_block>/generated-image1.png. See `ky-publish/dresource'.

Use `ky-publish/media-destination-directory' function to access the expanded path."
	:group 'ky-publish
	:package-version '(ky-publish . "0.1.0")
	:type 'string)

(defun ky-publish/media-destination-directory ()
	"Return expanded path of `ky-publish/media-destination-directory' variable.
See variable documentation."
	(file-name-concat (ky-publish/destination-directory) ky-publish/media-destination-dirname))

(defcustom ky-publish/styles-destination-dirname
	"styles"
	"Directory to use for global styles under `ky-publish/destination-directory'.

Use `ky-publish/styles-destination-directory' function to access the expanded value."
	:group 'ky-publish
	:package-version '(ky-publish . "0.1.0")
	:type 'directory)

(defun ky-publish/styles-destination-directory ()
	"Return expanded path of `ky-publish/styles-destination-directory' variable.
See variable documentation."
	(file-name-concat (ky-publish/destination-directory) ky-publish/styles-destination-dirname))

(defcustom ky-publish/denote-access-keyword
	"blog"
	"Denote keyword that marks files as safe for publishing.

Any denote file not containing the keyword will be marked as not
accessible, this also applies to denote links included in files.
The link behaviour depends on `org-export-with-broken-links'
variable."
	:group 'ky-publish
	:package-version '(ky-publish . "0.1.0")
	:type 'string)

(defcustom ky-publish/media-resource-regexp
	"\\png\\|\\jpg\\|\\gif"
	"This regexp should match resources that can be used as media on site pages."
	:group 'ky-publish
	:package-version '(ky-publish . "0.1.0")
	:type 'regexp)

(defun ky-publish/denote-media-regexp ()
	"Regexp to match media resources.

TODO: improve ext matching"
	(format "_%s.*\\.%s" ky-publish/denote-access-keyword ky-publish/media-resource-regexp))

(defun ky-publish/denote-page-regexp ()
	"Regexp to match site pages."
	(format "_%s.*\\.%s$" ky-publish/denote-access-keyword (or denote-file-type "org")))

(org-export-define-derived-backend 'ky-html 'html
  :translate-alist
  `((link . ky--publish/html-link)))

(defun ky--publish/html-link (link desc info)
  "Link transcoder for custom denote/file link handling.

See `org-html-link' for LINK/DESC/INFO description."
	(let* ((link-type (org-element-property :type link))
				 (link-path (org-element-property :path link))
				 (file-path (if (string= "denote" link-type)
												(denote-get-relative-path-by-id link-path)
											link-path))
				 (file-name (file-name-nondirectory file-path))
				 (file-ext (file-name-extension file-name))
				 (denote-file-title (denote-retrieve-filename-title file-path)))
		(pcase link-type
			("denote"
			 (let* ()
				 (pcase (ky--publish/classify-denote-file file-name)
					 ;; any page uses absolute URL e.g. `/page1'
					 ('page (ky--publish/make-link (format "/%s" denote-file-title) desc))
					 ;; any site resources go into shared resource directory e.g. `/media/<file>'
					 ('media (ky--publish/make-link
										(format "/%s/%s.%s"
														ky-publish/media-destination-dirname
														denote-file-title
														file-ext)
										desc))
					 ('no-access (ky--publish/handle-no-access-file file-path info))
					 (_ (ky--publish/handle-unknown-file file-path info)))))
 			("file"
			 (if denote-file-title
					 ;; If we match Denote extension (e.g. org) - assume it is a link to a post otherwise
					 ;; treat as a shared resource - set href to the resource directory. Links have to be
					 ;; relative, otherwise html backend will create a `file:' link. We don't want to handle
					 ;; potentially inlined resources, let 'html deal with this.
           ;;
					 ;; NOTE: perhaps mutating `link' is a bit dirty, but `org-element-copy' doesn't copy
					 ;; properties set on a link e.g. `ATTR_HTML'
					 (if (string= file-ext (or denote-file-type "org"))
							 (ky--publish/make-link (format "/%s" denote-file-title) desc)
						 (let ((publish-path (format "../%s/%s.%s"
																				 ky-publish/media-destination-dirname
																				 denote-file-title
																				 file-ext)))
							 (org-element-put-property link :path publish-path)
							 (org-export-data-with-backend link 'html info)))
				 ;; a link to a regular file
				 (let ((publish-dir (ky-publish/destination-directory)))
					 (if (file-in-directory-p file-path publish-dir)
							 ;; file is already in the publishing-dir, assume this is a dynamic resource generated
							 ;; by a page with `ky-publish/dresource', form links relative to containing page:
							 ;; <publish-dir>/<page>/<resource-path> -> ./<resource-path>
							 (let ((publish-path
											(apply
											 'file-name-concat
											 (cdr (file-name-split (file-relative-name file-path publish-dir))))))
								 (org-element-put-property link :path publish-path)
								 (org-export-data-with-backend link 'html info))
						 ;; otherwise bail out
						 (ky--publish/handle-unknown-file file-path info)))))
			(_ (org-export-data-with-backend link 'html info)))))

(defun ky--publish/classify-denote-file (file-name)
  "Determine how FILE-NAME should be published.
Returns one of the following: 'page, 'media, 'no-access,
nil"
  (when (denote-file-has-identifier-p file-name)
    (let ((classify (lambda (regexp)
                      (ky--publish/denote-file-accesible-p file-name regexp))))
      (cond
       ((funcall classify (ky-publish/denote-page-regexp)) 'page)
       ((funcall classify (ky-publish/denote-media-regexp)) 'media)
       ('no-access)))))

(defun ky-publish/filter-denote-files (regexp)
  "Get a list of denote formatted filenames filtered by REGEXP."
  (mapcar
   'denote-get-file-name-relative-to-denote-directory
   (denote-directory-files regexp)))

(defun ky--publish/denote-file-accesible-p (file-name regexp)
  "Use REGEXP to determine if FILE-NAME can be published.
See `ky-publish-vars.el' for REGEXP definitions."
  (member file-name (ky-publish/filter-denote-files regexp)))

;; TODO: handle IDs
(defun ky--publish/make-link (href desc)
  "Create <a> element pointing to HREF with description DESC."
	(format "<a href=\"%s\">%s</a>" href desc))

(defun ky--publish/handle-no-access-file (file-path info)
  "Handle no-access links according to settings in INFO.
FILE-PATH is a relative path to a file returned by Denote."
  (pcase (plist-get info :with-broken-links)
    (`nil (user-error "Unable to resolve link for: %s, no access" file-path))
    (`mark (format "<span class=\"no-access-link\">[NO ACCESS: %s]</span>" file-path))
    (_ nil)))

(defun ky--publish/handle-unknown-file (file-path info)
  "Handle links to unknown files according to settings in INFO.
FILE-PATH is a relative path to a file returned by Denote."
  (pcase (plist-get info :with-broken-links)
    (`nil (user-error "File does not match any type: %s" file-path))
    (`mark (format "<span class=\"unknown-link\">[UNKNOWN FILE: %s]</span>" file-path))
    (_ nil)))

(defun ky--publish/setup-publish-filename (orig-fn &rest args)
  "An override for `org-export-output-file-name'.
Instead of using full Denote-style filenames extract `title` part
and create <title>/index.html entries. <title> directory has to
be created here too as a side-effect, as Org Publish expects it
to exist. Since the resulting directory structure is flat,
<title> part of the filename is assumed to be unique.
ORIG-FUN/ARGS are the original function/args passed by
`advice-add'."
  (let* ((orig-res (apply orig-fn args))
				 (html-ext (string-remove-prefix "." (nth 0 args)))
				 (pub-dir (nth 2 args))
				 (denote-title (denote-retrieve-filename-title orig-res)))
    (if denote-title
				(let ((output-dir (file-name-concat pub-dir denote-title)))
					(make-directory output-dir t)
					(file-name-concat output-dir (concat "index." html-ext)))
			orig-res)))

(defun ky-publish/export-denote-to-html (&optional async subtreep visible-only body-only ext-plist)
  (interactive)
  (let* ((extension (concat
										 (when (> (length org-html-extension) 0) ".")
										 (or (plist-get ext-plist :html-extension)
												 org-html-extension
												 "html")))
				 (file (ky--publish/setup-publish-filename #'org-export-output-file-name extension subtreep))
				 (org-export-coding-system org-html-coding-system))
    (org-export-to-file 'ky-html file
      async subtreep visible-only body-only ext-plist)))

(defun ky-publish/publish-denote-to-html (plist filename pub-dir)
  (advice-add 'org-export-output-file-name :around #'ky--publish/setup-publish-filename)
	(org-publish-org-to ky-publish/backend filename
											(concat (when (> (length org-html-extension) 0) ".")
															(or (plist-get plist :html-extension)
																	org-html-extension
																	"html"))
											plist pub-dir)
  (advice-remove  'org-export-output-file-name #'ky--publish/setup-publish-filename))

(defun ky-publish/publish-denote-media (_plist filename pub-dir)
	"Publish a denote file as a media resource.

FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.

Return title.ext part of the filename."
  (unless (file-directory-p pub-dir)
    (make-directory pub-dir t))
  (let* ((denote-title (denote-retrieve-filename-title filename))
				 (file-ext (file-name-extension filename))
				 (output (expand-file-name
									(file-name-nondirectory (format "%s.%s" denote-title file-ext))
									pub-dir)))
    (unless (file-equal-p (expand-file-name (file-name-directory filename))
													(file-name-as-directory (expand-file-name pub-dir)))
      (copy-file filename output t))
    output))

(defun ky-publish/make-denote-pages-plist ()
	`(
		:base-directory ,(denote-directory)
		:base-extension ,(or denote-file-type "org")
		:publishing-directory ,(ky-publish/destination-directory)
		:publishing-function ky-publish/publish-denote-to-html
		:exclude ".*"
		:include ,(ky-publish/filter-denote-files (ky-publish/denote-page-regexp))
		:sitemap-filename "index.org"
		:sitemap-style list
		:auto-sitemap t))
(defun ky-publish/make-denote-media-plist ()
	"Minimal property setup for publishing non-page Denote files are resources."
	`(
		:base-directory ,(denote-directory)
    :base-extension ,ky-publish/media-resource-regexp
		:publishing-directory ,(ky-publish/media-destination-directory)
		:publishing-function ky-publish/publish-denote-media
    :exclude ".*"
    :include ,(ky-publish/filter-denote-files (ky-publish/denote-media-regexp))))
(defun ky-publish/make-styles-plist (rel-src-dir)
	"Minimal property setup for publishing style files, CSS and so on."
	`(
    :base-directory ,(file-name-concat (denote-directory) rel-src-dir)
    :base-extension "css"
    :publishing-directory ,(ky-publish/styles-destination-directory)
    :publishing-function org-publish-attachment
    :recursive t))

(defun ky-publish/make-media-plist (rel-src-dir)
	"Minimal property setup for publishing media files."
	`(
    :base-directory ,(file-name-concat (denote-directory) rel-src-dir)
    :base-extension ,ky-publish/media-resource-regexp
    :publishing-directory ,(ky-publish/media-destination-directory)
    :publishing-function org-publish-attachment
    :recursive t))

(defun ky-publish/make-web-settings-plist (rel-src-dir)
	"Minimal property setup for publishing any other required files, robots.txt etc"
	`(
    :base-directory ,(file-name-concat (denote-directory) rel-src-dir)
    :base-extension any
    :publishing-directory ,(ky-publish/destination-directory)
    :publishing-function org-publish-attachment
    :recursive t))

(defun ky-publish/dresource (file-name &optional fallback)
	"Can be used to generate :file param for Babel SRC blocks.

If export backend matches one we defined and the current buffer is
a denote page, generate filename as `<page_name>/FILE-NAME' in
the `:publishing-directory', `ky--publish/html-link' will set
links accordingly. In all other cases fallback to default SRC
block behaviour with :file set to FALLBACK."
	(let ((backend (when (boundp 'org-export-current-backend) org-export-current-backend)))
		(if (eq ky-publish/backend backend)
				(when-let* ((buffer-name (buffer-file-name))
										(parent-dir (denote-retrieve-filename-title buffer-name))
										(out-dir (file-name-concat (ky-publish/destination-directory) parent-dir))
										(file (file-name-concat out-dir file-name)))
					(make-directory (file-name-parent-directory file) t)
					file)
			fallback)))

(provide 'ky-publish)
;;; ky-publish.el ends here
