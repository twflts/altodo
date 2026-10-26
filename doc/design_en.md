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
- Cache only results that are expensive to recompute (counts during one rendering, heading ranges, the contents of the configuration file). The only asynchronous processing is the auto-move timer
- Use font-lock standard features for syntax highlighting
- Add optimizations incrementally as needed


## 3. Specification Definition

### 3.1 Constant Definitions

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
- `altodo-special-tag-names`: `'("id" "group-start" "group-due" "done" "seq-tasks")` - Special tag name list
  - Note: `"dep"` is processed separately by `altodo--dep-tag-matcher`


#### Regex Definitions

The implementation defines the following constants.

- `altodo-task-regex`: a task line. The value is `^\([ ]*\)\[\([x@w~ ]?\)\]\(.*\)$`. Group 1 is the indentation at the beginning of the line, group 2 is the state character, and group 3 is the string after the state mark
- `altodo-comment-regex`: a single-line comment line. The value is `^\([ \t]*\)/// \(.*\)$`
- `altodo-tag-with-value-regex`: a tag with a value. The value is `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\):\("[^"]*"\|[^[:space:]]+\)`. The value can be enclosed in double quotes
- `altodo-tag-without-value-regex`: a tag without a value. The value is `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\)\b`
- `altodo-special-tag-regex`: special tags. Generated from `altodo-special-tag-names`

The date regular expression is not a constant. `altodo--date-regex-info` generates it at run time from `altodo-date-format` (the default `nil` means `YYYY-MM-DD`).


#### Task State Character List

`altodo-task-state-chars` is the string `"x@w~"`, the state characters of done, in-progress, waiting and cancelled joined together.


### 3.2 Customizable Variables

| Variable                                       | Default        | Description                                               |
| ---------------------------------------------- | -------------- | --------------------------------------------------------- |
| `altodo-indent-size`                           | `4`            | Indentation size                                          |
| `altodo-enable-markdown-in-multiline-comments` | `t`            | Enable Markdown formatting in multi-line comments         |
| `altodo-auto-save`                             | `nil`          | Save the file automatically when a task state changes     |
| `altodo-skk-wrap-newline`                      | `t`            | Wrap newline commands for SKK input method compatibility  |
| `altodo-inline-code-cache`                     | `t`            | Keep the inline code spans while fontifying               |
| `altodo-done-tag-datetime-format`              | `nil`          | Time format of `#done` (`nil` is ISO 8601 with time zone) |
| `altodo-use-local-timezone`                    | `t`            | Use the local time zone for the `#done` time              |
| `altodo-insert-id-format`                      | `'tiny-random` | ID format of `#id`                                        |
| `altodo-date-format`                           | `nil`          | Date format (`nil` is `YYYY-MM-DD`)                       |
| `altodo-week-start-day`                        | `0`            | First day of the week (0 is Sunday, 1 is Monday)          |
| `altodo-done-file-prefix`                      | `"_done"`      | String added to the done file name                        |
| `altodo-move-unit`                             | `'subtree`     | Unit of the move (`subtree` or `line`)                    |
| `altodo-auto-move-interval`                    | `3600`         | Interval of the automatic move (seconds, positive)        |
| `altodo-move-after-days`                       | `nil`          | Days from `#done` to the move (`nil`: at once)            |
| `altodo-auto-save-after-move`                  | `nil`          | Save the source file after a move                         |
| `altodo-auto-move-skip-done-files`             | `t`            | Exclude done files from the automatic move                |
| `altodo-show-auto-move-in-mode-line`           | `t`            | Show the automatic move state in the mode line            |

For the sidebar variables, see "Settings" in `README_en.md`.


### 3.3 Face Definitions

The main faces are listed. All faces (including date states, `@person`, the sidebar, the calendar and the agenda) are available with `M-x customize-group RET altodo RET`.


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


### 3.4 Keymap

The keys fall into four groups by the kind of line where they are active. On any other line, a key calls the `markdown-mode` binding of the same key (`altodo--on-line`).


#### All Lines

