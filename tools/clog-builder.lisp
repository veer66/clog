;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; CLOG Builder - UI Design tool for CLOG                                ;;;;
;;;; (c) 2020-2024 David Botton                                            ;;;;
;;;; License BSD 3 Clause                                                  ;;;;
;;;;                                                                       ;;;;
;;;; clog-buider.lisp                                                      ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :clog-tools)

(defparameter *start-project* nil)
(defparameter *start-dir* nil)
(defparameter *client-side-movement* nil)

;; Per instance app data

(defclass builder-app-data ()
  ((copy-buf
    :accessor copy-buf
    :initform nil
    :documentation "Copy buffer")
   (copy-history-win
    :accessor copy-history-win
    :initform nil
    :documentation "Copy history window")
   (next-panel-id
    :accessor next-panel-id
    :initform 0
    :documentation "Next new panel id")
   (current-control
    :accessor current-control
    :initform nil
    :documentation "Current selected control")
   (select-tool
    :accessor select-tool
    :initform nil
    :documentation "Select tool")
   (properties-list
    :accessor properties-list
    :initform nil
    :documentation "Property list in properties window")
   (current-project
    :accessor current-project
    :initform *start-project*
    :documentation "Current Project")
   (current-project-dir
    :accessor current-project-dir
    :initform ""
    :documentation "Current Project")
   (project-win
    :accessor project-win
    :initform nil
    :documentation "Project window")
   (right-panel
    :accessor right-panel
    :initform nil
    :documentation "Right panel")
   (left-panel
    :accessor left-panel
    :initform nil
    :documentation "Left panel")
   (control-properties-win
    :accessor control-properties-win
    :initform nil
    :documentation "Current control properties window")
   (events-list
    :accessor events-list
    :initform nil
    :documentation "Event list in events window")
   (event-editor
    :accessor event-editor
    :initform nil
    :documentation "Editor in events window")
   (events-js-list
    :accessor events-js-list
    :initform nil
    :documentation "JS Event list in events window")
   (event-js-editor
    :accessor event-js-editor
    :initform nil
    :documentation "JS Editor in events window")
   (events-ps-list
    :accessor events-ps-list
    :initform nil
    :documentation "ParenScript Event list in events window")
   (event-ps-editor
    :accessor event-ps-editor
    :initform nil
    :documentation "PS Editor in events window")
   (auto-complete-configured
    :accessor auto-complete-configured
    :initform nil
    :documentation "Auto complete is setup once per instance")
   (current-editor-is-lisp
    :accessor current-editor-is-lisp
    :initform nil
    :documentation "Turn or off swank autocomplete")
   (control-events-win
    :accessor control-events-win
    :initform nil
    :documentation "Current control events window")
   (control-js-events-win
    :accessor control-js-events-win
    :initform nil
    :documentation "Current control events window")
   (control-ps-events-win
    :accessor control-ps-events-win
    :initform nil
    :documentation "Current control events window")
   (control-list-win
    :accessor control-list-win
    :initform nil
    :documentation "Current control list window")
   (control-pallete-win
    :accessor control-pallete-win
    :initform nil
    :documentation "Current control pallete window")
   (control-lists
    :accessor control-lists
    :initform (make-hash-table* :test #'equalp)
    :documentation "Panel -> Control List - hash table")))

;; Control Record Utilities / Plugin Controls API

(defun control-info (control-type-name)
  "Return the control-record for CONTROL-TYPE-NAME from supported controls. (Exported)"
  (if (equal control-type-name "clog-data")
       `(:name           "clog-data"
         :description    "Panel Properties"
         :events         nil
         :properties     ((:name "panel name"
                           :attr "data-clog-name")
                          (:name "in-package"
                           :attr "data-in-package")
                          (:name "custom slots"
                           :attr "data-custom-slots")
                          (:name "width"
                           :get  ,(lambda (control) (width control))
                           :setup :read-only)
                          (:name "height"
                           :setup :read-only
                           :get  ,(lambda (control) (height control)))))
      (find-if (lambda (x) (equal (getf x :name) control-type-name)) *supported-controls*)))

(defun add-supported-controls (control-records)
  "Add a list of control-records to builder's supported controls. If control exists it is
replaced. (Exported)"
  (dolist (r control-records)
    (setf *supported-controls*
          (append (remove-if (lambda (x)
                               (unless (equalp (getf x :name) "group")
                                 (equal (getf x :name) (getf r :name))))
                             *supported-controls*)
                  (list r)))))

(defun reset-control-pallete (panel)
  (let* ((app (connection-data-item panel "builder-app-data"))
         (pallete (select-tool app)))
    (setf (inner-html pallete) "")
    (dolist (control *supported-controls*)
      (if (equal (getf control :name) "group")
          (add-select-optgroup pallete (getf control :description))
          (add-select-option pallete (getf control :name) (getf control :description))))))

;; Population of utility windows

(defun on-populate-control-events-win (obj)
  "Populate the control events for the current control"
  (let* ((app       (connection-data-item obj "builder-app-data"))
         (event-win (control-events-win app))
         (elist     (events-list app))
         (control   (current-control app)))
    (when event-win
      (set-on-blur (event-editor app) nil)
      (set-on-change elist nil)
      (setf (inner-html elist) "")
      (remove-attribute elist "data-current-event")
      (setf (text-value (event-editor app)) "")
      (setf (clog-ace:read-only-p (event-editor app)) t)
      (when control
        (let ((info (control-info (attribute control "data-clog-type"))))
          (labels ((populate-options (&key (current ""))
                     (set-on-change elist nil)
                     (setf (inner-html elist) "")
                     (add-select-option elist "" "Select Event")
                     (dolist (event (getf info :events))
                       (let ((attr (format nil "data-~A" (getf event :name))))
                         (add-select-option elist
                                            (getf event :name)
                                            (format nil "~A ~A (panel ~A)"
                                                    (if (has-attribute control attr)
                                                        "&#9632;‎ "
                                                        "&#9633; ")
                                                    (getf event :name)
                                                    (getf event :parameters))
                                            :selected (equal attr current))))
                     (set-on-change elist #'on-change))
                   (on-blur (obj)
                     (declare (ignore obj))
                     (set-on-blur (event-editor app) nil)
                     (let ((attr (attribute elist "data-current-event")))
                       (unless (equalp attr "undefined")
                         (let ((opt (select-text elist))
                               (txt (text-value (event-editor app))))
                           (setf (char opt 0) #\space)
                           (setf opt (string-left-trim "#\space" opt))
                           (cond ((or (equal txt "")
                                      (equalp txt "undefined"))
                                  (setf (select-text elist) (format nil "~A ~A" (code-char 9633) opt))
                                  (remove-attribute control attr))
                                 (t
                                  (setf (select-text elist) (format nil "~A ~A" (code-char 9632) opt))
                                  (setf (attribute control attr) txt))))
                         (jquery-execute (get-placer control) "trigger('clog-builder-snap-shot')")))
                     (set-on-blur (event-editor app) #'on-blur))
                   (on-change (obj)
                     (declare (ignore obj))
                     (set-on-blur (event-editor app) nil)
                     (let ((event (select-value elist "clog-events")))
                       (cond ((equal event "")
                              (set-on-blur (event-editor app) nil)
                              (remove-attribute elist "data-current-event")
                              (setf (text-value (event-editor app)) "")
                              (setf (clog-ace:read-only-p (event-editor app)) t))
                             (t
                              (setf (clog-ace:read-only-p (event-editor app)) nil)
                              (let* ((attr (format nil "data-~A" event))
                                     (txt  (attribute control attr)))
                                (setf (text-value (event-editor app))
                                      (if (equalp txt "undefined")
                                          ""
                                          txt))
                                (setf (attribute elist "data-current-event") attr)
                                (set-on-blur (event-editor app) #'on-blur)))))))
            (populate-options))))))
  (on-populate-control-ps-events-win obj)
  (on-populate-control-js-events-win obj))

(defun on-populate-control-js-events-win (obj)
  "Populate the control js events for the current control"
  (let* ((app       (connection-data-item obj "builder-app-data"))
         (event-win (control-js-events-win app))
         (elist     (events-js-list app))
         (control   (current-control app)))
    (when event-win
      (set-on-blur (event-js-editor app) nil)
      (set-on-change elist nil)
      (setf (inner-html elist) "")
      (remove-attribute elist "data-current-js-event")
      (setf (text-value (event-js-editor app)) "")
      (setf (clog-ace:read-only-p (event-js-editor app)) t)
      (when control
        (let ((info (control-info (attribute control "data-clog-type"))))
          (labels ((populate-options (&key (current ""))
                     (set-on-change elist nil)
                     (setf (inner-html elist) "")
                     (add-select-option elist "" "Select JS Event")
                     (dolist (event (getf info :events))
                       (when (getf event :js-event)
                         (let ((attr (format nil "~A" (getf event :js-event))))
                           (add-select-option elist
                                              (getf event :js-event)
                                              (format nil "~A ~A"
                                                      (if (has-attribute control attr)
                                                          "&#9632;‎ "
                                                          "&#9633; ")
                                                      (getf event :js-event))
                                              :selected (equal attr current)))))
                     (set-on-change elist #'on-change))
                   (on-blur (obj)
                     (declare (ignore obj))
                     (set-on-blur (event-js-editor app) nil)
                     (let ((attr (attribute elist "data-current-js-event")))
                       (unless (equalp attr "undefined")
                         (let ((opt (select-text elist))
                               (txt (text-value (event-js-editor app))))
                           (setf (char opt 0) #\space)
                           (setf opt (string-left-trim "#\space" opt))
                           (cond ((or (equal txt "")
                                      (equalp txt "undefined"))
                                  (setf (select-text elist) (format nil "~A ~A" (code-char 9633) opt))
                                  (remove-attribute control attr))
                                 (t
                                  (setf (select-text elist) (format nil "~A ~A" (code-char 9632) opt))
                                  (setf (attribute control attr) txt))))
                         (jquery-execute (get-placer control) "trigger('clog-builder-snap-shot')")))
                     (set-on-blur (event-js-editor app) #'on-blur))
                   (on-change (obj)
                     (declare (ignore obj))
                     (set-on-blur (event-js-editor app) nil)
                     (let ((event (select-value elist "clog-js-events")))
                       (cond ((equal event "")
                              (set-on-blur (event-js-editor app) nil)
                              (remove-attribute elist "data-current-js-event")
                              (setf (text-value (event-js-editor app)) "")
                              (setf (clog-ace:read-only-p (event-js-editor app)) t))
                             (t
                              (setf (clog-ace:read-only-p (event-js-editor app)) nil)
                              (let* ((attr (format nil "~A" event))
                                     (txt  (attribute control attr)))
                                (setf (text-value (event-js-editor app))
                                      (if (equalp txt "undefined")
                                          ""
                                          txt))
                                (setf (attribute elist "data-current-js-event") attr)
                                (set-on-blur (event-js-editor app) #'on-blur)))))))
            (populate-options)))))))

(defun on-populate-control-ps-events-win (obj)
  "Populate the control ps events for the current control"
  (let* ((app       (connection-data-item obj "builder-app-data"))
         (event-win (control-ps-events-win app))
         (elist     (events-ps-list app))
         (control   (current-control app)))
    (when event-win
      (set-on-blur (event-ps-editor app) nil)
      (set-on-change elist nil)
      (setf (inner-html elist) "")
      (remove-attribute elist "data-current-ps-event")
      (setf (text-value (event-ps-editor app)) "")
      (setf (clog-ace:read-only-p (event-ps-editor app)) t)
      (when control
        (let ((info (control-info (attribute control "data-clog-type"))))
          (labels ((populate-options (&key (current ""))
                     (set-on-change elist nil)
                     (setf (inner-html elist) "")
                     (add-select-option elist "" "Select JS Event for ParenScript")
                     (dolist (event (getf info :events))
                       (when (getf event :js-event)
                         (let ((attr (format nil "~A" (getf event :js-event))))
                           (add-select-option elist
                                              (getf event :js-event)
                                              (format nil "~A ~A"
                                                      (if (has-attribute control attr)
                                                          "&#9632;‎ "
                                                          "&#9633; ")
                                                      (getf event :js-event))
                                              :selected (equal attr current)))))
                     (set-on-change elist #'on-change))
                   (on-blur (obj)
                     (declare (ignore obj))
                     (set-on-blur (event-ps-editor app) nil)
                     (let* ((attr    (attribute elist "data-current-ps-event"))
                            (ps-attr (format nil "data-ps-~A" attr)))
                       (unless (equalp attr "undefined")
                         (let ((opt (select-text elist))
                               (txt (text-value (event-ps-editor app))))
                           (setf (char opt 0) #\space)
                           (setf opt (string-left-trim "#\space" opt))
                           (cond ((or (equal txt "")
                                      (equalp txt "undefined"))
                                  (setf (select-text elist) (format nil "~A ~A" (code-char 9633) opt))
                                  (remove-attribute control ps-attr)
                                  (remove-attribute control attr))
                                 (t
                                  (setf (select-text elist) (format nil "~A ~A" (code-char 9632) opt))
                                  (setf (attribute control ps-attr) txt)
                                  (let ((ss (make-string-input-stream txt)))
                                    (setf (attribute control attr) (ps:ps-compile-stream ss)))))
                         (jquery-execute (get-placer control) "trigger('clog-builder-snap-shot')"))))
                     (set-on-blur (event-ps-editor app) #'on-blur))
                   (on-change (obj)
                     (declare (ignore obj))
                     (set-on-blur (event-ps-editor app) nil)
                     (let ((event (select-value elist "clog-ps-events")))
                       (cond ((equal event "")
                              (set-on-blur (event-ps-editor app) nil)
                              (remove-attribute elist "data-current-ps-event")
                              (setf (text-value (event-ps-editor app)) "")
                              (setf (clog-ace:read-only-p (event-ps-editor app)) t))
                             (t
                              (setf (clog-ace:read-only-p (event-ps-editor app)) nil)
                              (let* ((attr    (format nil "~A" event))
                                     (ps-attr (format nil "data-ps-~A" attr))
                                     (txt     (attribute control ps-attr)))
                                (setf (text-value (event-ps-editor app))
                                      (if (equalp txt "undefined")
                                          ""
                                          txt))
                                (setf (attribute elist "data-current-ps-event") attr)
                                (set-on-blur (event-ps-editor app) #'on-blur)))))))
            (populate-options)))))))

(defun on-populate-control-properties-win (obj &key win)
  "Populate the control properties for the current control"
  ;; obj if current-control is nil must be content
  (with-sync-event (obj)
    (bordeaux-threads:make-thread (lambda () (on-populate-control-events-win obj)))
    (let ((app (connection-data-item obj "builder-app-data")))
      (let* ((prop-win (control-properties-win app))
             (control  (if (current-control app)
                           (current-control app)
                           obj))
             (placer   (when control
                         (get-placer control)))
             (table    (properties-list app)))
        (when prop-win
          (setf (inner-html table) "")
          (let ((info (control-info (attribute control "data-clog-type")))
                props)
            (dolist (prop (reverse (getf info :properties)))
              (cond ((eq (third prop) :style)
                     (push `(,(getf prop :name) ,(style control (getf prop :style)) ,(getf prop :setup)
                             ,(lambda (obj)
                                (setf (style control (getf prop :style)) (text obj))))
                           props))
                    ((or (eq (third prop) :get)
                         (eq (third prop) :set)
                         (eq (third prop) :setup))
                     (push `(,(getf prop :name) ,(when (getf prop :get)
                                                   (funcall (getf prop :get) control))
                             ,(getf prop :setup)
                             ,(lambda (obj)
                                (when (getf prop :set)
                                  (funcall (getf prop :set) control obj))))
                           props))
                    ((eq (third prop) :prop)
                     (push `(,(getf prop :name) ,(property control (getf prop :prop)) ,(getf prop :setup)
                             ,(lambda (obj)
                                (setf (property control (getf prop :prop)) (text obj))))
                           props))
                    ((eq (third prop) :attr)
                     (push `(,(getf prop :name) ,(attribute control (getf prop :attr)) ,(getf prop :setup)
                             ,(lambda (obj)
                                (setf (attribute control (getf prop :attr)) (text obj))))
                           props))
                    (t (print "Configuration error."))))
            (when (current-control app)
              (let* (panel-controls
                     (cname    (attribute control "data-clog-name"))
                     (panel-id (attribute placer "data-panel-id"))
                     (panel    (attach-as-child obj panel-id)))
                (maphash (lambda (k v)
                           (declare (ignore k))
                           (let ((n (attribute v "data-clog-name"))
                                 (p (attribute (parent-element v) "data-clog-name")))
                             (unless (or (equal cname n)
                                         (equal cname p))
			       (push n panel-controls))))
                         (get-control-list app panel-id))
                (push (attribute panel "data-clog-name") panel-controls)
                (push
                 `("parent"  nil
                             ,(lambda (control td1 td2)
                                (declare (ignore td1))
                                (let ((dd (create-select td2))
                                      (v  (attribute (parent-element control) "data-clog-name")))
                                  (set-geometry dd :width "100%")
                                  (add-select-options dd panel-controls)
                                  (setf (value dd) v)
                                  (set-on-change dd
                                   (lambda (obj)
                                     (place-inside-bottom-of
                                      (attach-as-child control
                                                       (js-query
                                                        control
                                                        (format nil "$(\"[data-clog-name='~A']\").attr('id')"
                                                                (value obj))))
                                      control)
                                     (place-after control placer)
                                     (on-populate-control-list-win panel :win win))))
                                nil)
                             nil)
                 props)
                (push
                 `("name"    ,cname
                             nil
                             ,(lambda (obj)
                                (let ((vname (text obj)))
                                  (unless (equal vname "")
                                    (when (equal (subseq vname 0 1) "(")
                                      (setf vname (format nil "|~A|" vname)))
                                    (setf (attribute control "data-clog-name") vname)
                                    (when (equal (getf info :name) "clog-data")
                                      (when win
                                        (setf (window-title win) vname)))))))
                 props)))
            (dolist (item props)
              (let* ((tr  (create-table-row table))
                     (td1 (create-table-column tr :content (first item)))
                     (td2 (if (second item)
                              (create-table-column tr :content (second item))
                              (create-table-column tr))))
                (setf (width td1) "30%")
                (setf (width td2) "70%")
                (setf (spellcheckp td2) nil)
                (set-border td1 "1px" :dotted :black)
                (cond ((third item)
                       (unless (eq (third item) :read-only)
                         (setf (editablep td2) (funcall (third item) control td1 td2))))
                      (t
                       (setf (editablep td2) t)))
                (set-on-blur td2
                             (lambda (obj)
                               (funcall (fourth item) obj)
                               (when placer
                                 (jquery-execute placer "trigger('clog-builder-snap-shot')")
                                 (set-geometry placer :top (position-top control)
                                                      :left (position-left control)
                                                      :width (client-width control)
                                                      :height (client-height control)))))))))))))

(defun on-populate-control-list-win (content &key win)
  "Populate the control-list-window to allow drag and drop adjust of order
of controls and double click to select control."
  (with-sync-event (content)
    (let ((app (connection-data-item content "builder-app-data")))
      (let ((panel-id (html-id content))
            (last-ctl nil))
        (when (control-list-win app)
          (let ((lwin (control-list-win app)))
            (setf (inner-html lwin) "")
            (set-on-mouse-click (create-div lwin :content (attribute content "data-clog-name"))
                                (lambda (obj data)
                                  (declare (ignore obj data))
                                  (deselect-current-control app)
                                  (on-populate-control-properties-win content :win win)
                                  (on-populate-control-list-win content :win win)))
            (labels ((add-siblings (control sim)
                       (let (dln dcc)
                         (loop
                           (when (equal (html-id control) "undefined") (return))
                           (setf dcc (attribute control "data-clog-composite-control"))
                           (setf dln (attribute control "data-clog-name"))
                           (unless (equal dln "undefined")
                             (let ((list-item (create-div lwin :content (format nil "&#8597; ~A~A" sim dln)))
                                   (status    (hiddenp (get-placer control))))
                               (if status
                                   (setf (color list-item) :darkred)
                                   (setf (background-color list-item) :grey))
                               (setf (draggablep list-item) t)
                               (setf (attribute list-item "data-clog-control") (html-id control))
                               ;; click to select item
                               (set-on-mouse-down list-item
                                                  (lambda (obj data)
                                                    (let* ((html-id (attribute obj "data-clog-control"))
                                                           (control (get-from-control-list app
                                                                                           panel-id
                                                                                           html-id)))
                                                      (cond ((or (getf data :shift-key)
                                                                 (getf data :ctrl-key)
                                                                 (getf data :meta-key))
                                                             (when (drop-new-control app content data)
                                                               (incf-next-id content)))
                                                            (t
                                                             (when last-ctl
                                                               (set-border last-ctl "0px" :dotted :blue))
                                                             (set-border list-item "2px" :dotted :blue)
                                                             (setf last-ctl list-item)
                                                             (select-control control))))))
                               (set-on-double-click list-item
                                                    (lambda (obj)
                                                      (let* ((html-id (attribute obj "data-clog-control"))
                                                             (control (get-from-control-list app
                                                                                             panel-id
                                                                                             html-id))
                                                             (placer  (get-placer control))
                                                             (state   (hiddenp placer)))
                                                        (setf (hiddenp placer) (not state))
                                                        (select-control control)
                                                        (on-populate-control-list-win content :win win))))
                               ;; drag and drop to change
                               (set-on-drag-over list-item (lambda (obj)(declare (ignore obj))()))
                               (set-on-drop list-item
                                            (lambda (obj data)
                                              (let* ((id       (attribute obj "data-clog-control"))
                                                     (control1 (get-from-control-list app
                                                                                      panel-id
                                                                                      id))
                                                     (control2 (get-from-control-list app
                                                                                      panel-id
                                                                                      (getf data :drag-data)))
                                                     (placer1  (get-placer control1))
                                                     (placer2  (get-placer control2)))
                                                (if (getf data :shift-key)
                                                    (place-inside-bottom-of control1 control2)
                                                    (place-before control1 control2))
                                                (place-after control2 placer2)
                                                (set-geometry placer1 :top (position-top control1)
                                                                      :left (position-left control1)
                                                                      :width (client-width control1)
                                                                      :height (client-height control1))
                                                (set-geometry placer2 :top (position-top control2)
                                                                      :left (position-left control2)
                                                                      :width (client-width control2)
                                                                      :height (client-height control2))
                                                (on-populate-control-properties-win content :win win)
                                                (on-populate-control-list-win content :win win))))
                               (set-on-drag-start list-item (lambda (obj)(declare (ignore obj))())
                                                  :drag-data (html-id control))
                               (when (equal dcc "undefined") ; when t is not a composite control
                                 (add-siblings (first-child control) (format nil "~A&#8594;" sim)))))
                           (setf control (next-sibling control))))))
              (add-siblings (first-child content) ""))))))))

;; Show utility windows

(defun on-show-control-properties-win (obj)
  "Show control properties window"
  (let* ((app (connection-data-item obj "builder-app-data"))
         (is-hidden  nil)
         (auto-mode  nil)
         (panel  (create-panel (connection-body obj) :positioning :fixed
                                                     :width 400
                                                     :top 40
                                                     :right 0 :bottom 0
                                                     :class "w3-border-left"))
         (content (create-panel panel :width 390 :top 0 :right 0 :bottom 0))
         (side-panel (create-panel panel :top 0 :left 0 :bottom 0 :width 10))
         (pin        (create-div side-panel :content "☑" :class "w3-small"))
         (control-list (create-table content)))
    (setf (background-color side-panel) :black)
    (setf (background-color content) :gray)
    (setf (right-panel app) panel)
    (setf (hiddenp (right-panel app)) t)
    (setf (control-properties-win app) content)
    (setf (properties-list app) control-list)
    (set-on-click side-panel (lambda (obj)
                               (declare (ignore obj))
                               (cond (auto-mode
                                      (setf auto-mode nil)
                                      (setf (text-value pin) "☑")
                                      (setf (width panel) "400px")
                                      (setf is-hidden nil))
                                     (t
                                      (setf auto-mode t)
                                      (setf (text-value pin) "☐")
                                      (setf (width panel) "400px")
                                      (setf is-hidden nil)))))
    (set-on-mouse-leave side-panel (lambda (obj)
                                     (declare (ignore obj))
                                     (when auto-mode
                                       (cond (is-hidden
                                              (setf (width panel) "400px")
                                              (setf is-hidden nil))
                                             (t
                                              (setf (width panel) "10px")
                                              (setf is-hidden t))))))
    (setf (overflow content) :auto)
    (setf (positioning control-list) :absolute)
    (set-geometry control-list :left 0 :top 0 :right 0)))

(defun on-show-project (obj &key project)
  (let ((app (connection-data-item obj "builder-app-data")))
    (when project
      (setf (current-project app) project))
    (if (project-win app)
        (window-focus (project-win app))
        (let* ((win (create-gui-window obj :title "Project Window"
                                           :top 60 :left 232
                                           :width 643 :height 625
                                           :has-pinner t :client-movement *client-side-movement*)))
          (create-projects (window-content win))
          (setf (project-win app) win)
          (set-on-window-close win (lambda (obj)
                                     (declare (ignore obj))
                                     (setf (project-win app) nil)))))))

(defun on-show-control-events-win (obj)
  "Show control events window"
  (let ((app (connection-data-item obj "builder-app-data")))
    (if (control-events-win app)
        (window-focus (control-events-win app))
        (let* ((win     (create-gui-window obj :title "Control CLOG Events"
                                               :left 225
                                               :top 480
                                               :height 200 :width 645
                                               :has-pinner t :client-movement *client-side-movement*))
               (content (window-content win))
               status)
          (setf (current-editor-is-lisp app) t)
          (set-on-window-focus win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (setf (current-editor-is-lisp app) t)))
          (setf (control-events-win app) win)
          (setf (events-list app) (create-select content :name "clog-events" :class "w3-gray w3-text-white"))
          (setf (positioning (events-list app)) :absolute)
          (set-geometry (events-list app) :top 5 :left 5 :right 5)
          (setf (event-editor app) (clog-ace:create-clog-ace-element content))
          (setf (clog-ace:read-only-p (event-editor app)) t)
          (set-on-event (event-editor app) "clog-save-ace"
                        (lambda (obj)
                          (declare (ignore obj))
                          ;; toggle focus to force a save of event
                          (focus (events-list app))
                          (focus (event-editor app))))
          (setf (positioning (event-editor app)) :absolute)
          (setf (width (event-editor app)) "")
          (setf (height (event-editor app)) "")
          (set-geometry (event-editor app) :top 35 :left 5 :right 5 :bottom 30)
          (clog-ace:resize (event-editor app))
          (setf status (create-div content :class "w3-tiny w3-border"))
          (setf (positioning status) :absolute)
          (setf (width status) "")
          (set-geometry status :height 20 :left 5 :right 5 :bottom 5)
          (setup-lisp-ace (event-editor app) status :package "CLOG-USER")
          (set-on-window-size-done win (lambda (obj)
                                         (declare (ignore obj))
                                         (clog-ace:resize (event-editor app))))
          (panel-mode win t)
          (set-on-window-focus win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (panel-mode win t)))
          (set-on-window-blur win
                              (lambda (obj)
                                (declare (ignore obj))
                                (panel-mode win nil)))
          (set-on-window-close win (lambda (obj)
                                     (declare (ignore obj))
                                     (setf (event-editor app) nil)
                                     (setf (events-list app) nil)
                                     (setf (control-events-win app) nil))))))
  (on-populate-control-events-win obj))

(defun on-show-control-js-events-win (obj)
  "Show control events window"
  (let ((app (connection-data-item obj "builder-app-data")))
    (if (control-js-events-win app)
        (window-focus (control-js-events-win app))
        (let* ((win     (create-gui-window obj :title "Control Client JavaScript Events"
                                               :left 225
                                               :top 700
                                               :height 200 :width 645
                                               :has-pinner t :client-movement *client-side-movement*))
               (content (window-content win))
               status)
          (setf (current-editor-is-lisp app) nil)
          (set-on-window-focus win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (setf (current-editor-is-lisp app) nil)))
          (setf (control-js-events-win app) win)
          (setf (events-js-list app) (create-select content :name "clog-js-events" :class "w3-gray w3-text-white"))
          (setf (positioning (events-js-list app)) :absolute)
          (set-geometry (events-js-list app) :top 5 :left 5 :right 5)
          (setf (event-js-editor app) (clog-ace:create-clog-ace-element content))
          (setf (clog-ace:read-only-p (event-js-editor app)) t)
          (set-on-event (event-js-editor app) "clog-save-ace"
                        (lambda (obj)
                          (declare (ignore obj))
                          ;; toggle focus to force a save of event
                          (focus (events-js-list app))
                          (focus (event-js-editor app))))
          (setf (positioning (event-js-editor app)) :absolute)
          (setf (width (event-js-editor app)) "")
          (setf (height (event-js-editor app)) "")
          (set-geometry (event-js-editor app) :top 35 :left 5 :right 5 :bottom 30)
          (clog-ace:resize (event-js-editor app))
          (setf status (create-div content :class "w3-tiny w3-border"
                                           :content "Use $(\"data-clog-name='control-name']\") to access controls."))
          (setf (positioning status) :absolute)
          (setf (width status) "")
          (set-geometry status :height 20 :left 5 :right 5 :bottom 5)
          (setup-lisp-ace (event-js-editor app) nil :package "clog-user")
          (setf (clog-ace:mode (event-js-editor app)) "ace/mode/javascript")
          (set-on-window-size-done win (lambda (obj)
                                         (declare (ignore obj))
                                         (clog-ace:resize (event-js-editor app))))
          (panel-mode win t)
          (set-on-window-focus win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (panel-mode win t)))
          (set-on-window-blur win
                              (lambda (obj)
                                (declare (ignore obj))
                                (panel-mode win nil)))
          (set-on-window-close win (lambda (obj)
                                     (declare (ignore obj))
                                     (setf (event-js-editor app) nil)
                                     (setf (events-js-list app) nil)
                                     (setf (control-js-events-win app) nil))))))
  (on-populate-control-js-events-win obj))

(defun on-show-control-ps-events-win (obj)
  "Show control events window"
  (let ((app (connection-data-item obj "builder-app-data")))
    (if (control-ps-events-win app)
        (window-focus (control-ps-events-win app))
        (let* ((win     (create-gui-window obj :title "Control Client ParenScript Events"
                                               :left 225
                                               :top 700
                                               :height 200 :width 645
                                               :has-pinner t :client-movement *client-side-movement*))
               (content (window-content win))
               status)
          (setf (current-editor-is-lisp app) nil)
          (set-on-window-focus win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (setf (current-editor-is-lisp app) nil)))
          (setf (control-ps-events-win app) win)
          (setf (events-ps-list app) (create-select content :name "clog-ps-events" :class "w3-gray w3-text-white"))
          (setf (positioning (events-ps-list app)) :absolute)
          (set-geometry (events-ps-list app) :top 5 :left 5 :right 5)
          (setf (event-ps-editor app) (clog-ace:create-clog-ace-element content))
          (setf (clog-ace:read-only-p (event-ps-editor app)) t)
          (set-on-event (event-ps-editor app) "clog-save-ace"
                        (lambda (obj)
                          (declare (ignore obj))
                          ;; toggle focus to force a save of event
                          (focus (events-ps-list app))
                          (focus (event-ps-editor app))))
          (setf (positioning (event-ps-editor app)) :absolute)
          (setf (width (event-ps-editor app)) "")
          (setf (height (event-ps-editor app)) "")
          (set-geometry (event-ps-editor app) :top 35 :left 5 :right 5 :bottom 30)
          (clog-ace:resize (event-ps-editor app))
          (setf status (create-div content :class "w3-tiny w3-border"
                                           :content "Use (ps:chain ($ \"[data-clog-name=\\\"control-name\\\"]\")) to access controls."))
          (setf (positioning status) :absolute)
          (setf (width status) "")
          (set-geometry status :height 20 :left 5 :right 5 :bottom 5)
          (setup-lisp-ace (event-ps-editor app) nil :package "parenscript")
          (set-on-window-size-done win (lambda (obj)
                                         (declare (ignore obj))
                                         (clog-ace:resize (event-ps-editor app))))
          (panel-mode win t)
          (set-on-window-focus win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (panel-mode win t)))
          (set-on-window-blur win
                              (lambda (obj)
                                (declare (ignore obj))
                                (panel-mode win nil)))
          (set-on-window-close win (lambda (obj)
                                     (declare (ignore obj))
                                     (setf (event-ps-editor app) nil)
                                     (setf (events-ps-list app) nil)
                                     (setf (control-ps-events-win app) nil))))))
  (on-populate-control-ps-events-win obj))

(defun on-show-copy-history-win (obj)
  "Create and show copy/but history"
  (let ((app (connection-data-item obj "builder-app-data")))
    (if (copy-history-win app)
        (progn
          (setf (hiddenp (copy-history-win app)) nil)
          (window-focus (copy-history-win app)))
        (let* ((win          (create-gui-window obj :title "Copy History"
                                                    :left 225
                                                    :top 480
                                                    :height 400 :width 600
                                                    :has-pinner t :client-movement *client-side-movement*)))
          (window-center win)
          (setf (hiddenp win) t)
          (setf (overflow (window-content win)) :scroll)
          (setf (copy-history-win app) win)
          (set-on-window-can-close win (lambda (obj)
                                         (declare (ignore obj))
                                         (setf (hiddenp win) t)
                                         nil))))))

(defun on-show-control-list-win (obj)
  "Show control list for selecting and manipulating controls by name"
  (let* ((app          (connection-data-item obj "builder-app-data"))
         (is-hidden    nil)
         (auto-mode    nil)
         (content      (create-panel (connection-body obj) :positioning :fixed
                                                       :width 220
                                                       :top 40
                                                       :left 0 :bottom 0
                                                       :class "w3-border-right"))
         (side-panel   (create-panel content :top 0 :right 0 :bottom 0 :width 10))
         (pin          (create-div side-panel :content "☑" :class "w3-small"))
         (sheight      (floor (/ (height content) 2)))
         (swidth       (floor (width content)))
         (divider      (create-panel content :top sheight :height 10 :left 0 :right 10))
         (control-list (create-panel content :height (- sheight 10) :left 0 :bottom 0 :right 10))
         (pallete      (create-select content))
         (adj-size     0))
    (set-geometry pallete :left 0 :top 0 :height sheight :width (- swidth 10))
    (setf (left-panel app) content)
    (setf (hiddenp (left-panel app)) t)
    (setf (background-color divider) :black)
    (setf (tab-index divider) "-1")
    (setf (cursor divider) :ns-resize)
    (setf (background-color content) :gray)
    (setf (background-color pallete) :gray)
    (setf (color pallete) :white)
    (setf (positioning pallete) :absolute)
    (setf (size pallete) 2)
    (setf (advisory-title pallete) (format nil "<ctrl/cmd> place static~%<shift> child to current selection"))
    (setf (select-tool app) pallete)
    (setf (overflow control-list) :auto)
    (reset-control-pallete obj)
    (setf (control-list-win app) control-list)
    (setf (advisory-title content)
          (format nil "Drag and drop order~%Double click non-focusable~%~
                             <ctrl/cmd> place as static~%<shift> child to current selection"))
    (setf (background-color side-panel) :black)
    (flet ((on-size (obj)
             (declare (ignore obj))
             (setf sheight (floor (/ (height content) 2)))
             (when (and (> (- sheight adj-size) 5)
                        (> (+ (- sheight 10) adj-size) 5))
               (set-geometry pallete :height (- sheight adj-size))
               (set-geometry divider :top (- sheight adj-size))
               (set-geometry control-list :height (+ (- sheight 10) adj-size)))))
      (set-on-resize (window (connection-body obj)) #'on-size)
      (set-on-full-screen-change (html-document (connection-body obj)) #'on-size)
      (set-on-orientation-change (window (connection-body obj)) #'on-size)
      (set-on-pointer-down divider (lambda (obj data)
                                     (setf (getf data :client-y) (+ adj-size
                                                                    (getf data :client-y)))
                                     (set-on-pointer-up (connection-body obj)
                                                        (lambda (obj data)
                                                          (declare (ignore data))
                                                          (set-on-pointer-up (connection-body obj) nil)
                                                          (set-on-pointer-move (connection-body obj) nil)))
                                     (set-on-pointer-move (connection-body obj)
                                                          (lambda (obj new-data)
                                                            (setf adj-size (- (getf data :client-y)
                                                                              (getf new-data :client-y)))
                                                            (on-size obj))))
                           :capture-pointer t))
    (set-on-click side-panel (lambda (obj)
                               (declare (ignore obj))
                               (cond (auto-mode
                                      (setf auto-mode nil)
                                      (setf (text-value pin) "☑")
                                      (setf (width content) "220px")
                                      (setf (hiddenp pallete) nil)
                                      (setf is-hidden nil))
                                     (t
                                      (setf auto-mode t)
                                      (setf (text-value pin) "☐")
                                      (setf (width content) "10px")
                                      (setf (hiddenp pallete) t)
                                      (setf is-hidden t)))))
    (set-on-mouse-leave side-panel (lambda (obj)
                                     (declare (ignore obj))
                                     (when auto-mode
                                       (cond (is-hidden
                                              (setf (width content) "220px")
                                              (setf (hiddenp pallete) nil)
                                              (setf is-hidden nil))
                                             (t
                                              (setf (width content) "10px")
                                              (setf (hiddenp pallete) t)
                                              (setf is-hidden t))))))))

(defun panel-mode (obj bool)
  "Set the status for display or hiding the side panels."
  (let ((app (connection-data-item obj "builder-app-data")))
    (setf (hiddenp (right-panel app)) (not bool))
    (setf (hiddenp (left-panel app)) (not bool))))

(defun on-new-builder-panel-ext (obj &key open-file popup)
  (open-window (window (connection-body obj))
               (if open-file
                   (format nil "/panel-editor?open-panel=~A"
                           open-file)
                   "/source-editor")
               :specs (if popup
                          "width=645,height-430"
                          "")
               :name "_blank"))

(defun on-new-builder-panel (obj &key (open-file nil))
  "Open new panel"
  (unless (and open-file
               (window-to-top-by-param obj open-file))
    (let* ((app (connection-data-item obj "builder-app-data"))
           (win (create-gui-window obj :top 40 :left 225
                                       :width 645 :height 430
                                       :client-movement *client-side-movement*))
           (box (create-panel-box-layout (window-content win)
                                         :left-width 0 :right-width 0
                                         :top-height 33 :bottom-height 0))
           (tool-bar  (create-div (top-panel box) :class "w3-center"))
           (btn-class "w3-button w3-white w3-border w3-border-black w3-ripple")
           (btn-copy  (create-img tool-bar :alt-text "copy"     :url-src img-btn-copy  :class btn-class))
           (btn-paste (create-img tool-bar :alt-text "paste"    :url-src img-btn-paste :class btn-class))
           (btn-cut   (create-img tool-bar :alt-text "cut"      :url-src img-btn-cut   :class btn-class))
           (btn-del   (create-img tool-bar :alt-text "delete"   :url-src img-btn-del   :class btn-class))
           (btn-undo  (create-img tool-bar :alt-text "undo"     :url-src img-btn-undo  :class btn-class))
           (btn-redo  (create-img tool-bar :alt-text "redo"     :url-src img-btn-redo  :class btn-class))
           (btn-test  (create-img tool-bar :alt-text "test"     :url-src img-btn-test  :class btn-class))
           (btn-rndr  (create-img tool-bar :alt-text "render"   :url-src img-btn-rndr  :class btn-class))
           (btn-save  (create-img tool-bar :alt-text "save"     :url-src img-btn-save  :class btn-class))
           (btn-load  (create-img tool-bar :alt-text "load"     :url-src img-btn-load  :class btn-class))
           (cbox      (create-form-element tool-bar :checkbox :class "w3-margin-left"))
           (cbox-lbl  (create-label tool-bar :content "&nbsp;auto render" :label-for cbox :class "w3-black"))
           (spacer    (create-span tool-bar :content "&nbsp;&nbsp;&nbsp;"))
           (btn-help  (create-span tool-bar :content "?" :class "w3-tiny w3-ripple w3-black"))
           (content   (center-panel box))
           (in-simulation    nil)
           (undo-chain       nil)
           (redo-chain       nil)
           (is-dirty         nil)
           (last-date        nil)
           (file-name        "")
           (render-file-name "")
           (panel-id  (html-id content)))
      (declare (ignore spacer))
      (setf (background-color (top-panel box)) :black)
      (setf (checkedp cbox) t)
      (setf (advisory-title btn-copy) "copy")
      (setf (advisory-title btn-paste) "paste")
      (setf (advisory-title btn-cut) "cut")
      (setf (advisory-title btn-del) "delete")
      (setf (advisory-title btn-undo) "undo")
      (setf (advisory-title btn-redo) "redo")
      (setf (advisory-title btn-test) "test")
      (setf (advisory-title btn-rndr) "render to lisp - shift-click render as...")
      (setf (advisory-title btn-save) "save - shift-click save as...")
      (setf (advisory-title btn-load) "load")
      (setf (advisory-title cbox) "when checked render on save")
      (setf (advisory-title cbox-lbl) "when checked render on save")
      (setf (height btn-copy) "12px")
      (setf (height btn-paste) "12px")
      (setf (height btn-cut) "12px")
      (setf (height btn-del) "12px")
      (setf (height btn-undo) "12px")
      (setf (height btn-redo) "12px")
      (setf (height btn-test) "12px")
      (setf (height btn-rndr) "12px")
      (setf (height btn-save) "12px")
      (setf (height btn-load) "12px")
      (setf (height btn-help) "12px")
      (setf-next-id content 1)
      (setf (overflow content) :auto)
      (init-control-list app panel-id)
      ;; Setup panel window
      (let ((panel-name (format nil "panel-~A" (incf (next-panel-id app)))))
        (setf (window-title win) panel-name)
        (setf (attribute content "data-clog-name") panel-name))
      (setf (attribute content "data-clog-type") "clog-data")
      (setf (attribute content "data-in-package") "clog-user")
      (setf (attribute content "data-custom-slots") "")
      ;; activate associated windows on open
      (on-show-control-events-win win)
      (panel-mode win t)
      (on-populate-control-properties-win content :win win)
      (on-populate-control-list-win content :win win)
      ;; setup window events
      (set-on-window-focus win
                           (lambda (obj)
                             (declare (ignore obj))
                             (panel-mode win t)
                             (on-populate-control-properties-win content :win win)
                             (on-populate-control-list-win content :win win)))
      (set-on-window-blur win
                          (lambda (obj)
                            (declare (ignore obj))
                            (panel-mode win nil)))
      (set-on-window-close win
                           (lambda (obj)
                             (declare (ignore obj))
                             ;; clear associated windows on close
                             (setf (current-control app) nil)
                             (destroy-control-list app panel-id)
                             (on-populate-control-properties-win content :win win)
                             (on-populate-control-list-win content :win win)))
      (set-on-window-size-done win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (on-populate-control-properties-win content :win win)))
      ;; setup tool bar events
      (set-on-click btn-help 'on-quick-start)
      (flet (;; copy
             (copy (obj)
               (when (current-control app)
                 (maphash
                  (lambda (html-id control)
                    (declare (ignore html-id))
                    (place-inside-bottom-of (bottom-panel box)
                                            (get-placer control)))
                  (get-control-list app panel-id))
                 (setf (copy-buf app)
                       (js-query content
                                 (format nil
                                         "var z=~a.clone(); z=$('<div />').append(z);~
     z.find('*').each(function(){~
       if($(this).attr('data-clog-composite-control') == 't'){$(this).text('')}~
       if($(this).attr('id') !== undefined && ~
         $(this).attr('id').substring(0,5)=='CLOGB'){$(this).removeAttr('id')}});~
     z.html()"
                                         (jquery (current-control app)))))
                 (system-clipboard-write obj (copy-buf app))
                 (let ((c (create-text-area (window-content (copy-history-win app))
                                            :value (copy-buf app)
                                            :auto-place nil)))
                   (place-inside-top-of (window-content (copy-history-win app)) c)
                   (setf (width c) "100%"))
                 (maphash
                  (lambda (html-id control)
                    (declare (ignore html-id))
                    (place-after control (get-placer control)))
                  (get-control-list app panel-id))))
             ;; paste
             (paste (obj)
               (let ((buf (or (system-clipboard-read obj)
                              (copy-buf app))))
                 (when buf
                   (let ((control (create-control content content
                                                  `(:name "custom"
                                                    :create-type :paste)
                                                  (format nil "CLOGB~A~A"
                                                          (get-universal-time)
                                                          (next-id content))
                                                  :custom-query buf)))
                     (setf (attribute control "data-clog-name")
                           (format nil "~A-~A" "copy" (next-id content)))
                     (incf-next-id content)
                     (add-sub-controls control content :win win :paste t)
                     (let ((cr (control-info (attribute control "data-clog-type"))))
                       (when (getf cr :on-load)
                         (funcall (getf cr :on-load) control cr)))
                     (setup-control content control :win win)
                     (select-control control)
                     (on-populate-control-list-win content :win win)
                     (jquery-execute (get-placer content) "trigger('clog-builder-snap-shot')")))))
             ;; delete
             (del (obj)
               (declare (ignore obj))
               (when (current-control app)
                 (delete-current-control app panel-id (html-id (current-control app)))
                 (on-populate-control-properties-win content :win win)
                 (on-populate-control-list-win content :win win)
                 (jquery-execute (get-placer content) "trigger('clog-builder-snap-shot')"))))
        ;; set up del/cut/copy/paste handlers
        (set-on-copy content #'copy)
        (set-on-click btn-copy #'copy)
        (set-on-paste content #'paste)
        (set-on-click btn-paste #'paste)
        (set-on-click btn-del #'del)
        (set-on-cut content (lambda (obj)
                              (copy obj)
                              (del obj)))
        (set-on-click btn-cut (lambda (obj)
                                (copy obj)
                                (del obj))))
      (set-on-click btn-undo (lambda (obj)
                               (declare (ignore obj))
                               (when undo-chain
                                 (setf (inner-html content)
                                       (let ((val (pop undo-chain)))
                                         (push val redo-chain)
                                         val))
                                 (clrhash (get-control-list app panel-id))
                                 (on-populate-loaded-window content :win win)
                                 (setf (window-title win) (attribute content "data-clog-name"))
                                 (on-populate-control-properties-win content :win win)
                                 (on-populate-control-list-win content :win win))))
      (set-on-event content "clog-builder-snap-shot"
                    (lambda (obj)
                      (declare (ignore obj))
                      (setf is-dirty t)
                      (setf redo-chain nil)
                      (push (panel-snap-shot content panel-id (bottom-panel box)) undo-chain)
                      (when (current-control app)
                        (focus (get-placer (current-control app))))))
      (set-on-click btn-redo (lambda (obj)
                               (declare (ignore obj))
                               (when redo-chain
                                 (setf (inner-html content)
                                       (let ((val (pop redo-chain)))
                                         (push val undo-chain)
                                         val))
                                 (clrhash (get-control-list app panel-id))
                                 (on-populate-loaded-window content :win win)
                                 (setf (window-title win) (attribute content "data-clog-name"))
                                 (on-populate-control-properties-win content :win win)
                                 (on-populate-control-list-win content :win win))))
      (flet ((open-file-name (fname)
               (setf file-name fname)
               (setf last-date (file-write-date fname))
               (setf render-file-name (format nil "~A~A.lisp"
                                              (directory-namestring file-name)
                                              (pathname-name file-name)))
               (setf (inner-html content)
                     (or (read-file fname :clog-obj obj)
                         ""))
               (setf is-dirty nil)
               (clrhash (get-control-list app panel-id))
               (on-populate-loaded-window content :win win)
               (setf (window-title win) (attribute content "data-clog-name"))
               (setf (window-param win) fname)
               (on-populate-control-list-win content :win win)))
        (when open-file
          (open-file-name open-file))
        (set-on-click btn-load (lambda (obj)
                                 (server-file-dialog obj "Load Panel" (directory-namestring (if (equal file-name "")
                                                                                                (current-project-dir app)
                                                                                                file-name))
                                                     (lambda (fname)
                                                       (window-focus win)
                                                       (when fname
                                                         (open-file-name fname)))))))
      (labels ((do-save (obj fname data)
                 (declare (ignore obj data))
                 (setf file-name fname)
                 (setf render-file-name (format nil "~A~A.lisp"
                                                (directory-namestring file-name)
                                                (pathname-name file-name)))
                 (add-class btn-save "w3-animate-top")
                 (save-panel fname content panel-id (bottom-panel box))
                 (setf last-date (file-write-date fname))
                 (when (checkedp cbox)
                   (add-class btn-rndr "w3-animate-top")
                   (write-file (render-clog-code content (bottom-panel box))
                               render-file-name :clog-obj obj)
                   (sleep .5)
                   (remove-class btn-rndr "w3-animate-top"))
                 (sleep .5)
                 (remove-class btn-save "w3-animate-top")
                 (cond ((eq is-dirty :close)
                        (setf is-dirty nil)
                        (window-close win))
                       (t
                        (setf is-dirty nil))))
               (save (obj data)
                 (cond ((or (equal file-name "")
                            (getf data :shift-key))
                        (when (equal file-name "")
                          (setf file-name (format nil "~A~A.clog"
                                                  (current-project-dir app)
                                                  (attribute content "data-clog-name"))))
                        (server-file-dialog obj "Save Panel As.." file-name
                                            (lambda (fname)
                                              (window-focus win)
                                              (when fname
                                                (do-save obj fname data)))
                                            :initial-filename file-name))
                       (t
                        (if (eql last-date (file-write-date file-name))
                            (do-save obj file-name data)
                            (confirm-dialog obj "Panel changed on file system. Save?"
                                            (lambda (result)
                                              (when result
                                                (do-save obj file-name data)))))))))
        (set-on-window-can-close win
                                 (lambda (obj)
                                   (cond (is-dirty
                                          (confirm-dialog win "Save panel?"
                                                          (lambda (result)
                                                            (cond (result
                                                                   (setf is-dirty :close)
                                                                   (save obj nil))
                                                                  (t
                                                                   (setf is-dirty nil)
                                                                   (window-close win))))
                                                          :ok-text "Yes" :cancel-text "No")
                                          nil)
                                         (t
                                          t))))
        (set-on-mouse-click btn-save
                            (lambda (obj data)
                              (setf is-dirty nil)
                              (save obj data))))
      (set-on-click btn-test
                    (lambda (obj)
                      (do-eval obj (render-clog-code content (bottom-panel box))
                        (attribute content "data-clog-name")
                        :package (attribute content "data-in-package"))))
      (set-on-mouse-click btn-rndr
                          (lambda (obj data)
                            (cond ((or (equal render-file-name "")
                                       (getf data :shift-key))
                                   (when (equal render-file-name "")
                                     (if (equal file-name "")
                                         (setf render-file-name (format nil "~A.lisp" (attribute content "data-clog-name")))
                                         (setf render-file-name (format nil "~A~A.lisp"
                                                                        (directory-namestring file-name)
                                                                        (pathname-name file-name)))))
                                   (server-file-dialog obj "Render As.." render-file-name
                                                       (lambda (fname)
                                                         (window-focus win)
                                                         (when fname
                                                           (setf render-file-name fname)
                                                           (add-class btn-rndr "w3-animate-top")
                                                           (write-file (render-clog-code content (bottom-panel box))
                                                                       fname :clog-obj obj)
                                                           (sleep .5)
                                                           (remove-class btn-rndr "w3-animate-top")))
                                                       :initial-filename render-file-name))
                                  (t
                                   (add-class btn-rndr "w3-animate-top")
                                   (write-file (render-clog-code content (bottom-panel box))
                                               render-file-name :clog-obj obj)
                                   (sleep .5)
                                   (remove-class btn-rndr "w3-animate-top")))))
      (set-on-mouse-down content
                         (lambda (obj data)
                           (declare (ignore obj))
                           (unless in-simulation
                             (when (drop-new-control app content data :win win)
                               (incf-next-id content))))))))

(defun on-attach-builder-custom (body)
  "New custom builder page has attached"
  (let* ((params (form-get-data body))
         (curl   (form-data-item params "curl")))
    (on-attach-builder-page body :custom-boot curl)))

(defun on-attach-builder-page (body &key custom-boot)
  "New builder page has attached"
  (let* ((params        (form-get-data body))
         (panel-uid     (form-data-item params "bid"))
         (app           (gethash panel-uid *app-sync-hash*))
         win
         (box           (create-panel-box-layout body
                                                 :left-width 0 :right-width 0
                                                 :top-height 0 :bottom-height 0))
         (content       (center-panel box))
         (in-simulation nil)
         (undo-chain       nil)
         (redo-chain       nil)
         (file-name        "")
         (render-file-name "")
         (panel-id      (html-id content)))
    ;; sync new window with app
    (setf (connection-data-item body "builder-app-data") app)
    (remhash panel-uid *app-sync-hash*)
    (funcall (gethash (format nil "~A-link" panel-uid) *app-sync-hash*) content)
    (setf win (gethash (format nil "~A-win" panel-uid) *app-sync-hash*))
    (remhash (format nil "~A-win" panel-uid) *app-sync-hash*)
    ;; setup window and page
    (setf-next-id content 1)
    (let ((panel-name (format nil "page-~A" (incf (next-panel-id app)))))
      (setf (title (html-document body)) panel-name)
      (setf (window-title win) panel-name)
      (setf (attribute content "data-clog-name") panel-name))
    (setf (attribute content "data-clog-type") "clog-data")
    (setf (attribute content "data-in-package") "clog-user")
    (setf (attribute content "data-custom-slots") "")
    (setf (overflow content) :auto)
    (set-on-focus (window body)
                  (lambda (obj)
                    (declare (ignore obj))
                    (setf (title (html-document body)) (attribute content "data-clog-name"))))
    ;; setup close of page
    (set-on-before-unload (window body)
                          (lambda (obj)
                            (declare (ignore obj))
                            (window-close win)))
    ;; activate associated windows on open
    (deselect-current-control app)
    (panel-mode win t)
    (on-populate-control-properties-win content :win win)
    (on-populate-control-list-win content :win win)
    ;; setup window events
    (set-on-window-focus win
                         (lambda (obj)
                           (declare (ignore obj))
                           (panel-mode win t)
                           (on-populate-control-properties-win content :win win)
                           (on-populate-control-list-win content :win win)))
    (set-on-window-blur win
                        (lambda (obj)
                          (declare (ignore obj))
                          (panel-mode win nil)))
    (set-on-window-close win
                         (lambda (obj)
                           (declare (ignore obj))
                           ;; clear associated windows on close
                           (setf (current-control app) nil)
                           (destroy-control-list app panel-id)
                           (close-window (window body))))
    ;; setup jquery and jquery-ui
    (cond (custom-boot
           (load-css (html-document body) "/css/jquery-ui.css")
           (load-script (html-document body) "/js/jquery-ui.js"))
          (t
           (clog-gui-initialize body)
           (clog-web-initialize body :w3-css-url nil)))
    ;; init builder
    (init-control-list app panel-id)
    (let* ((pbox      (create-panel-box-layout (window-content win)
                                         :left-width 0 :right-width 0
                                         :top-height 33 :bottom-height 0))
           (tool-bar  (create-div (top-panel pbox) :class "w3-center"))
           (btn-class "w3-button w3-white w3-border w3-border-black w3-ripple")
           (btn-copy  (create-img tool-bar :alt-text "copy"     :url-src img-btn-copy  :class btn-class))
           (btn-paste (create-img tool-bar :alt-text "paste"    :url-src img-btn-paste :class btn-class))
           (btn-cut   (create-img tool-bar :alt-text "cut"      :url-src img-btn-cut   :class btn-class))
           (btn-del   (create-img tool-bar :alt-text "delete"   :url-src img-btn-del   :class btn-class))
           (btn-undo  (create-img tool-bar :alt-text "undo"     :url-src img-btn-undo  :class btn-class))
           (btn-redo  (create-img tool-bar :alt-text "redo"     :url-src img-btn-redo  :class btn-class))
           (btn-sim   (create-img tool-bar :alt-text "simulate" :url-src img-btn-sim   :class btn-class))
           (btn-test  (create-img tool-bar :alt-text "test"     :url-src img-btn-test  :class btn-class))
           (btn-rndr  (create-img tool-bar :alt-text "render"   :url-src img-btn-rndr  :class btn-class))
           (btn-save  (create-img tool-bar :alt-text "save"     :url-src img-btn-save  :class btn-class))
           (btn-load  (create-img tool-bar :alt-text "load"     :url-src img-btn-load  :class btn-class))
           (btn-exp   (create-img tool-bar :alt-text "export"   :url-src img-btn-exp   :class btn-class))
           (wcontent  (center-panel pbox)))
      (setf (background-color (top-panel pbox)) :black)
      (setf (advisory-title btn-copy) "copy")
      (setf (advisory-title btn-paste) "paste")
      (setf (advisory-title btn-cut) "cut")
      (setf (advisory-title btn-del) "delete")
      (setf (advisory-title btn-undo) "undo")
      (setf (advisory-title btn-redo) "redo")
      (setf (advisory-title btn-test) "test")
      (setf (advisory-title btn-rndr) "render to lisp - shift-click render as...")
      (setf (advisory-title btn-save) "save - shift-click save as...")
      (setf (advisory-title btn-load) "load")
      (setf (advisory-title btn-sim) "start simulation")
      (setf (advisory-title btn-exp) "export as boot page")
      (setf (height btn-copy) "12px")
      (setf (height btn-paste) "12px")
      (setf (height btn-cut) "12px")
      (setf (height btn-del) "12px")
      (setf (height btn-undo) "12px")
      (setf (height btn-redo) "12px")
      (setf (height btn-sim) "12px")
      (setf (height btn-test) "12px")
      (setf (height btn-rndr) "12px")
      (setf (height btn-save) "12px")
      (setf (height btn-load) "12px")
      (setf (height btn-exp) "12px")
      (create-div wcontent :content
                  "<br><center>Drop and work with controls on it's window.</center>")
      ;; setup tool bar events
      (set-on-click btn-exp (lambda (obj)
                              (server-file-dialog obj "Export as Boot HTML" "./"
                                                  (lambda (filename)
                                                    (when filename
                                                      (maphash
                                                       (lambda (html-id control)
                                                         (declare (ignore html-id))
                                                         (place-inside-bottom-of (bottom-panel box)
                                                                                 (get-placer control)))
                                                       (get-control-list app panel-id))
                                                      (save-body-to-file filename :body body :if-exists :rename)
                                                      (maphash
                                                       (lambda (html-id control)
                                                         (declare (ignore html-id))
                                                         (place-after control (get-placer control)))
                                                       (get-control-list app panel-id)))))))
      (flet (;; copy
             (copy (obj)
               (when (current-control app)
                 (maphash
                  (lambda (html-id control)
                    (declare (ignore html-id))
                    (place-inside-bottom-of (bottom-panel box)
                                            (get-placer control)))
                  (get-control-list app panel-id))
                 (setf (copy-buf app)
                       (js-query content
                                 (format nil
                                         "var z=~a.clone(); z=$('<div />').append(z);~
     z.find('*').each(function(){~
       if($(this).attr('data-clog-composite-control') == 't'){$(this).text('')}~
       if($(this).attr('id') !== undefined && ~
         $(this).attr('id').substring(0,5)=='CLOGB'){$(this).removeAttr('id')}});~
     z.html()"
                                         (jquery (current-control app)))))
                 (system-clipboard-write obj (copy-buf app))
                 (let ((c (create-text-area (window-content (copy-history-win app))
                                            :value (copy-buf app)
                                            :auto-place nil)))
                   (place-inside-top-of (window-content (copy-history-win app)) c)
                   (setf (width c) "100%"))
                 (maphash
                  (lambda (html-id control)
                    (declare (ignore html-id))
                    (place-after control (get-placer control)))
                  (get-control-list app panel-id))))
             ;; paste
             (paste (obj)
               (let ((buf (or (system-clipboard-read obj)
                              (copy-buf app))))
                 (when buf
                   (let ((control (create-control content content
                                                  `(:name "custom"
                                                    :create-type :paste)
                                                  (format nil "CLOGB~A~A"
                                                          (get-universal-time)
                                                          (next-id content))
                                                  :custom-query buf)))
                     (setf (attribute control "data-clog-name")
                           (format nil "~A-~A" "copy" (next-id content)))
                     (incf-next-id content)
                     (add-sub-controls control content :win win :paste t)
                     (let ((cr (control-info (attribute control "data-clog-type"))))
                       (when (getf cr :on-load)
                         (funcall (getf cr :on-load) control cr)))
                     (setup-control content control :win win)
                     (select-control control)
                     (on-populate-control-list-win content :win win)
                     (jquery-execute (get-placer content) "trigger('clog-builder-snap-shot')")))))
             ;; delete
             (del (obj)
               (declare (ignore obj))
               (when (current-control app)
                 (delete-current-control app panel-id (html-id (current-control app)))
                 (on-populate-control-properties-win content :win win)
                 (on-populate-control-list-win content :win win)
                 (jquery-execute (get-placer content) "trigger('clog-builder-snap-shot')"))))
        ;; set up del/cut/copy/paste handlers
        (set-on-copy content #'copy)
        (set-on-click btn-copy #'copy)
        (set-on-paste content #'paste)
        (set-on-click btn-paste #'paste)
        (set-on-click btn-del #'del)
        (set-on-cut content (lambda (obj)
                              (copy obj)
                              (del obj)))
        (set-on-click btn-cut (lambda (obj)
                                (copy obj)
                                (del obj))))
      (set-on-click btn-sim (lambda (obj)
                              (declare (ignore obj))
                              (cond (in-simulation
                                     (setf (url-src btn-sim) img-btn-sim)
                                     (setf (advisory-title btn-sim) "start simulation")
                                     (setf in-simulation nil)
                                     (maphash (lambda (html-id control)
                                                (declare (ignore html-id))
                                                (setf (hiddenp (get-placer control)) nil))
                                              (get-control-list app panel-id)))
                                    (t
                                     (setf (url-src btn-sim) img-btn-cons)
                                     (setf (advisory-title btn-sim) "construction mode")
                                     (deselect-current-control app)
                                     (on-populate-control-properties-win content :win win)
                                     (setf in-simulation t)
                                     (maphash (lambda (html-id control)
                                                (declare (ignore html-id))
                                                (setf (hiddenp (get-placer control)) t))
                                              (get-control-list app panel-id))
                                     (focus (first-child content))))))
      (set-on-click btn-undo (lambda (obj)
                               (declare (ignore obj))
                               (when undo-chain
                                 (setf (inner-html content)
                                       (let ((val (pop undo-chain)))
                                         (push val redo-chain)
                                         val))
                                 (clrhash (get-control-list app panel-id))
                                 (on-populate-loaded-window content :win win)
                                 (setf (window-title win) (attribute content "data-clog-name"))
                                 (on-populate-control-properties-win content :win win)
                                 (on-populate-control-list-win content :win win))))
      (set-on-event content "clog-builder-snap-shot"
                    (lambda (obj)
                      (declare (ignore obj))
                      (setf redo-chain nil)
                      (push (panel-snap-shot content panel-id (bottom-panel box)) undo-chain)
                      (when (current-control app)
                        (focus (get-placer (current-control app))))))
      (set-on-click btn-redo (lambda (obj)
                               (declare (ignore obj))
                               (when redo-chain
                                 (setf (inner-html content)
                                       (let ((val (pop redo-chain)))
                                         (push val undo-chain)
                                         val))
                                 (clrhash (get-control-list app panel-id))
                                 (on-populate-loaded-window content :win win)
                                 (setf (window-title win) (attribute content "data-clog-name"))
                                 (on-populate-control-properties-win content :win win)
                                 (on-populate-control-list-win content :win win))))
      (set-on-click btn-load (lambda (obj)
                               (declare (ignore obj))
                               (server-file-dialog win "Load Panel" (directory-namestring (if (equal file-name "")
                                                                                              (current-project-dir app)
                                                                                              file-name))
                                                   (lambda (fname)
                                                     (window-focus win)
                                                     (when fname
                                                       (setf file-name fname)
                                                       (setf render-file-name (format nil "~A~A.lisp"
                                                                                      (directory-namestring file-name)
                                                                                      (pathname-name file-name)))
                                                       (setf (inner-html content)
                                                             (read-file fname :clog-obj obj))
                                                       (clrhash (get-control-list app panel-id))
                                                       (on-populate-loaded-window content :win win)
                                                       (setf (title (html-document body)) (attribute content "data-clog-name"))
                                                       (setf (window-title win) (attribute content "data-clog-name"))
                                                       (on-populate-control-list-win content :win win))))))
      (set-on-mouse-click btn-save
                          (lambda (obj data)
                            (cond ((or (equal file-name "")
                                       (getf data :shift-key))
                                   (when (equal file-name "")
                                     (setf file-name (format nil "~A~A.clog"
                                                             (current-project-dir app)
                                                             (attribute content "data-clog-name"))))
                                   (server-file-dialog obj "Save Panel As.." file-name
                                                       (lambda (fname)
                                                         (window-focus win)
                                                         (when fname
                                                           (setf file-name fname)
                                                           (setf render-file-name (format nil "~A~A.lisp"
                                                                                          (directory-namestring file-name)
                                                                                          (pathname-name file-name)))
                                                           (add-class btn-save "w3-animate-top")
                                                           (save-panel fname content panel-id (bottom-panel box))
                                                           (sleep .5)
                                                           (remove-class btn-save "w3-animate-top"))
                                                         :initial-filename file-name)))
                                  (t
                                   (add-class btn-save "w3-animate-top")
                                   (save-panel file-name content panel-id (bottom-panel box))
                                   (sleep .5)
                                   (remove-class btn-save "w3-animate-top")))))
      (set-on-click btn-test
                    (lambda (obj)
                      (do-eval obj (render-clog-code content (bottom-panel box))
                        (attribute content "data-clog-name")
                        :package (attribute content "data-in-package")
                        :custom-boot custom-boot)))
      (set-on-mouse-click btn-rndr
                          (lambda (obj data)
                            (cond ((or (equal render-file-name "")
                                       (getf data :shift-key))
                                   (when (equal render-file-name "")
                                     (if (equal file-name "")
                                         (setf render-file-name (format nil "~A.lisp" (attribute content "data-clog-name")))
                                         (setf render-file-name (format nil "~A~A.lisp"
                                                                        (directory-namestring file-name)
                                                                        (pathname-name file-name)))))
                                   (server-file-dialog obj "Render As.." render-file-name
                                                       (lambda (fname)
                                                         (window-focus win)
                                                         (when fname
                                                           (setf render-file-name fname)
                                                           (add-class btn-rndr "w3-animate-top")
                                                           (write-file (render-clog-code content (bottom-panel box))
                                                                       fname :clog-obj obj)
                                                           (sleep .5)
                                                           (remove-class btn-rndr "w3-animate-top")))
                                                       :initial-filename render-file-name))
                                  (t
                                   (add-class btn-rndr "w3-animate-top")
                                   (write-file (render-clog-code content (bottom-panel box))
                                               render-file-name :clog-obj obj)))
                                   (sleep .5)
                                   (remove-class btn-rndr "w3-animate-top"))))
    (set-on-mouse-down content
                       (lambda (obj data)
                         (declare (ignore obj))
                         (unless in-simulation
                           (when (drop-new-control app content data :win win)
                             (incf-next-id content)))))))

(defun on-new-builder-basic-page (obj)
  "Menu item to open new basic HTML page"
  (set-on-new-window 'on-attach-builder-custom :boot-file "/boot.html" :path "/builder-custom")
  (on-new-builder-page obj :custom-boot "/boot.html" :url-launch nil))

(defun on-new-builder-launch-page (obj)
  "Menu item to open new page"
  (on-new-builder-page obj :url-launch t))

(defun on-new-builder-custom (obj)
  "Open custom boot page"
  (let ((custom-boot "/boot.html"))
    (input-dialog obj "Boot File Name:"
                  (lambda (answer)
                    (when answer
                      (setf custom-boot answer)
                      (set-on-new-window 'on-attach-builder-custom
                                         :boot-file custom-boot :path "/builder-custom")
                      (on-new-builder-page obj :custom-boot custom-boot :url-launch t)))
                  :default-value custom-boot :modal t)))

(defun on-new-builder-page (obj &key custom-boot url-launch)
  "Open new page"
  (let* ((app (connection-data-item obj "builder-app-data"))
         (win (create-gui-window obj :top 40 :left 225 :width 600 :client-movement *client-side-movement*))
         (panel-uid  (format nil "~A" (get-universal-time))) ;; unique id for panel
         (boot-loc   (if custom-boot
                         "builder-custom"
                         "builder-page"))
         (curl       (if custom-boot
                         (format nil "&curl=~A" (quri:url-encode custom-boot))
                         ""))
         (link       (format nil "http://127.0.0.1:~A/~A?bid=~A~A" clog:*clog-port* boot-loc panel-uid curl))
         (link-rel   (format nil "/~A?bid=~A~A" boot-loc panel-uid curl))
         (btn-txt    (if url-launch
                         "Click to launch default browser or copy URL."
                         "Click if browser does not open new page shortly."))
         (txt-area   (create-div (window-content win)))
         (page-link  (create-a txt-area
                               :target "_blank"
                               :content (format nil "<br><center><button>
                                   ~A
                                   </button></center>" btn-txt)
                               :link link))
         (txt-link   (create-div txt-area
                                 :content (format nil "<br><center>~A</center>" link)))
         content)
    (declare (ignore page-link txt-link))
    (on-show-control-events-win win)
    (setf (gethash panel-uid *app-sync-hash*) app)
    (setf (gethash (format nil "~A-win" panel-uid) *app-sync-hash*) win)
    (setf (gethash (format nil "~A-link" panel-uid) *app-sync-hash*)
          (lambda (obj)
            (setf content obj)
            (setf panel-uid (html-id content))
            (destroy txt-area)
            (remhash (format nil "~A-link" panel-uid) *app-sync-hash*)))
    (unless url-launch
      (open-window (window (connection-body obj)) link-rel))))

(defun on-help-about-builder (obj)
  "Open about box"
  (let ((about (create-gui-window obj
                                  :title   "About"
                                  :content (format nil "<div class='w3-black'>
                                         <center><img src='~A'></center>
                                         <center>CLOG</center>
                                         <center>The Common Lisp Omnificent GUI</center></div>
                                         <div><p><center>
                                           <a target=_blank href='https://github.com/sponsors/rabbibotton'>CLOG Builder</a>
                                           </center>
                                         <center>(c) 2022-2024 - David Botton</center></p></div>"
                                                   img-clog-icon)
                                  :width   200
                                  :height  215
                                  :hidden  t)))
    (window-center about)
    (setf (visiblep about) t)
    (set-on-window-can-size about (lambda (obj)
                                    (declare (ignore obj))()))))

(defun on-new-app-template (obj)
  "Menu option to create new project from template"
  (let* ((win (create-gui-window obj :title "New Application Template"
                                     :width 500 :height 400))
         (ct  (create-clog-templates (window-content win))))
    (window-center win)
    (setf (win ct) win)
    (dolist (tmpl *supported-templates*)
      (if (eq (getf tmpl :code) :group)
          (add-select-optgroup (template-box ct) (getf tmpl :name))
          (add-select-option (template-box ct) (getf tmpl :code) (getf tmpl :name))))))

(defun on-image-to-data (obj)
  "Menu option to create new project from template"
  (let* ((win (create-gui-window obj :title "Convert Images to Data"
                                     :width 450 :height 200)))
    (create-image-to-data (window-content win))
    (window-center win)))

(defun on-convert-image (body)
  "Convert image from form input from on-image-to-data"
  (let ((params (form-multipart-data body)))
    (create-div body :content params)
    (destructuring-bind (stream fname content-type)
        (form-data-item params "filename")
      (create-div body :content (format nil "filename = ~A - (contents printed in REPL)" fname))
      (let ((s        (flexi-streams:make-flexi-stream stream))
            (pic-data ""))
        (setf pic-data (format nil "data:~A;base64,~A" content-type
                               (with-output-to-string (out)
                                 (s-base64:encode-base64 s out))))
        (create-img body :url-src pic-data)
        (create-br body)
        (create-div body :content "User the following as a url source:")
        (set-geometry (create-text-area body :value pic-data) :width 500 :height 400)
        (create-br body)
        (create-div body :content (format nil "For example:<br>(create-img body :url-src \"~A\")" pic-data))))))

(defun on-quick-start (obj)
  "Open quick start help"
  (let* ((win (create-gui-window obj :title "Quick Start"
                                     :top 40 :left 225
                                     :width 600 :height 400
                                     :client-movement *client-side-movement*)))
    (create-quick-start (window-content win))))

(defun on-show-thread-viewer (obj)
  "Open thread views"
  (let* ((win (create-gui-window obj :title "Thread Viewer"
                                     :top 40 :left 225
                                     :width 600 :height 400
                                     :client-movement *client-side-movement*)))
    (create-thread-list (window-content win))))

(defun on-open-file-ext (obj &key open-file popup)
  (open-window (window (connection-body obj))
               (if open-file
                   (format nil "/source-editor?open-file=~A"
                           open-file)
                   "/source-editor")
               :specs (if popup
                          "width=645,height-430"
                          "")
               :name "_blank"))

(defun on-open-file (obj &key open-file
                           (title "New Source Editor")
                           text
                           (title-class "w3-black")
                           maximized)
  "Open a new text editor"
  (unless (window-to-top-by-title obj open-file)
    (let* ((app (connection-data-item obj "builder-app-data"))
           (win (create-gui-window obj :title title
                                       :title-class title-class
                                       :width 645 :height 430
                                       :client-movement *client-side-movement*))
           (box (create-panel-box-layout (window-content win)
                                         :left-width 0 :right-width 0
                                         :top-height 33 :bottom-height 0))
           (tool-bar  (create-div (top-panel box) :class "w3-center"))
           (btn-class "w3-button w3-white w3-border w3-border-black w3-ripple")
           (btn-copy  (create-img tool-bar :alt-text "copy"     :url-src img-btn-copy  :class btn-class))
           (btn-paste (create-img tool-bar :alt-text "paste"    :url-src img-btn-paste :class btn-class))
           (btn-cut   (create-img tool-bar :alt-text "cut"      :url-src img-btn-cut   :class btn-class))
           (btn-del   (create-img tool-bar :alt-text "delete"   :url-src img-btn-del   :class btn-class))
           (btn-undo  (create-img tool-bar :alt-text "undo"     :url-src img-btn-undo  :class btn-class))
           (btn-redo  (create-img tool-bar :alt-text "redo"     :url-src img-btn-redo  :class btn-class))
           (btn-save  (create-img tool-bar :alt-text "save"     :url-src img-btn-save  :class btn-class))
           (btn-load  (create-img tool-bar :alt-text "load"     :url-src img-btn-load  :class btn-class))
           (spacer1   (create-span tool-bar :content "&nbsp;"))
           (btn-efrm  (create-button tool-bar :content "Eval Form" :class (format nil "w3-tiny ~A" btn-class)))
           (btn-esel  (create-button tool-bar :content "Eval Sel"  :class (format nil "w3-tiny ~A" btn-class)))
           (btn-test  (create-button tool-bar :content "Eval All"  :class (format nil "w3-tiny ~A" btn-class)))
           (spacer2   (create-span tool-bar :content "&nbsp;&nbsp;"))
           (btn-help  (create-span tool-bar :content "?" :class "w3-tiny w3-ripple"))
           (content   (center-panel box))
           (pac-line  (create-form-element content :text :class "w3-black"))
           (ace       (clog-ace:create-clog-ace-element content))
           (status    (create-div content :class "w3-tiny w3-border"))
           (lisp-file t)
           (is-dirty  nil)
           (last-date nil)
           (file-name ""))
      (declare (ignore spacer1 spacer2))
      (when maximized
        (window-maximize win))
      (when text
        (setf (text-value ace) text))
      (set-on-window-focus win
                           (lambda (obj)
                             (declare (ignore obj))
                             (if lisp-file
                                 (setf (current-editor-is-lisp app) (text-value pac-line))
                                 (setf (current-editor-is-lisp app) nil))))
      (add-class tool-bar title-class)
      (setf (advisory-title btn-paste) "paste")
      (setf (advisory-title btn-cut) "cut")
      (setf (advisory-title btn-del) "delete")
      (setf (advisory-title btn-undo) "undo")
      (setf (advisory-title btn-redo) "redo")
      (setf (advisory-title btn-save) "save  - shift-click save as...")
      (setf (advisory-title btn-load) "load")
      (setf (advisory-title btn-efrm) "evaluate form")
      (setf (advisory-title btn-esel) "evaluate selection")
      (setf (advisory-title btn-test) "evaluate")
      (setf (height btn-copy) "12px")
      (setf (height btn-paste) "12px")
      (setf (height btn-cut) "12px")
      (setf (height btn-del) "12px")
      (setf (height btn-undo) "12px")
      (setf (height btn-redo) "12px")
      (setf (height btn-save) "12px")
      (setf (height btn-load) "12px")
      (setf (height btn-efrm) "12px")
      (setf (height btn-esel) "12px")
      (setf (height btn-test) "12px")
      (setf (height btn-help) "12px")
      (setf (width btn-efrm) "43px")
      (setf (width btn-esel) "43px")
      (setf (width btn-test) "43px")
      (setf (positioning ace) :absolute)
      (setf (positioning status) :absolute)
      (set-geometry pac-line :units "" :top "20px" :left "0px"
                             :right "0px" :height "22px" :width "100%")
      (setf (place-holder pac-line) "Current Package")
      (setf (text-value pac-line) "clog-user")
      (setf (current-editor-is-lisp app) "clog-user")
      (set-geometry ace :units "" :width "" :height ""
                        :top "22px" :bottom "20px" :left "0px" :right "0px")
      (clog-ace:resize ace)
      (set-geometry status :units "" :width "" :height "20px"
                           :bottom "0px" :left "0px" :right "0px")
      (setup-lisp-ace ace status)
      (set-on-click btn-help
                    (lambda (obj)
                      (declare (ignore obj))
                      (alert-dialog win
                                    "<table>
<tr><td>cmd/alt-,</td><td>Configure editor</td></tr>
<tr><td>cmd/alt-.</td><td> Launch system browser</td></tr>
<tr><td>cmd/alt-[</td><td> Evaluate form</td></tr>
<tr><td>cmd/ctl-s</td><td> Save</td></tr>
<tr><td>ctl-=</td><td>Expand region</td></tr>
<tr><td>opt/alt-m</td><td>Macroexpand</td></tr>
</table><p><a target='_blank' href='https://github.com/ajaxorg/ace/wiki/Default-Keyboard-Shortcuts'>Default Keybindings</a>"
                                    :width 400 :height 300
                                    :title "Help")))
      (set-on-window-size-done win
                               (lambda (obj)
                                 (declare (ignore obj))
                                 (clog-ace:resize ace)))
      (flet ((open-file-name (fname)
               (window-focus win)
               (handler-case
                   (when fname
                     (setf last-date (file-write-date fname))
                     (setf file-name fname)
                     (setf (window-title win) fname)
                     (let ((c (or (read-file fname) "" :clog-obj obj)))
                       (cond ((or (equalp (pathname-type fname) "lisp")
                                  (equalp (pathname-type fname) "asd"))
                              (setf (clog-ace:mode ace) "ace/mode/lisp")
                              (setf (text-value pac-line) (get-package-from-string c))
                              (setf lisp-file t)
                              (setf (current-editor-is-lisp app) (text-value pac-line)))
                             (t
                              (setf lisp-file nil)
                              (setf (current-editor-is-lisp app) nil)
                              (setf (clog-ace:mode ace) (clog-ace:get-mode-from-extension ace fname))))
                       (setf (clog-ace:text-value ace) c)))
                 (error (condition)
	           (alert-toast obj "File Error" (format nil "Error: ~A" condition))
	           (format t "Error: ~A" condition)))))
        (when open-file
          (open-file-name open-file))
        (set-on-click btn-load (lambda (obj)
                                 (server-file-dialog obj "Load Source" (directory-namestring (if (equal file-name "")
                                                                                                 (current-project-dir app)
                                                                                                 file-name))
                                                     (lambda (fname)
                                                       (open-file-name fname)
                                                       (setf is-dirty nil))))))
      (set-on-input ace (lambda (obj)
                          (declare (ignore obj))
                          (setf is-dirty t)))
      (set-on-event ace "clog-save-ace"
                    (lambda (obj)
                      (unless (equal file-name "")
                        (add-class btn-save "w3-animate-top")
                        (write-file (text-value ace) file-name :clog-obj obj)
                        (sleep .5)
                        (remove-class btn-save "w3-animate-top"))))
      (flet ((save (obj data)
               (cond ((or (equal file-name "")
                          (getf data :shift-key))
                      (server-file-dialog obj "Save Source As.." (if (equal file-name "")
                                                                     (current-project-dir app)
                                                                     file-name)
                                          (lambda (fname)
                                            (window-focus win)
                                            (when fname
                                              (setf file-name fname)
                                              (add-class btn-save "w3-animate-top")
                                              (write-file (text-value ace) fname :clog-obj obj)
                                              (setf last-date (file-write-date fname))
                                              (sleep .5)
                                              (remove-class btn-save "w3-animate-top"))
                                            :initial-filename file-name)))
                     (t
                      (cond ((eql last-date (file-write-date file-name))
                             (add-class btn-save "w3-animate-top")
                             (write-file (text-value ace) file-name :clog-obj obj)
                             (setf last-date (file-write-date file-name))
                             (sleep .5)
                             (remove-class btn-save "w3-animate-top"))
                            (t
                             (confirm-dialog obj "File changed on file system. Save?"
                                             (lambda (result)
                                               (when result
                                                 (add-class btn-save "w3-animate-top")
                                                 (write-file (text-value ace) file-name :clog-obj obj)
                                                 (setf last-date (file-write-date file-name))
                                                 (sleep .5)
                                                 (remove-class btn-save "w3-animate-top"))))))))))
        (set-on-window-can-close win
                                 (lambda (obj)
                                   (cond (is-dirty
                                          (confirm-dialog obj "Save File?"
                                                          (lambda (result)
                                                            (setf is-dirty nil)
                                                            (when result
                                                              (save obj nil))
                                                            (window-close win))
                                                          :ok-text "Yes" :cancel-text "No")
                                          nil)
                                         (t
                                          t))))
        (set-on-mouse-click btn-save
                            (lambda (obj data)
                              (save obj data)
                              (setf is-dirty nil))))
      (set-on-click btn-copy (lambda (obj)
                               (declare (ignore obj))
                               (clog-ace:clipboard-copy ace)))
      (set-on-click btn-cut (lambda (obj)
                              (declare (ignore obj))
                              (clog-ace:clipboard-cut ace)))
      (set-on-click btn-paste (lambda (obj)
                                (declare (ignore obj))
                                (clog-ace:clipboard-paste ace)))
      (set-on-click btn-del (lambda (obj)
                              (declare (ignore obj))
                              (clog-ace:execute-command ace "del")))
      (set-on-click btn-undo (lambda (obj)
                               (declare (ignore obj))
                               (clog-ace:execute-command ace "undo")))
      (set-on-click btn-redo (lambda (obj)
                               (declare (ignore obj))
                               (clog-ace:execute-command ace "redo")))
      (set-on-click btn-efrm (lambda (obj)
                               (let ((p  (parse-integer
                                          (js-query obj
                                                    (format nil "~A.session.doc.positionToIndex (~A.selection.getCursor(), 0);"
                                                            (clog-ace::js-ace ace)
                                                            (clog-ace::js-ace ace)))
                                          :junk-allowed t))
                                     (tv (text-value ace))
                                     (lf nil)
                                     (cp 0))
                                 (loop
                                   (setf (values lf cp) (read-from-string tv nil nil :start cp))
                                   (unless lf (return nil))
                                   (when (> cp p) (return lf)))
                                 (when lf
                                   (let ((result (capture-eval lf
                                                               :clog-obj (connection-body obj)
                                                               :eval-in-package (text-value pac-line))))
                                     (on-open-file obj :title-class "w3-blue" :title "form eval" :text result))))))
      (set-on-click btn-esel (lambda (obj)
                               (let ((val (clog-ace:selected-text ace)))
                                 (unless (equal val "")
                                   (let ((result (capture-eval val :clog-obj obj
                                                                   :eval-in-package (text-value pac-line))))
                                     (on-open-file obj :title-class "w3-blue" :title "selection eval" :text result))))))

      (set-on-click btn-test (lambda (obj)
                               (let ((val (text-value ace)))
                                 (unless (equal val "")
                                   (let ((result (capture-eval val :clog-obj obj
                                                                   :eval-in-package (text-value pac-line))))
                                     (on-open-file obj :title-class "w3-blue" :title "file eval" :text result)))))))))

(defun on-repl (obj)
  "Open a REPL"
  (let* ((win (create-gui-window obj :title "CLOG Builder REPL"
                                     :top 40 :left 225
                                     :width 600 :height 400
                                     :client-movement *client-side-movement*)))
    (set-geometry (create-clog-builder-repl (window-content win))
                  :units "%" :width 100 :height 100)))

(defun on-show-callers (body)
  "Open callers window"
  (input-dialog body "Enter package:function-name :"
                (lambda (result)
                  (when result
                    (handler-case
                        (on-open-file body :title (format nil "Callers of ~A" result)
                                           :title-class "w3-orange"
                                           :text (swank::list-callers (read-from-string result)))
                      (t (c)
                        (on-open-file body :title "Error - Callers"
                                           :title-class "w3-red"
                                           :text c)))))))

(defun on-show-callees (body)
  "Open callees window"
  (input-dialog body "Enter package:function-name :"
                (lambda (result)
                  (when result
                    (handler-case
                        (on-open-file body :title (format nil "Callees of ~A" result)
                                           :title-class "w3-orange"
                                           :text (swank::list-callees (read-from-string result)))
                      (t (c)
                        (on-open-file body :title "Error - Callees"
                                           :title-class "w3-red"
                                           :text c)))))))

(defun on-dir-win (obj &key dir top left)
  "Open dir window"
  (let* ((win (create-gui-window obj :title "Directory Window"
                                     :top top :left left
                                     :width 600 :height 400
                                     :client-movement *client-side-movement*))
         (d   (create-dir-view (window-content win))))
    (set-geometry d :units "%" :width 100 :height 100)
    (when *open-external*
      (setf (checkedp (open-file-ext d)) t))
    (when dir
      (populate-dir-win d dir))))

(defun on-open-file-window (body)
  (on-new-builder body))

(defun on-open-panel-window (body)
  (on-new-builder body))

(defun on-new-builder (body &key file)
  "Launch instance of the CLOG Builder"
  (set-html-on-close body "Connection Lost")
  (let ((app        (make-instance 'builder-app-data))
        (open-file  (form-data-item (form-get-data body) "open-file"))
        (open-panel (form-data-item (form-get-data body) "open-panel")))
    (setf (connection-data-item body "builder-app-data") app)
    (setf (title (html-document body)) "CLOG Builder")
    (clog-gui-initialize body :body-left-offset 10 :body-right-offset 10)
    (add-class body "w3-blue-grey")
    (setf (z-index (create-panel body :positioning :fixed
                                      :bottom 0 :left 222
                                      :content (format nil "static-root: ~A" clog::*static-root*)))
          -9999)
    (let* ((menu  (create-gui-menu-bar body))
           (icon  (create-gui-menu-icon menu :image-url img-clog-icon
                                             :on-click  #'on-help-about-builder))
           (file  (create-gui-menu-drop-down menu :content "Builder"))
           (src   (create-gui-menu-drop-down menu :content "Project"))
           (tools (create-gui-menu-drop-down menu :content "Tools"))
           (win   (create-gui-menu-drop-down menu :content "Window"))
           (help  (create-gui-menu-drop-down menu :content "Help")))
      (declare (ignore icon))
      (create-gui-menu-item file  :content "New CLOG-GUI Panel"          :on-click 'on-new-builder-panel)
      (create-gui-menu-item file  :content "New CLOG-WEB Page"           :on-click 'on-new-builder-page)
      (create-gui-menu-item file  :content "New Basic HTML Page"         :on-click 'on-new-builder-basic-page)
      (create-gui-menu-item file  :content "New CLOG-WEB Delay Launch"   :on-click 'on-new-builder-launch-page)
      (create-gui-menu-item file  :content "New Custom Boot Page"        :on-click 'on-new-builder-custom)
      (create-gui-menu-item file  :content "New Application Template"    :on-click 'on-new-app-template)
      (create-gui-menu-item src   :content "Project Window"              :on-click 'on-show-project)
      (create-gui-menu-item src   :content "Directory Window"            :on-click 'on-dir-win)
      (create-gui-menu-item src   :content "New Source Editor"           :on-click 'on-open-file)
      (create-gui-menu-item src   :content "New Source Editor (New Tab)" :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "/source-editor")))
      (create-gui-menu-item src   :content "New System Browser"          :on-click 'on-new-sys-browser)
      (create-gui-menu-item src   :content "New ASDF System Browser"     :on-click 'on-new-asdf-browser)
      (create-gui-menu-item tools :content "Control CLOG Events"         :on-click 'on-show-control-events-win)
      (create-gui-menu-item tools :content "Control JavaScript Events"   :on-click 'on-show-control-js-events-win)
      (create-gui-menu-item tools :content "Control ParenScript Events"  :on-click 'on-show-control-ps-events-win)
      (create-gui-menu-item tools :content "Directory Window"            :on-click 'on-dir-win)
      (create-gui-menu-item tools :content "List Callers"                :on-click 'on-show-callers)
      (create-gui-menu-item tools :content "List Callees"                :on-click 'on-show-callees)
      (create-gui-menu-item tools :content "Thread Viewer"               :on-click 'on-show-thread-viewer)
      (create-gui-menu-item tools :content "CLOG Builder REPL"           :on-click 'on-repl)
      (create-gui-menu-item tools :content "Copy/Cut History"            :on-click 'on-show-copy-history-win)
      (unless *app-mode*
        (create-gui-menu-item tools :content "Image to HTML Data"        :on-click 'on-image-to-data))
      (create-gui-menu-item tools :content "Launch DB Admin"           :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "/dbadmin")))
      (create-gui-menu-item win   :content "Maximize"           :on-click
			    (lambda (obj)
			      (when (current-window obj)
			        (window-maximize (current-window obj)))))
      (create-gui-menu-item win   :content "Normalize"          :on-click
			    (lambda (obj)
			      (when (current-window obj)
			        (window-normalize (current-window obj)))))
      (create-gui-menu-item win   :content "Maximize All"       :on-click #'maximize-all-windows)
      (create-gui-menu-item win   :content "Normalize All"      :on-click #'normalize-all-windows)
      (create-gui-menu-window-select win)
      (create-gui-menu-item help  :content "CLOG Quick Start"     :on-click 'on-quick-start)
      (create-gui-menu-item help  :content "CLOG Manual"          :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "https://rabbibotton.github.io/clog/clog-manual.html")))
      (create-gui-menu-item help  :content "CLOG Tutorials"       :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "https://github.com/rabbibotton/clog/blob/main/LEARN.md")))
      (create-gui-menu-item help  :content "ParenScript Reference" :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "https://parenscript.common-lisp.dev/")))
      (create-gui-menu-item help  :content "L1sp Search"       :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "http://l1sp.org/html/")))
      (create-gui-menu-item help  :content "Lisp in Y Minutes"    :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "https://learnxinyminutes.com/docs/common-lisp/")))
      (create-gui-menu-item help  :content "Simplified Reference" :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "https://jtra.cz/stuff/lisp/sclr/index.html")))
      (create-gui-menu-item help  :content "Common Lisp Manual"   :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "http://clhs.lisp.se/")))
      (create-gui-menu-item help  :content "W3.CSS Manual"        :on-click
                            (lambda (obj)
                              (declare (ignore obj))
                              (open-window (window body) "https://www.w3schools.com/w3css/")))
      (create-gui-menu-item help  :content "About CLOG Builder"   :on-click #'on-help-about-builder)
      (create-gui-menu-full-screen menu))
    (on-show-control-properties-win body)
    (on-show-control-list-win body)
    (on-show-copy-history-win body)
    (cond
      (open-panel
       (setf (title (html-document body)) open-panel)
       (on-new-builder-panel body :open-file open-panel))
      (open-file
       (setf (title (html-document body)) open-file)
       (on-open-file body :open-file open-file :maximized t))   
      (*start-dir*
       (on-dir-win body :dir *start-dir* :top 60 :left 232))
      (t
        (on-show-project body :project *start-project*)))
    (set-on-before-unload (window body) (lambda(obj)
                                          (declare (ignore obj))
                                          ;; return empty string to prevent nav off page
                                          "")))
  (run body)
  (when *app-mode*
    (clog:shutdown)
    (uiop:quit)))

(defparameter *app-mode* nil
  "If *app-mode* is t terminates the clog-builder process on exit of the first
clog-builder window.")

(defun clog-builder (&key (port 8080) (start-browser t)
                       app project dir static-root system clogframe)
  "Start clog-builder. When PORT is 0 choose a random port. When APP is
t, shutdown applicatoin on termination of first window. If APP eq :BATCH then
must specific default project :PROJECT and it will be batch rerendered
and shutdown application. You can set the specific STATIC-ROOT or set SYSTEM
to use that asdf system's static root. if DIR then the directory window
instead of the project window will be displayed."
  (load (format nil "~A/preferences.lisp"
                (merge-pathnames "./tools/"
                                 (asdf:system-source-directory :clog)))
        :if-does-not-exist nil
        :verbose t)
  (if project
      (setf *start-project* (string-downcase (format nil "~A" project)))
      (setf *start-project* nil))
  (setf *start-dir* dir)
  (when system
    (setf static-root (merge-pathnames "./www/"
                                       (asdf:system-source-directory system))))
  (when app
    (setf *app-mode* app))
  (if static-root
      (initialize nil :port port :static-root static-root)
      (initialize nil :port port))
  (setf port clog:*clog-port*)
  (set-on-new-window 'on-new-builder :path "/builder")
  (set-on-new-window 'on-new-db-admin :path "/dbadmin")
  (set-on-new-window 'on-attach-builder-page :path "/builder-page")
  (set-on-new-window 'on-convert-image :path "/image-to-data")
  (set-on-new-window 'on-open-panel-window :path "/panel-editor")
  (set-on-new-window 'on-open-file-window :path "/source-editor")
  (when clogframe
    (uiop:run-program (list "./clogframe"
                            "CLOG Builder"
                            (format nil "~A/builder" port)
                            (format nil "~A" 1280) (format nil "~A" 840))))
  (when start-browser
    (format t "If browser does not start go to http://127.0.0.1:~A/builder" port)
    (open-browser :url (format nil "http://127.0.0.1:~A/builder" port))))
