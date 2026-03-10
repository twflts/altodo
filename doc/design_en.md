# altodo-mode Design Specification

## 1. Overview

altodo-mode is a task management major mode for Emacs. It extends __Emacs Markdown Mode__ https://github.com/jrblevin/markdown-mode to operate altodo files, making tasks easier to view and manipulate through features like face application and filtering.


## 2. Architecture

### Overall Structure

altodo.el functions as a custom extension of __Emacs Markdown Mode__ https://github.com/jrblevin/markdown-mode and follows the typical Emacs Major-mode structure.

- __Constants and Variables__ - Constant and variable definitions
- __Customizable Variables__ - Customizable variables
- __Font Lock Keywords__ - Syntax highlighting definitions
- __Keymap__ - Key binding definitions
- __Mode Definition__ - Major mode definition
- __Interactive Commands__ - User commands
- __Task Management Functions__ - Task operation functions
- __Parsing Functions__ - Text parsing functions
- __Utility Functions__ - Helper functions


### Extension Modules

- __altodo-enhanced.el__ - Progress visualization and statistics features (WIP)


### Implementation Policy

#### Plain Text Focus

- Directly manipulate buffer contents without using data structures
- Execute functions through line-by-line regex matching
- Parse text only when necessary to maintain lightweight performance
- Maximize the advantages of plain text files


#### Simple Implementation

- Maximize use of Emacs standard features
- Avoid complex caching or asynchronous processing
- Use font-lock standard features for syntax highlighting
- Add optimizations incrementally as needed


## 3. Implementation Status

### ✅ Completed Features

#### Font-lock

- 5-layer processing (Task brackets → Base → Partial elements → Emphasis → Priority)
- 29 face definitions (all task states, flags, tags, comments, date-based)
- Efficiency through integrated processing


#### Task State Management

- 5 task states (open, done, progress, waiting, cancelled)
- State toggle function (`C-c C-x`)
- State setting commands (`C-c C-t o/x/@/w/~`)


#### Flags and Priority

- Star flag (`+`)
- Priority flags (`!`, `!!`, `!!!`)


#### Comments

- Single-line comments (`///` marker)
- Multi-line comments (function-based detection)


#### Tags

- General tags (`#tag`)
- Value tags (`#key:value`)
- Special tags (`#id`, `#dep`, `#done`)
- @person tags


#### Task Move Feature

- Manual move (`C-c C-t d`)
- Auto move (timer-based)
- Done file management


#### Filtering Feature

- Parent task regex filter
- Compound condition support (AND/OR/NOT)
- Sidebar `:title` extension feature


#### Navigation Feature

- Dependency task jump (`C-c C-j`)
- Multiple buffer support


### 📋 Unimplemented Features

#### Navigation Feature

- imenu integration
- Folding feature
- Task search


#### Extension Features

- Analysis and report features
- External tool integration (Vertico/Consult)


#### Others

- `altodo-toggle-comment` command
- `#group-start`, `#group-due` tags


## 4. Specification Definition

### 4.1 Constant Definitions

#### Task State Characters

- `altodo-state-done`: `"x"` - Done task
- `altodo-state-progress`: `"@"` - In-progress task
- `altodo-state-waiting`: `"w"` - Waiting task
- `altodo-state-cancelled`: `"~"` - Cancelled task
- `altodo-state-open`: `" "` - Open task


#### Flag Characters

- `altodo-flag-star`: `"+"` - Star flag
- `altodo-flag-priority`: `"!"` - Priority flag


#### Comment and Tag Related

- `altodo-comment-marker`: `"///"` - Comment marker
- `altodo-special-tag-names`: `'("id" "group-start" "group-due" "done")` - Special tag name list
  - Note: `"dep"` is processed separately by `altodo--dep-tag-matcher`


#### Regex Definitions

##### Task Line Regex