| Key           | Function                 | Description                                            |
| ------------- | ------------------------ | ------------------------------------------------------ |
| `TAB`         | `altodo-indent-line`     | Indent/outdent a subtask (depends on the kind of line) |
| `RET`         | `altodo-enter`           | Context-aware newline                                  |
| `<backtab>`   | `outline-cycle`          | Cycle the outline                                      |
| `C-c C-v f c` | `altodo-filter-clear`    | Clear the filter                                       |
| `C-c C-v s t` | `altodo-sidebar-toggle`  | Toggle the sidebar                                     |
| `C-c C-v s r` | `altodo-sidebar-refresh` | Refresh the sidebar                                    |


#### Task Lines

| Key         | Function                          | Description                           |
| ----------- | --------------------------------- | ------------------------------------- |
| `C-c C-x`   | `altodo-toggle-task-state`        | Toggle open ↔ done                   |
| `C-c C-t o` | `altodo-set-task-open`            | Set to open                           |
| `C-c C-t x` | `altodo-set-task-done`            | Set to done                           |
| `C-c C-t @` | `altodo-set-task-progress`        | Set to in progress                    |
| `C-c C-t w` | `altodo-set-task-waiting`         | Set to waiting                        |
| `C-c C-t ~` | `altodo-set-task-cancelled`       | Set to cancelled                      |
| `C-c C-t d` | `altodo-move-done-tasks-at-point` | Move finished tasks to the done file  |
| `C-c C-t D` | `altodo-move-done-task-alone`     | Move only the line of a finished task |


#### Task Lines and Single-line Comment Lines

| Key                   | Function                            | Description                         |
| --------------------- | ----------------------------------- | ----------------------------------- |
| `C-c C-a`             | `altodo-add-task`                   | Add a task                          |
| `M-RET`               | `altodo-add-subtask`                | Add a subtask                       |
| `C-c C-m`             | `altodo-start-multiline-comment`    | Start a multi-line comment          |
| `C-c C-s`             | `altodo-toggle-star-flag`           | Toggle the star flag                |
| `C-c C-f 1`, `2`, `3` | `altodo-set-priority-1`, `-2`, `-3` | Set the priority                    |
| `C-c C-e d`           | `altodo-select-due-calendar`        | Choose the due date in a calendar   |
| `C-c C-e s`           | `altodo-select-start-calendar`      | Choose the start date in a calendar |
| `C-c C-i`             | `altodo-insert-id`                  | Insert `#id`                        |
| `C-c C-j`             | `altodo-goto-dependency`            | Jump to the dependency task         |

`altodo-add-task` adds a task with the same indentation after the subtree of the current line (its multi-line comment, `///` lines and descendant tasks; `altodo--subtree-end`). `altodo-add-subtask` adds it as the last child, one level deeper. `RET` calls `altodo-add-task` on a task line or `///` line. On an empty task line it removes the marker; on a multi-line comment line it continues on the next line with the same indentation.

`altodo-set-priority-1`, `-2` and `-3` remove the priority on a line that already has that priority (the star stays).


#### Task Lines, Single-line Comment Lines and Multi-line Comment Lines

| Key                     | Function                                           | Description              |
| ----------------------- | -------------------------------------------------- | ------------------------ |
| `M-<right>`, `M-<left>` | `altodo-indent-increase`, `altodo-indent-decrease` | Increase/decrease indent |

On a task line or `///` line, `altodo-indent-increase` and `altodo-indent-decrease` move the multi-line comment of the line by the same width. Child tasks do not move.

`altodo-toggle-comment` (toggle between task and comment) has no key binding. Run it with `M-x`.


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

Only the following five variables are read from `.altodo-locals.el` (`altodo--get-locals-value`). Other variables in the file are not used.

| Variable Name               | Description                                               |
| --------------------------- | --------------------------------------------------------- |
| `altodo-filter-patterns`    | Sidebar filter pattern list                               |
| `altodo-sidebar-face-alist` | Sidebar face definitions                                  |
| `altodo-sidebar-position`   | Sidebar position (`left`, `right`, `above`, `below`)      |
| `altodo-sidebar-size`       | Width or height; below 1 a frame ratio, else columns/rows |
| `altodo-sidebar-indent`     | Sidebar indent width                                      |

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


