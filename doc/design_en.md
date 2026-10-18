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
- 50 face definitions (all task states, flags, tags, comments, date-based)
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

- Key binding for `altodo-toggle-comment` (the command itself is implemented)
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

The implementation defines the following constants.

- `altodo-task-regex`: a task line. The value is `^\([ ]*\)\[\([x@w~ ]?\)\]\(.*\)$`. Group 1 is the indentation at the beginning of the line, group 2 is the state character, and group 3 is the string after the state mark
- `altodo-comment-regex`: a single-line comment line. The value is `^\([ \t]*\)/// \(.*\)$`
- `altodo-tag-with-value-regex`: a tag with a value. The value is `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\):\("[^"]*"\|[^[:space:]]+\)`. The value can be enclosed in double quotes
- `altodo-tag-without-value-regex`: a tag without a value. The value is `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\)\b`
- `altodo-person-tag-regex`: an @person tag. The value is `\(?:^\|[[:space:]]\)\(@[^[:space:]]+\)`
- `altodo-special-tag-regex`: special tags. Generated from `altodo-special-tag-names`

The date regular expression is not a constant. `altodo--date-regex-info` generates it at run time from `altodo-date-format` (the default `nil` means `YYYY-MM-DD`).


#### Task State Character List

```elisp
(defconst altodo-task-state-chars
  (concat altodo-state-done altodo-state-progress
          altodo-state-waiting altodo-state-cancelled)
  "List of task state characters.")
```

**Value**: `"x@w~"`


### 4.2 Customizable Variables

| Variable                                       | Default        | Description                                               |
| ---------------------------------------------- | -------------- | --------------------------------------------------------- |
| `altodo-indent-size`                           | `4`            | Indentation size                                          |
| `altodo-enable-markdown-in-multiline-comments` | `t`            | Enable Markdown formatting in multi-line comments         |
| `altodo-auto-save`                             | `nil`          | Save the file automatically when a task state changes     |
| `altodo-skk-wrap-newline`                      | `t`            | Wrap newline commands for SKK input method compatibility  |
| `altodo-font-lock-maximum-decoration`          | `t`            | Maximize font-lock decoration                             |
| `altodo-done-tag-datetime-format`              | `nil`          | Time format of `#done` (`nil` is ISO 8601 with time zone) |
| `altodo-use-local-timezone`                    | `t`            | Use the local time zone for the `#done` time              |
| `altodo-insert-id-format`                      | `'tiny-random` | ID format of `#id`                                        |
| `altodo-date-format`                           | `nil`          | Date format (`nil` is `YYYY-MM-DD`)                       |
| `altodo-week-start-day`                        | `1`            | First day of the week (0 is Sunday, 1 is Monday)          |
| `altodo-done-file-prefix`                      | `"_done"`      | String added to the done file name                        |
| `altodo-move-single-line-comments-manually`    | `t`            | Enable manual move of single-line comments                |
| `altodo-auto-move-interval`                    | `3600`         | Interval of the automatic move (seconds)                  |
| `altodo-auto-save-after-move`                  | `nil`          | Save the source file after a move                         |
| `altodo-auto-move-skip-done-files`             | `t`            | Exclude done files from the automatic move                |
| `altodo-show-auto-move-in-mode-line`           | `t`            | Show the automatic move state in the mode line            |

For the sidebar and debug variables, see "Settings" in `README_en.md`.


### 4.3 Face Definitions

#### Task State Faces

| Face                         | Description           |
| ---------------------------- | --------------------- |
| `altodo-task-open-face`      | For open tasks        |
| `altodo-task-done-face`      | For done tasks        |
| `altodo--task-progress-face` | For in-progress tasks |
| `altodo-task-waiting-face`   | For waiting tasks     |
| `altodo-task-cancelled-face` | For cancelled tasks   |


#### Task Text Faces

| Face                              | Description                             |
| --------------------------------- | --------------------------------------- |
| `altodo-task-open-text-face`      | For open task text (light green)        |
| `altodo-task-done-text-face`      | For done task text (strikethrough)      |
| `altodo--task-progress-text-face` | For in-progress task text (magenta)     |
| `altodo-task-waiting-text-face`   | For waiting task text (light gray)      |
| `altodo-task-cancelled-text-face` | For cancelled task text (strikethrough) |


#### Comment Faces

| Face                            | Description                    |
| ------------------------------- | ------------------------------ |
| `altodo-comment-face`           | For single-line comments (red) |
| `altodo-multiline-comment-face` | For multi-line comments (gray) |