```elisp
(defconst altodo-task-regex
  (concat "^\\([ \t]*\\)"
          "\\(\\[\\([~xw@ ]\\)\\]\\)"  ; Task state bracket
          "\\(?: \\(.*\\)\\)?$")        ; Task body (optional)
  "Regex matching a task line.")
```

**Structure**:
- `^` - Line start
- `[ \t]*` - Leading whitespace (indent)
- `\\[[~xw@ ]\\]` - Task state bracket (`[ ]`, `[@]`, `[w]`, `[x]`, `[~]`)
- `\\(?: \\(.*\\)\\)?$` - Task body (optional)


##### Comment Line Regex

```elisp
(defconst altodo-comment-regex
  (format "^\\([ \t]*\\)%s \\(.*\\)$"
          (regexp-quote altodo-comment-marker))
  "Regex matching a comment line.")
```

**Structure**:
- `^` - Line start
- `[ \t]*` - Leading whitespace (indent)
- `/// ` - Comment marker
- `\\(.*\\)$` - Comment body


##### Tag Regex

```elisp
(defconst altodo-tag-regex
  (concat "\\(?:^\\|[ \t]\\)"        ; Line start or after whitespace
          "\\(#\\)"                  ; # tag start
          "\\(" altodo-tag-name-regex "\\)"  ; Tag name
          "\\(?::\\([^ \t\n]*\\)\\)?")      ; Value (optional)
  "Regex matching a tag.")
```

**Structure**:
- `\\(?:^\\|[ \t]\\)` - Line start or after whitespace
- `#` - Tag start
- Tag name (`altodo-tag-name-regex`)
- `:value` (optional)


##### Date Regex

```elisp
(defconst altodo-date-regex
  (concat "\\([0-9]\\{4\\}[-/][0-9]\\{2\\}[-/][0-9]\\{2\\}\\)"  ; Date
          "\\(?: -> \\)?"                                        ; Arrow (optional)
          "\\(?:\\([0-9]\\{4\\}[-/][0-9]\\{2\\}[-/][0-9]\\{2\\}\\)\\)?")  ; End date
  "Regex matching a date range.")
```

**Structure**:
- `YYYY-MM-DD` or `YYYY/MM/DD` format date
- ` -> ` arrow (optional)
- End date (optional)


#### Task State Character List

```elisp
(defconst altodo-task-state-chars
  (concat altodo-state-done altodo-state-progress
          altodo-state-waiting altodo-state-cancelled)
  "List of task state characters.")
```

**Value**: `"x@w~"`


### 4.2 Customizable Variables

| Variable Name                         | Default               | Description                            |
|---------------------------------------|-----------------------|----------------------------------------|
| `altodo-indent-size`                  | 4                     | Indent size                            |
| `altodo-auto-save`                    | t                     | Enable/disable auto-save               |
| `altodo-font-lock-maximum-decoration` | t                     | Maximize font-lock decoration          |
| `altodo-done-tag-format`              | `"%Y-%m-%d_%H:%M:%S"` | Done tag timestamp format              |
| `altodo-due-warning-days`             | 7                     | Days before due date to show warning   |
| `altodo-due-urgent-days`              | 2                     | Days before due date to show urgent    |
| `altodo-date-patterns`                | YYYY-MM-DD format     | Supported date format pattern list     |
| `altodo-done-file-prefix`             | `"_done"`             | Done file prefix                       |
| `altodo-auto-move-enabled`            | t                     | Enable/disable auto-move               |
| `altodo-auto-move-interval`           | 3600                  | Auto-move execution interval (seconds) |
| `altodo-auto-save-after-move`         | t                     | Auto-save source file after move       |


### 4.3 Face Definitions

#### Task State Faces

| Face                         | Description          |
|------------------------------|----------------------|
| `altodo-task-open-face`      | For open tasks       |
| `altodo-task-done-face`      | For done tasks       |
| `altodo-task-progress-face`  | For in-progress tasks|
| `altodo-task-waiting-face`   | For waiting tasks    |
| `altodo-task-cancelled-face` | For cancelled tasks  |