#### Abnormal Configuration Files

- If the file has a syntax error or its content is not an alist, a warning is shown and the default settings are used, as when the file does not exist
- An entry of `altodo-filter-patterns` that is not a plist with a string `:title` is ignored with a warning; the other entries are used
- A warning is shown once for the same content each time the file is modified
- When the value of an entry is invalid and the entry cannot be drawn (`:nest` is not an integer, a lambda that counts signals an error, and so on), a message is shown once and only that entry is left out. The other entries are drawn (section 7 of `doc/design-filter.md`)


### 4.5 Execution of Code in the Configuration File

The following code in `.altodo-locals.el` runs according to `altodo-locals-code-policy`.

- The `:pattern` (lambda) of `:type search-lambda`, and `:count-pattern-lambda`
- A `:command` that is not a command of this package (the name does not start with altodo-)

| Value     | Behavior                                                                                    |
| --------- | ------------------------------------------------------------------------------------------- |
| `deny`    | Default. The code does not run                                                              |
| `confirm` | Runs if the SHA-256 of the file is in `altodo-trusted-locals`. Otherwise asks when selected |
| `allow`   | Always runs                                                                                 |

- Entries whose code does not run are still shown in the sidebar. The count is shown as `?`, and `:face-rules` is not evaluated. Selecting such an entry shows a message that the code does not run (`confirm` asks for trust instead)
- Trusting a file under `confirm` saves its absolute path and SHA-256 to `altodo-trusted-locals` (`customize-save-variable`). The trust ends when the content of the file changes
- Code in `altodo-default-filter-patterns` (the Emacs configuration) is not subject to the policy. Only entries from the configuration file are
- `:face-rules` evaluates only the operators `<`, `>`, `<=`, `>=`, `=` and `/=`. Rules with other operators are ignored


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


#### Using a Star and a Priority Together

- They can be used together, in either order, each at most once on a line
- The commands (`altodo-set-priority-1` to `3`, `altodo-toggle-star-flag`) write the star first, then the priority, and keep the other flag
- `altodo--parse-flags` parses them


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

Detection is performed line by line, using regular expressions and the state of the previous line. An indented line is not treated as a Markdown indented code block (section 6.1).


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
| `#group-start:date` | Group start date (color only)     |
| `#group-due:date`   | Group due date (color only)       |
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


#### Date Input

The following commands set a date on the task line (or `///` line) at point. On any other line they signal a `user-error`.

- `altodo-select-due-calendar` (`C-c C-e d`) and `altodo-select-start-calendar` (`C-c C-e s`): open a `calendar` window and set the date with `RET`; `q` cancels. The week starts on `altodo-week-start-day`, and the cursor starts at the date on the line
- `altodo-input-due-date` and `altodo-input-start-date`: enter the date in the minibuffer with `calendar-read-date`
- The format follows `altodo-date-format`. An existing date of the same kind is replaced. Otherwise a due date is added at the end of the line as `-> DATE` and a start date as `DATE ->`. If the other date exists, the arrow is shared (`START -> DUE`)


#### Dates That Do Not Exist

A date that does not exist, such as `2026-02-30`, is not treated as a date. `altodo--parse-date` returns nil, the date gets the plain date face, and it matches no start or due date condition. Relative conditions (`today`, `overdue`, etc.) use the real date whatever `altodo-date-format` is.


#### Date-based Coloring

The difference from today decides the face of the date and of the task text. `altodo--determine-due-date-face` and `altodo--determine-start-date-face` decide the date face; `altodo--due-overdue-severe-text-matcher` and `altodo--start-not-yet-text-matcher` decide the text face. Days are calendar days in the local time zone.