#### Flag Faces

| Face                         | Description                    |
| ---------------------------- | ------------------------------ |
| `altodo-flag-star-face`      | For star flag (gold bold)      |
| `altodo-flag-priority1-face` | For priority 1 flag (red)      |
| `altodo-flag-priority2-face` | For priority 2 flag (red bold) |
| `altodo-flag-priority3-face` | For priority 3 flag (red bold) |


#### Tag and Date Faces

| Face                      | Description                       |
| ------------------------- | --------------------------------- |
| `altodo-tag-face`         | For general tags (purple)         |
| `altodo-tag-value-face`   | For tag values (dark purple bold) |
| `altodo-special-tag-face` | For special tags (magenta bold)   |
| `altodo-date-face`        | For dates (blue)                  |


#### Dependency Faces

| Face                           | Description                      |
| ------------------------------ | -------------------------------- |
| `altodo-dep-blocked-text-face` | For dependency blocked (red)     |
| `altodo-dep-blocked-tag-face`  | For dependency blocked tag (red) |
| `altodo-dep-ready-tag-face`    | For dependency ready tag (green) |
| `altodo-dep-error-tag-face`    | For dependency error (red bold)  |


### 4.4 Keymap

On lines other than task lines and single-line comment lines, each key calls the `markdown-mode` binding.

| Key                             | Function                                                               | Description                           |
| ------------------------------- | ---------------------------------------------------------------------- | ------------------------------------- |
| `TAB`                           | `altodo-indent-line`                                                   | Make/unmake a subtask                 |
| `RET`                           | `altodo-enter`                                                         | Context-dependent newline             |
| `<backtab>`                     | `outline-cycle`                                                        | Cycle the outline                     |
| `C-c C-x`                       | `altodo-toggle-task-state`                                             | Toggle open ↔ completed              |
| `C-c C-t o`, `x`, `@`, `w`, `~` | `altodo-set-task-open`, `-done`, `-progress`, `-waiting`, `-cancelled` | Set the state                         |
| `C-c C-t d`                     | `altodo-move-done-tasks-at-point`                                      | Move a finished task to the done file |
| `C-c C-a`                       | `altodo-add-task`                                                      | Add a task                            |
| `M-RET`                         | `altodo-add-subtask`                                                   | Add a subtask                         |
| `C-c C-m`                       | `altodo-start-multiline-comment`                                       | Start a multi-line comment            |
| `C-c C-s`                       | `altodo-toggle-star-flag`                                              | Toggle the star flag                  |
| `C-c C-f 1`, `2`, `3`           | `altodo-set-priority-1`, `-2`, `-3`                                    | Set the priority                      |
| `C-c C-i`                       | `altodo-insert-id`                                                     | Insert `#id`                          |
| `C-c C-j`                       | `altodo-goto-dependency`                                               | Jump to the dependency task           |
| `M-<right>`, `M-<left>`         | `altodo-indent-increase`, `altodo-indent-decrease`                     | Increase/decrease the indentation     |
| `C-c C-v f c`                   | `altodo-filter-clear`                                                  | Clear the filter                      |
| `C-c C-v s t`                   | `altodo-sidebar-toggle`                                                | Toggle the sidebar                    |
| `C-c C-v s r`                   | `altodo-sidebar-refresh`                                               | Refresh the sidebar                   |

`altodo-toggle-comment` (toggle task ↔ comment) has no key binding. Run it with `M-x`.


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

| Variable Name               | Description                                  |
| --------------------------- | -------------------------------------------- |
| `altodo-filter-patterns`    | Sidebar filter pattern list                  |
| `altodo-sidebar-face-alist` | Sidebar face definitions                     |
| `altodo-sidebar-position`   | Sidebar display position (`left` or `right`) |
| `altodo-sidebar-size`       | Sidebar width (ratio to the window width)    |
| `altodo-sidebar-indent`     | Sidebar indent width                         |

**Example**:

```elisp
(
 (altodo-filter-patterns . (...))
 (altodo-sidebar-face-alist . (...))
 (altodo-sidebar-position . right)
 (altodo-sidebar-size . 0.3)
 )
```


### 4.4 Default Settings

If the file does not exist, use the following default values:

- `altodo-filter-patterns` → `altodo-default-filter-patterns` variable
- Sidebar faces → Default faces


## 5. Feature Specifications

### 5.1 Task State Management

5 task states:

| State     | Mark  | Description                      |
| --------- | ----- | -------------------------------- |
| Open      | `[ ]` | Task before execution            |
| Progress  | `[@]` | Task currently in progress       |
| Waiting   | `[w]` | Task on hold (waiting state)     |
| Done      | `[x]` | Completed task                   |
| Cancelled | `[~]` | Task cancelled before completion |


### 5.2 Flags and Priority

#### Star Flag

- Flag: `+`
- Usage: Particularly important tasks
- Example: `[ ] + Task with star flag`


#### Lines That Accept Flags

- A flag is placed immediately after the task state mark of a task line, or immediately after `///` of a single-line comment line
- One space is required after the flag


#### Priority Flags

- Flags: `!`, `!!`, `!!!`
- Usage: Task prioritization based on importance
- Example: `[ ] !!! Highest priority task`


### 5.3 Comments

#### Single-line Comment

- Marker: `///`
- Usage: A detached note (a side remark, a review memo) that is not part of the task
- Example: `/// This is a single-line comment`
- A flag (`+`, `!`) can be added. Example: `/// ! Important note`


#### Multi-line Comment

- Attaches to: the task line or single-line comment line immediately above
- Usage: The description of the task, as part of the task
- Example: the line `    Description of the task` after `[ ] Task`


#### Multi-line Comment Detection Rules

The details of the specification follow section 3.2.3 of `doc/altodo_spec_en.md`. The detection rules are as follows.

- The first line begins with the indentation of the task line or single-line comment line above it + 4 spaces. There is no exception
- Every line with the same indentation as the first line, other than a task line, is part of the comment. This includes Markdown lists, links, and fenced code blocks
- Subsequent lines have the same indentation as the previous multi-line comment line. A line that keeps the indentation but contains only spaces is also part of the comment
- A line with a different indentation (shallower or deeper) or a completely empty line (zero characters) ends the comment. A more deeply indented line, such as a nested Markdown list item, is not part of the comment
- A line starting with a task state mark is always a task line

Detection is performed line by line, using regular expressions and the state of the previous line. An indented line is not treated as a Markdown indented code block (section 6.0).


### 5.4 Tags

#### General Tags

- Format: `#tag`
- Example: `[ ] Do task at #home`


#### Value Tags

- Format: `#key:value`
- Example: `[ ] #work-by:john`


#### Special Tags

| Tag                 | Description                       |
| ------------------- | --------------------------------- |
| `#id:value`         | Unique identifier                 |
| `#dep:value`        | Dependency (specify reference ID) |
| `#group-start:date` | Group task start date             |
| `#group-due:date`   | Group task due date               |
| `#done:timestamp`   | Task completion/cancellation time |
| `#seq-tasks`        | Subtasks run from top to bottom   |


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


#### Limitations

- The current version does not keep the nested (tree) structure of tasks. Only the lines of the completed or cancelled task and their multi-line comments are moved under the heading. Subtasks remain in the source buffer
- A future improvement is planned to move subtasks together


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
- `:type` option: Specify filter type (`nil`, `comment`, `group-header`, `separator`, `command`, `dynamic`, `search-simple`, `search-lambda`)


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

| Layer | Element                 | Override Flag | Reason                                                |
| ----- | ----------------------- | ------------- | ----------------------------------------------------- |
| 1     | Bracket/state character | `t`           | Finalize bracket and state character faces            |
| 2     | Entire text             | `append`      | Prioritize markdown-mode faces, add altodo-mode faces |
| 3     | (Empty)                 | -             | Tags moved to Layer 4                                 |
| 4     | Date-based text         | `prepend`     | Stack multiple faces                                  |
| 4     | Flag (symbol part)      | `t`           | Finalize flag symbol face                             |
| 4     | Flag (text part)        | `prepend`     | Stack multiple faces                                  |
| 4     | Tags/dates              | `t`           | Finalize tag and date faces                           |
| 5     | Comments                | `prepend`     | Stack multiple faces                                  |
| 5     | Strikethrough           | `t`           | Finalize strikethrough face                           |


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


## 8. References

- `doc/altodo_spec.md` - altodo format specification (Japanese)
- `doc/altodo_spec_en.md` - altodo format specification (English)
- `doc/design-filter.md` - Filter design document (includes DSL specification)
- `doc/design.md.backup_*` - Detailed design (pre-deletion versions)
- `doc/tmp_design.md` - Implementation details section (for detailed design)
- `.kiro/memo/` - Development notes