#### Task Text Faces

| Face                              | Description                              |
|-----------------------------------|------------------------------------------|
| `altodo-task-open-text-face`      | For open task text (light green)         |
| `altodo-task-done-text-face`      | For done task text (strikethrough)       |
| `altodo-task-progress-text-face`  | For in-progress task text (magenta)      |
| `altodo-task-waiting-text-face`   | For waiting task text (light gray)       |
| `altodo-task-cancelled-text-face` | For cancelled task text (strikethrough)  |

#### Comment Faces

| Face                            | Description                      |
|---------------------------------|----------------------------------|
| `altodo-comment-face`           | For single-line comments (red)   |
| `altodo-multiline-comment-face` | For multi-line comments (gray)   |

#### Flag Faces

| Face                         | Description                     |
|------------------------------|---------------------------------|
| `altodo-flag-star-face`      | For star flag (gold bold)       |
| `altodo-flag-priority1-face` | For priority 1 flag (red)       |
| `altodo-flag-priority2-face` | For priority 2 flag (red bold)  |
| `altodo-flag-priority3-face` | For priority 3 flag (red bold)  |

#### Tag and Date Faces

| Face                      | Description                      |
|---------------------------|----------------------------------|
| `altodo-tag-face`         | For general tags (purple)        |
| `altodo-tag-value-face`   | For tag values (dark purple bold)|
| `altodo-special-tag-face` | For special tags (magenta bold)  |
| `altodo-date-face`        | For dates (blue)                 |

#### Dependency Faces

| Face                           | Description                        |
|--------------------------------|------------------------------------|
| `altodo-dep-blocked-text-face` | For dependency blocked (red)       |
| `altodo-dep-blocked-tag-face`  | For dependency blocked tag (red)   |
| `altodo-dep-ready-tag-face`    | For dependency ready tag (green)   |
| `altodo-dep-error-tag-face`    | For dependency error (red bold)    |


### 4.4 Keymap

| Key         | Function               | Function Name                     | Description                                                 |
|-------------|------------------------|-----------------------------------|-------------------------------------------------------------|
| `TAB`       | Indent operation       | `altodo-indent-line`              | Make/unmake subtask                                         |
| `RET`       | Newline/new task       | `altodo-enter`                    | Context-aware newline processing                            |
| `C-c C-x`   | Task state toggle      | `altodo-toggle-task-state`        | Toggle open ↔ done                                         |
| `C-c C-t o` | Open task              | `altodo-set-task-open`            | Change to `[ ]`                                             |
| `C-c C-t x` | Done task              | `altodo-set-task-done`            | Change to `[x]`                                             |
| `C-c C-t @` | In-progress task       | `altodo-set-task-progress`        | Change to `[@]`                                             |
| `C-c C-t w` | Waiting task           | `altodo-set-task-waiting`         | Change to `[w]`                                             |
| `C-c C-t ~` | Cancelled task         | `altodo-set-task-cancelled`       | Change to `[~]`                                             |
| `C-c C-t d` | Move done task         | `altodo-move-done-tasks-at-point` | Move done/cancelled task at cursor/region to done file     |
| `C-c C-a`   | Add task               | `altodo-add-task`                 | Add subtask or new task                                     |
| `C-c C-m`   | Start multiline comment| `altodo-start-multiline-comment`  | Start multiline comment                                     |
| `C-c C-s`   | Toggle star flag       | `altodo-toggle-star-flag`         | Toggle `+` flag                                             |
| `C-c C-f 1` | Set priority 1         | `altodo-set-priority-1`           | Set `!` flag                                                |
| `C-c C-f 2` | Set priority 2         | `altodo-set-priority-2`           | Set `!!` flag                                               |
| `C-c C-f 3` | Set priority 3         | `altodo-set-priority-3`           | Set `!!!` flag                                              |
| `C-c C-v f c` | Clear filter         | `altodo-filter-clear`             | Clear all filters                                           |
| `C-c C-v s t` | Toggle sidebar       | `altodo-sidebar-toggle`           | Toggle sidebar visibility                                   |
| `C-c C-v s r` | Refresh sidebar      | `altodo-sidebar-refresh`          | Refresh sidebar content                                     |
| `C-c =`     | Toggle comment         | `altodo-toggle-comment`           | Toggle task ↔ comment                                      |