| Condition                    | Date face                       | Task text face                          |
| ---------------------------- | ------------------------------- | --------------------------------------- |
| Due 3 or more days ago       | `altodo-date-due-overdue-face`  | `altodo-due-overdue-severe-text-face`   |
| Due 1 or 2 days ago          | `altodo-date-due-overdue-face`  | unchanged                               |
| Due today                    | `altodo-date-due-today-face`    | unchanged                               |
| Due in 1 to 3 days           | `altodo-date-due-soon-face`     | unchanged                               |
| Due in 4 or more days        | `altodo-date-face`              | unchanged                               |
| Start date today or earlier  | `altodo-date-start-active-face` | unchanged                               |
| Start date tomorrow or later | `altodo-date-face`              | `altodo-start-not-yet-text-face` (gray) |
| A date that does not exist   | `altodo-date-face`              | unchanged                               |
| Done or cancelled task       | same face as the text (strike)  | done or cancelled face                  |

When both the due date and the start date match a condition, each date is colored by its own condition. The text faces are stacked.


### 5.6 Dependency Management

#### #id Tag

- Usage: Unique task identification
- Example: `[ ] Task #id:20250101-0000`


#### #dep Tag

- Usage: Specify dependency
- Example: `[ ] Dependent task #dep:20250101-0000`


#### Abnormal IDs and Dependencies

- A `#id` value matches only when it is followed by a space or the end of the line. `#id:T1` does not match `#id:T1-2`
- If the same `#id` appears more than once, only the first one is used. The later ones are never referenced and cause no error
- A `#dep` on the task itself and a circular `#dep` are "circular", shown with `altodo-dep-error-tag-face`
- A `#dep` on an `#id` that does not exist is treated as having no dependency (ready)


### 5.7 Task Move Feature

#### Manual Move

- Command: `altodo-move-done-tasks-at-point`
- Key binding: `C-c C-t d`
- Target: when the task at point is done (`[x]`) or cancelled (`[~]`), that task is moved. Whether its descendants are included depends on "Unit of the Move"


#### Auto Move

- Timer-based (global timer)
- Execution interval: `altodo-auto-move-interval` (default: 3600 seconds)
- Target: All open altodo buffers


#### Done File

- Naming convention: `[filename]_done.altodo`
- Prefix: Configurable with `altodo-done-file-prefix`


#### Unit of the Move

- The unit of the move is chosen with `altodo-move-unit` (`subtree` or `line`). The default is `subtree`
- `subtree`: A completed or cancelled task is moved with its descendants (subtasks, `///` lines and multi-line comments). If a descendant is not done, nothing is moved: a `user-error` by hand, skipped by the batch and automatic moves. The batch move and the automatic move handle only tasks without a parent, so a done subtask waits until the whole subtree is done. The manual move moves the subtree of a subtask even if its parent is not done. In the done file, the root is written with indent 0 and the relative indent of the descendants is kept
- `line`: Only the task line and its multi-line comments are moved. Subtasks stay in the source buffer, and a done subtask leaves its parent
- `altodo-move-done-task-alone` (`C-c C-t D`) moves in the `line` unit whatever `altodo-move-unit` is
- If `altodo-move-after-days` is a number N, the batch and automatic moves take only tasks whose `#done` date is N or more days ago. The manual move is not affected. A task without a `#done` tag, or with a value that is not a date, is not moved. With `subtree`, every task of the subtree must meet the condition. The date is read as the date part of ISO 8601, a Unix time in seconds, or a date in `altodo-date-format`
- The date of `#done` is the date in the time zone of the time that was written, and today's date is counted in the local time zone. If `altodo-use-local-timezone` is `nil` (recorded in UTC), the date of `#done` can differ from the local date by up to one day, so the judgment can be off by up to one day. The UTC offset of an ISO 8601 value is not used. Reason: the implementation judges by the date part only, and using the offset would treat it differently from a value with only a date or a Unix time


#### Preconditions and Abnormal Cases of the Move

- Preconditions: the buffer is writable, and the done file is writable (not a directory, and its parent directory is writable). If they are not met, nothing is moved and a `user-error` is signaled. This prevents the state where the append to the done file succeeds but the deletion from the source buffer fails
- Writing: write a temporary file in the same directory and replace the done file with `rename-file`. If the write fails, the done file keeps its content
- If a buffer visits the done file, the entry is appended to that buffer. The buffer is saved if it had no unsaved changes; otherwise it is not saved and a message says so
- In the automatic move, if the move fails in one buffer, a message is shown and the other buffers are still processed. A read-only buffer is not moved, and a message is shown
- `altodo-auto-move-interval` must be a positive number. Otherwise the timer is not set and a `user-error` is signaled


### 5.8 Filtering Feature

The specifications of sidebar entries, DSL patterns, dynamic filters, the calendar, the agenda and heading jump are in `doc/design-filter.md`. This section gives only an overview.

- Entry types: specified with `:type`. `nil`, `comment`, `group-header`, `separator`, `command`, `dynamic`, `search-simple`, `search-lambda`, `calendar`, `agenda`
- Conditions: written as DSL patterns, combined with `and:`, `or:` and `not:`. Selecting several entries combines them with AND or OR
- Parent task conditions: the DSL patterns `parent-task-regexp:REGEXP` and `root-task-regexp:REGEXP` extract the tasks under a specific parent task
- Count: `%n` in `:title` shows the number of matches. `:count-format` specifies whether the count is calculated


## 6. Font-lock Design

### 6.1 Coexistence with markdown-mode

altodo-mode is derived from markdown-mode. When fontifying, it adjusts three behaviors of markdown-mode.


#### Excluding Indented Code Blocks

- markdown-mode recognizes lines indented by 4 or more spaces as an "indented code block" and sets the `markdown-pre` text property. altodo expresses nesting and multi-line comments with indentation, so task lines and comment lines would otherwise get `markdown-pre-face` (light blue)
- The body of `define-derived-mode altodo-mode` calls `font-lock-remove-keywords` to remove `markdown-match-pre-blocks` from font-lock-keywords. `syntax-propertize-function` is not changed
- altodo does not use indented code blocks, so this exclusion has no effect on altodo files

The detection of task lines, single-line comment lines and multi-line comment lines (`altodo--task-p`, `altodo--comment-p`, `altodo--multiline-comment-p`) only checks whether the line is inside a fenced code block (`altodo--in-fenced-code-block-p`). Indented code blocks are not considered.


#### Restoring Faces in Fenced Code Blocks