## 4. Configuration File (.altodo-locals.el)

altodo manages buffer-local settings in `.altodo-locals.el` file.


### 4.1 File Placement

Place `.altodo-locals.el` in the same directory as the altodo file.


### 4.2 Format

Multiple variables can be specified in alist format:

```elisp
(
 ;; Filter patterns
 (altodo-filter-patterns .
  (
   (:title "Status" :type group-header :nest 0)
   (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
   (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
   (:title "@Person - %n" :type dynamic :dynamic-type person :count-format t :nest 1)
   (:title "#Tag - %n" :type dynamic :dynamic-type tag :count-format t :nest 1)
   (:title "Priority - %n" :type search-simple :pattern "priority" :count-format t :nest 1
    :face-rules ((>= 5 error)
                 (>= 1 warning)))
   (:title "" :type separator :nest 0)
   (:title "[Clear]" :type command :command altodo-filter-clear :nest 0)
   ))
 
 ;; Sidebar face definitions
 (altodo-sidebar-face-alist .
  ((done-face . ((t (:foreground "green"))))
   (error-face . ((t (:foreground "red"))))
   (warning-face . ((t (:foreground "orange"))))))
 )
```


### 4.3 Configurable Variables

`.altodo-locals.el` can specify any variable in alist format. The implementation simply reads the file as Lisp data, so there are no restrictions.

| Variable Name               | Description                                 |
|-----------------------------|---------------------------------------------|
| `altodo-filter-patterns`    | Sidebar filter pattern list                 |
| `altodo-sidebar-face-alist` | Sidebar face definitions                    |
| `altodo-sidebar-position`   | Sidebar display position (`left` or `right`)|
| `altodo-sidebar-size`       | Sidebar width (characters)                  |
| `altodo-sidebar-indent`     | Sidebar indent width                        |

**Example**:

```elisp
(
 (altodo-filter-patterns . (...))
 (altodo-sidebar-face-alist . (...))
 (altodo-sidebar-position . right)
 (altodo-sidebar-size . 30)
 )
```


### 4.4 Default Settings

If the file does not exist, use the following default values:

- `altodo-filter-patterns` → `altodo--default-filter-patterns` variable
- Sidebar faces → Default faces


## 5. Feature Specifications

### 5.1 Task State Management

5 task states:

| State     | Mark  | Description                    |
|-----------|-------|--------------------------------|
| Open      | `[ ]` | Task before execution          |
| Progress  | `[@]` | Task currently in progress     |
| Waiting   | `[w]` | Task on hold (waiting state)   |
| Done      | `[x]` | Completed task                 |
| Cancelled | `[~]` | Task cancelled before completion|


### 5.2 Flags and Priority

#### Star Flag

- Flag: `+`
- Usage: Particularly important tasks
- Example: `[ ] + Task with star flag`


#### Priority Flags

- Flags: `!`, `!!`, `!!!`
- Usage: Task prioritization based on importance
- Example: `[ ] !!! Highest priority task`


### 5.3 Comments

#### Single-line Comment

- Marker: `///`
- Example: `/// This is a single-line comment`


#### Multi-line Comment

- Indented lines immediately following a task line or single-line comment line
- Indent rule: Parent line indent + 4 spaces
- Ends with blank line (no indent)


#### Multi-line Comment Termination Detection

Multi-line comments end with **blank line (no indent)**.

**Detection Logic**:

```elisp
(defun altodo--multiline-comment-p ()
  "Check if current line is part of a multiline comment.
Returns t if in multiline comment, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (let ((indent (current-indentation)))
      (cond
       ;; Single-line comment is not multiline comment
       ((looking-at-p (format "^%s[ \t]*$"
                             (regexp-quote altodo-comment-marker)))
        nil)
       ;; No indent means end of multiline comment
       ((= indent 0)
        nil)
       ;; With indent means continuation of multiline comment
       (t t)))))
```

**Processing**:
1. If current line is single-line comment line (`///` only), end
2. If current line has no indent, end
3. If current line has indent, continue


### 5.4 Tags

#### General Tags

- Format: `#tag`
- Example: `[ ] Do task at #home`


#### Value Tags

- Format: `#key:value`
- Example: `[ ] #work-by:john`


#### Special Tags

| Tag                 | Description                      |
|---------------------|----------------------------------|
| `#id:value`         | Unique identifier                |
| `#dep:value`        | Dependency (specify reference ID)|
| `#group-start:date` | Group task start date            |
| `#group-due:date`   | Group task due date              |
| `#done:timestamp`   | Task completion/cancellation time|


#### @person Tags

- Format: `@person`
- Usage: Specify assignee/location
- Example: `[ ] Task @john to confirm`


### 5.5 Date System

#### Start Date and Due Date

- Start date: `YYYY-MM-DD ->`
- Due date: `-> YYYY-MM-DD`
- Both: `YYYY-MM-DD -> YYYY-MM-DD`


#### Date-based Coloring

- Start date exceeded: Gray
- Due date exceeded: Red bold
- Due date today: Red
- Due date urgent: Bold


### 5.6 Dependency Management

#### #id Tag

- Usage: Unique task identification
- Example: `[ ] Task #id:20250101-0000`


#### #dep Tag

- Usage: Specify dependency
- Example: `[ ] Dependent task #dep:20250101-0000`


### 5.7 Task Move Feature

#### Manual Move

- Command: `altodo-move-done-tasks-at-point`
- Key binding: `C-c C-t d`
- Target: Done (`[x]`) and cancelled (`[~]`) tasks + multi-line comments


#### Auto Move

- Timer-based (global timer)
- Execution interval: `altodo-auto-move-interval` (default: 3600 seconds)
- Target: All open altodo buffers


#### Done File

- Naming convention: `[filename]_done.altodo`
- Prefix: Configurable with `altodo-done-file-prefix`


### 5.8 Filtering Feature

#### Parent Task Regex Filter

- Variables: `parent-task-regexp`, `root-task-regexp`
- Usage: Extract tasks under specific parent task


#### Compound Condition Support

- Combination with AND/OR/NOT conditions
- Simultaneous application of multiple filters


#### Sidebar Feature

- Display match count with `%n` placeholder in `:title`
- `:count-format` option: Enable/disable count processing
- `:type` option: Specify filter type (nil, "comment", "group-header", "dynamic")


## 6. Markdown Integration and Code Block Handling

### 6.0 markdown-pre Countermeasures and Code Block Support

**Problem 1**: markdown-mode recognizes indented lines (4+ spaces) as "indented code blocks" and applies the `markdown-pre` text property. This causes altodo task lines and comment lines to be displayed with `markdown-pre-face` (light blue color).

**Solution 1**: Use `font-lock-remove-keywords` to exclude `markdown-match-pre-blocks` from font-lock-keywords.

**Implementation Location**: Inside `define-derived-mode altodo-mode` body

```elisp
;; Disable markdown-mode's indented code block highlighting
(font-lock-remove-keywords nil '((markdown-match-pre-blocks (0 'markdown-pre-face))))
```

**Impact Range**:
- `markdown-pre-face` is no longer applied within altodo-mode buffers
- No impact on altodo files since indented code blocks (Markdown spec) are not used
- Does not modify `syntax-propertize-function`, respecting Emacs design principles

---

**Problem 2**: altodo-mode faces are applied inside Markdown fenced code blocks (` ``` ` / `~~~`).

**Solution 2**: Use `altodo--restore-code-block-faces` to overwrite altodo faces with markdown faces inside fenced code blocks.

**Implementation Location**: Inside `define-derived-mode altodo-mode` body

```elisp
;; Restore markdown faces in fenced code blocks
(let ((orig-fn font-lock-fontify-region-function))
  (setq-local font-lock-fontify-region-function
              (lambda (beg end &optional loudly)
                (funcall orig-fn beg end loudly)
                (altodo--restore-code-block-faces beg end))))
```

**Helper Function**:

```elisp
(defun altodo--restore-code-block-faces (beg end)
  "Restore markdown faces in fenced code blocks between BEG and END.
Overwrites altodo faces with markdown-pre-face and markdown-code-face.
Only targets fenced code blocks (``` or ~~~), not indented code blocks."
  (save-excursion
    (goto-char beg)
    (while (< (point) end)
      (when (or (get-text-property (point) 'markdown-gfm-code)
                (get-text-property (point) 'markdown-fenced-code))
        (put-text-property (line-beginning-position) (line-end-position)
                           'face '(markdown-pre-face markdown-code-face)))
      (forward-line 1))))
```

**Text Property Types**:
- `markdown-gfm-code`: Backtick fenced blocks (` ``` `)
- `markdown-fenced-code`: Tilde fenced blocks (`~~~`)

**Impact Range**:
- altodo faces inside fenced code blocks are overwritten with markdown faces
- Indented comment lines (multi-line comments) are not affected (no text property)

---

## 6. Font-lock Design

### 6.1 Processing Order (Layer Structure)

```
Layer 1: Task Brackets (apply blocked face to state character)
  ├── Bracket
  ├── State character
  └── Bracket
  ↓
Layer 2: Base (entire text)
  ├── seq-tasks blocked task text (process first)
  ├── Normal task text
  ├── Waiting task text
  └── In-progress task text
  ↓
Layer 3: (Empty - tags moved to Layer 4)
  ↓
Layer 4: Emphasis (date-based text, flag text, tags, dates)
  ├── Date-based text (change entire text color)
  ├── Priority flags (3 levels)
  ├── Star flag
  ├── General tags (with/without value)
  ├── @person tags
  ├── Special tags
  ├── Dependency tags
  ├── Date arrows
  ├── Start date
  └── Due date
  ↓
Layer 5: Priority (entire comments, strikethrough)
  ├── Multi-line comments
  ├── Multi-line comment lists
  ├── Single-line comments
  └── Done/cancelled task strikethrough
```


### 6.3 Override Flag Strategy

| Layer | Element                  | Override Flag | Reason                                                     |
|-------|--------------------------|---------------|------------------------------------------------------------|
| 1     | Bracket/state character  | `t`           | Finalize bracket and state character faces                 |
| 2     | Entire text              | `append`      | Prioritize markdown-mode faces, add altodo-mode faces      |
| 3     | (Empty)                  | -             | Tags moved to Layer 4                                      |
| 4     | Date-based text          | `prepend`     | Stack multiple faces                                       |
| 4     | Flag (symbol part)       | `t`           | Finalize flag symbol face                                  |
| 4     | Flag (text part)         | `prepend`     | Stack multiple faces                                       |
| 4     | Tags/dates               | `t`           | Finalize tag and date faces                                |
| 5     | Comments                 | `prepend`     | Stack multiple faces                                       |
| 5     | Strikethrough            | `t`           | Finalize strikethrough face                                |


### 6.4 seq-tasks Implementation

#### seq-tasks blocked State Detection

- Layer 1: Apply `altodo-dep-blocked-text-face` to state character
- Layer 2.5: Apply `altodo-task-waiting-text-face` to entire text (process first)
- Layer 2: Apply `altodo-task-open-text-face` to normal task text (process later)


#### Helper Functions

- `altodo--has-seq-tasks-tag()`: Check if current line has seq-tasks tag
- `altodo--get-seq-tasks-parent()`: Get parent task (with seq-tasks tag) of current line
- `altodo--get-seq-tasks-children()`: Get direct child tasks of current line
- `altodo--line-seq-tasks-blocked-p()`: Check if current line is seq-tasks blocked
- `altodo--is-seq-tasks-child-blocked-p()`: Check if current line is seq-tasks child blocked


## 7. Font-lock Design

### 7.1 Utility Functions

#### `altodo--normalize-state (state-str)`

- Argument: `state-str` - State string
- Return: Normalized state string
- Description: Normalize task state string


#### `altodo--get-state-face (state)`

- Argument: `state` - Task state character
- Return: Corresponding face symbol
- Description: Get face corresponding to task state


#### `altodo--get-state-text-face (state)`

- Argument: `state` - Task state character
- Return: Corresponding text face symbol
- Description: Get text face corresponding to task state


### 7.2 Task State Operation Functions

#### `altodo-toggle-task-state ()`

- Description: Toggle current line task state


#### `altodo-set-task-open ()`

- Description: Set current line task to open state


#### `altodo-set-task-done ()`

- Description: Set current line task to done state


#### `altodo-set-task-progress ()`

- Description: Set current line task to in-progress state


#### `altodo-set-task-waiting ()`

- Description: Set current line task to waiting state


#### `altodo-set-task-cancelled ()`

- Description: Set current line task to cancelled state


### 7.3 Date Processing Functions

#### `altodo--parse-date (date-str)`

- Argument: `date-str` - Date string
- Return: `(year month day)` list or nil
- Description: Parse date string and convert to list format


#### `altodo--days-diff (date-time)`

- Argument: `date-time` - Date
- Return: Day difference (integer)
- Description: Calculate day difference between specified date and today


#### `altodo--determine-start-date-face (date-str)`

- Argument: `date-str` - Date string
- Return: Face symbol or nil
- Description: Determine face to apply based on start date


#### `altodo--determine-due-date-face (date-str)`

- Argument: `date-str` - Date string
- Return: Face symbol or nil
- Description: Determine face to apply based on due date


### 7.4 Line Detection Functions

#### `altodo--task-p ()`

- Return: t or nil
- Description: Determine if current line is a task line


#### `altodo--comment-p ()`

- Return: t or nil
- Description: Determine if current line is a single-line comment line


#### `altodo--multiline-comment-p ()`

- Return: t or nil
- Description: Check if current line is a multi-line comment


### 7.5 Indent Support Functions

#### `altodo-indent-line ()`

- Description: Smartly adjust current line indent


#### `altodo-enter ()`

- Description: Enter key processing (newline and indent)


#### `altodo-add-task ()`

- Description: Add subtask or new task based on current line type


#### `altodo-start-multiline-comment ()`

- Description: Start multi-line comment from task line or single-line comment line


### 7.6 Font-lock Matcher Functions

#### `altodo--start-date-matcher (limit)`

- Argument: `limit` - Search limit position
- Return: t or nil
- Description: Start date matcher


#### `altodo--due-date-matcher (limit)`

- Argument: `limit` - Search limit position
- Return: t or nil
- Description: Due date matcher


#### `altodo--multiline-comment-matcher (limit)`

- Argument: `limit` - Search limit position
- Return: t or nil
- Description: Font-lock matcher for multi-line comment processing


## 9. References

- `doc/altodo_spec.md` - altodo format specification (Japanese)
- `doc/altodo_spec_en.md` - altodo format specification (English)
- `doc/design.md.backup_*` - Detailed design (pre-deletion versions)
- `doc/tmp_design.md` - Implementation details section (for detailed design)
- `.kiro/memo/` - Development notes