- altodo faces are also applied inside fenced code blocks (` ``` ` and `~~~`)
- `altodo--restore-code-block-faces` replaces the faces of the lines in fenced code blocks, within the fontified region, with `markdown-pre-face` and `markdown-code-face`. It wraps `font-lock-fontify-region-function` and runs after the original function. The wrapper returns the `(jit-lock-bounds BEG . END)` of the original function (the region that was fontified, widened to whole lines and so on) and restores the faces in that region
- The target lines are those with the text property `markdown-gfm-code` (backtick fences) or `markdown-fenced-code` (tilde fences). Indented multi-line comment lines do not have this property and are not affected


#### Keeping the Inline Code Spans

- The italic and bold matchers of markdown-mode call `markdown-inline-code-at-pos` for each candidate. That function searches the code spans again from the start of the text block (the lines up to a blank line) to the candidate. A list of tasks has few blank lines, so a block has hundreds of lines, and the fontification time grows with the square of its length
- When `altodo-inline-code-cache` is non-`nil`, the function that wraps `font-lock-fontify-region-function` (`altodo--call-with-inline-code-cache`) replaces `markdown-inline-code-at-pos` with `altodo--inline-code-at-pos` during the call only. Loading the file does not change the function of markdown-mode
- The replacement searches the code spans of a block once (`markdown-match-code`) and goes on from where it stopped. The result is kept with `buffer-chars-modified-tick` as the key, until a character changes. For a position inside the same block, the bounds of the block are kept too. The result, and the match data left when a candidate is rejected, are the same as those of the function of markdown-mode
- The following blocks are left to the function of markdown-mode, because text properties of comments and fences decide the result, and the result cannot be kept while they are not final
    - A block with `<!--`, ` ``` ` or `~~~`
    - A block that `syntax-propertize` has not finished up to its end


### 6.2 Processing Order (Layer Structure)

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
Layer 3: Emphasis (date-based text, flag text, tags, dates)
  ├── Date-based text (change entire text color)
  ├── Priority flags (3 levels)
  ├── Star flag
  ├── Flags of `///` lines
  ├── General tags (with/without value)
  ├── @person tags
  ├── Special tags
  ├── Dependency tags
  ├── Date arrows
  ├── Start date
  └── Due date
  ↓
Layer 4: Priority (entire comments, strikethrough)
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
| 3     | Date-based text         | `prepend`     | Stack multiple faces                                  |
| 3     | Flag (symbol part)      | `t`           | Finalize flag symbol face                             |
| 3     | Flag (text part)        | `prepend`     | Stack multiple faces                                  |
| 3     | Tags/dates              | `t`           | Finalize tag and date faces                           |
| 4     | Comments                | `prepend`     | Stack multiple faces                                  |
| 4     | Strikethrough           | `t`           | Finalize strikethrough face                           |


### 6.4 seq-tasks Implementation

#### seq-tasks blocked State Detection

A child of a task with `#seq-tasks` is blocked while the sibling right above it is neither done nor cancelled. The first child is never blocked. The parent (the task with `#seq-tasks`) is not blocked.

- Layer 1: Apply `altodo-dep-blocked-text-face` to state character
- Layer 2.5: Apply `altodo-task-waiting-text-face` to entire text (process first)
- Layer 2: Apply `altodo-task-open-text-face` to normal task text (process later)


#### Helper Functions

- `altodo--has-seq-tasks-tag()`: Check if current line has seq-tasks tag
- `altodo--is-seq-tasks-child-blocked-p()`: Check if the current line is a child of a task with `#seq-tasks` whose sibling right above it is not done (a line without indentation has no parent and is not checked)


### 6.5 Fontification Speed

The following three are kept so that the fontification time does not grow with the square of the number of lines. Measure it with `scripts/bench-fontlock.sh`. The samples are `sections` (a blank line after every 48 tasks) and `contiguous` (few blank lines, many `///` lines).

- The inline code spans (section 6.1)
- Index of `#id:`: `altodo--id-index` keeps the position of the first tag of each ID in a hash table. The key is `buffer-chars-modified-tick`, `point-min`, `point-max` and `case-fold-search`. A change of text properties (fontification) does not rebuild it. `altodo--find-task-by-id` and `altodo--check-circular-dependency` use it
- Fenced block test: `altodo--in-fenced-code-block-p` does not call `markdown-get-enclosing-fenced-block-construct` if the buffer has no ```, `~~~` or `---` (nor `...` if `markdown-use-pandoc-style-yaml-metadata` is non-`nil`) (`altodo--fence-marker-in-buffer-p`). markdown-mode returns the YAML metadata at the top as an enclosing block, besides the fences, so `---` is a condition too. The result is kept with the key (`buffer-chars-modified-tick`, `point-min` and `point-max`)
- Loops of the matchers: `altodo--tag-matcher`, `altodo--tag-with-value-matcher` and `altodo--person-tag-matcher` skip the candidates on lines that are not task lines and so on, without a limit on their number. `altodo--dep-tag-matcher` searches once (it does not repeat a failed search)
- Search for the parent of a `#seq-tasks` child: `altodo--is-seq-tasks-child-blocked-p` does not search if the buffer has no `#seq-tasks` above the current line (`altodo--seq-tasks-above-p`). The search looks only at task lines with the indentation of the current line or less, with `re-search-backward`, so it skips the lines of the descendants of siblings. `altodo--dep-blocked-text-matcher` looks only at lines with `#dep:`, not at every task line


## 7. References

- `doc/altodo_spec.md` - altodo format specification (Japanese)
- `doc/altodo_spec_en.md` - altodo format specification (English)
- `doc/design-filter.md` - Filter design document (includes DSL specification)
