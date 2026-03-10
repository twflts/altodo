# Filtering Feature Design Document

## 1. Overview

### Purpose

Implement filtering functionality in altodo-mode to filter tasks and comments based on conditions. Based on the filtering functionality, implement a sidebar (buffer) feature that makes it easy to select filters and displays status and filter counts.


### Feature List

- **Hide Filter**: Hide lines that don't match conditions
- **Background Color Change**: Change background color of lines that don't match conditions (optional) (WIP)
- **Clear**: Remove filters and display all lines
- **Multiple Conditions**: Filter by state, tags, priority, dates, etc.
- **Compound Conditions**: Combination with AND/OR/NOT conditions
- **Sidebar Integration**: Filter selection from sidebar


## 2. Functional Requirements

### Filter Types

| Filter           | Description                                    |
|------------------|------------------------------------------------|
| State Filter     | done, progress, waiting, open, cancelled       |
| Tag Filter       | Filter by `#tag`                               |
| @person Filter   | Filter by `@person`                            |
| Priority Filter  | Filter by `!` flag                             |
| Due Date Filter  | Filter by overdue, within due date, etc.       |
| Dynamic Filter   | Auto-collect values from buffer and filter     |
| Parent Task Filter | Filter by parent task conditions             |


### Compound Conditions

- **AND**: Match all conditions
- **OR**: Match any condition
- **NOT**: Don't match condition


## 3. Technical Selection

### Implementation Method

**Use overlay + buffer-invisibility-spec**

Reasons:
- Non-destructive (doesn't change buffer contents)
- Fast (`buffer-invisibility-spec` changes are very fast)
- Standard feature (official Emacs feature)
- Flexible (can manage multiple types of filters)


### Alternative Options and Rejection Reasons

| Method                       | Rejection Reason                                |
|------------------------------|-------------------------------------------------|
| `keep-lines` / `flush-lines` | Destructive (deletes buffer contents)           |
| `occur-mode`                 | Displays in separate buffer (doesn't change original) |
| text property                | Subject to undo/redo                            |


### Performance Requirements

- Within 1 second for 5000-line buffer
- Filtering is not subject to undo/redo


## 4. Basic Design Principles

### Filtering Flow

1. **predicate function**: Determine if each line matches condition (`t` = show, `nil` = hide)
2. **Matching**: Get range of lines matching condition
3. **Inversion**: Convert to range of lines not matching condition
4. **overlay creation**: Set `invisible` property on hidden ranges


### predicate Function Specification

**Input**: None (called with `(point)` at line beginning)

**Output**:
- `t`: This line **matches** condition (line to show)
- `nil`: This line **doesn't match** condition (line to hide)

**Example**:
```elisp
;; Show done tasks
(lambda ()
  (looking-at "^[ ]*\\[x\\]"))

;; Show lines containing @person
(lambda ()
  (save-excursion
    (re-search-forward "@person\\>" (line-end-position) t)))
```


### Helper Function Specification

**Naming Convention**: `altodo--line-*-p` - Determine if current line matches condition

**Return Value**: `t` (matches condition), `nil` (doesn't match condition)


### DSL Compiler Specification

`altodo--compile-filter-predicate`: Generate predicate function from DSL expression

**Example**:
```elisp
;; Input
(state done)

;; Output
(lambda ()
  (altodo--line-done-p))
```


## 5. Architecture

### Component Structure

```
altodo-filter
├── Internal Functions (altodo--*)
│   ├── altodo--filter-init          ; Initialization
│   ├── altodo--filter-lines         ; Filtering
│   ├── altodo--filter-cleanup       ; Cleanup
│   ├── altodo--compile-filter-predicate ; DSL compilation
│   └── altodo--combine-predicates   ; Predicate combination
├── Sidebar Functions (sidebar--*)
│   ├── sidebar--render              ; Sidebar rendering
│   ├── sidebar--insert-entry        ; Entry insertion
│   ├── sidebar--get-face            ; Face retrieval
│   └── sidebar--apply-filter        ; Filter application
├── User Commands (altodo-filter-*)
│   ├── altodo-filter-clear          ; Clear
│   ├── altodo-filter-show-done-only
│   ├── altodo-filter-show-progress-only
│   └── ...
└── Variables
    ├── altodo--filter-overlays      ; List of overlays
    ├── altodo--filter-mode          ; Filter mode
    └── altodo-sidebar--selected-filters ; Selected filters
```

### Data Flow

```
User Command / Sidebar Selection
    ↓
DSL Pattern / Filter Entry
    ↓
altodo--compile-filter-predicate
    ↓
predicate function
    ↓
altodo--filter-lines / sidebar--apply-filter
    ↓
Check each line in order
    ↓
Create overlay on lines not matching condition
    ↓
Set 'invisible property on overlay
    ↓
Hidden by buffer-invisibility-spec
```


## 6. Detailed Design

### 6.1 Variables

#### altodo--filter-overlays

```elisp
(defvar-local altodo--filter-overlays nil
  "List of overlays used for filtering.")
```

**Description**: List of overlays created for filtering
**Usage**: Delete all overlays when clearing


#### altodo--filter-mode

```elisp
(defvar-local altodo--filter-mode nil
  "Current filter mode.")
```

**Description**: Current filter mode
**Value**: Symbol (`'done`, `'progress`, `'tag`, etc.) or `nil`


#### altodo-sidebar--selected-filters

```elisp
(defvar-local altodo-sidebar--selected-filters nil
  "List of selected filter entries.")
```

**Description**: List of filters selected in sidebar


#### altodo-sidebar--combine-mode

```elisp
(defvar-local altodo-sidebar--combine-mode 'and
  "Filter combination mode: 'and or 'or.")
```

**Description**: Filter combination mode


### 6.2 Internal Functions

#### altodo--filter-init

**Description**: Initialize filter system
**Operation**: Add `'altodo-filter` to `buffer-invisibility-spec`


#### altodo--filter-lines

**Description**: Hide lines not matching predicate
**Input**: `predicate` function
**Output**: List of overlays


#### altodo--filter-cleanup

**Description**: Cleanup filter system
**Operation**: Delete all overlays


#### altodo--compile-filter-predicate

**Description**: Generate predicate function from DSL expression
**Input**: DSL s-expression
**Output**: predicate function


#### altodo--combine-predicates

**Description**: Combine multiple predicates
**Input**: List of predicates, combination mode (`and`/`or`)
**Output**: Combined predicate function


### 6.3 Sidebar Rendering Process

#### sidebar--insert-entry

**Description**: Insert entry into sidebar
**Process**:

1. Determine `action` based on `:type`
   - For `'(separator group-header comment nil)`: `action` = `nil` (not clickable)
   - Otherwise: `action` = `#'altodo-sidebar--apply-filter` (clickable)

2. Determine face based on `:type`
   - `nil` or `comment`: `'altodo-sidebar-comment-face`
   - `group-header`: `'altodo-sidebar-group-header-face`
   - `search-simple`: `'altodo-sidebar-search-simple-face`
   - `search-lambda`: `'altodo-sidebar-search-lambda-face`
   - `command`: `'altodo-sidebar-command-face`
   - `separator`: `'altodo-sidebar-separator-face`
   - Otherwise: `'default`

3. If clickable: Create button with `insert-button`
4. If not clickable: Insert text (no button)


#### sidebar--get-face

**Description**: Determine entry face (Layer structure)

**Processing Order**:

```
Layer 1: Selection (highest priority)
  ↓ Selected filter entry
Layer 2: COUNT (face-rules / count-face-rules)
  ↓ Face based on count
Layer 3: Default (:face specification)
  ↓ If :face is specified in entry
Layer 4: Type-based (default face)
  ↓ Default face based on :type
Layer 5: Non-clickable (comment lines, etc.)
  ↓ Non-clickable entries
```

**face-rules Fallback**:
- If face-rules don't match, fallback to face specified by `:face`
- If `:face` is not specified either, use default face


#### sidebar--apply-filter

**Description**: Apply filter
**Process**:

1. Apply filter based on `:type`
   - `search-simple`: Compile DSL pattern to generate predicate
   - `search-lambda`: Use lambda function as predicate
   - `command`: Execute specified command
   - `dynamic`: Auto-collect values and expand
   - `nil`/`comment`/`group-header`/`separator`: No filter

2. Apply predicate with `altodo--filter-lines`


### 6.4 Dynamic Filter Expansion

#### altodo--expand-dynamic-filter

**Description**: Expand dynamic filter entry

**Process**:

1. Collect values from buffer with `altodo--collect-dynamic-values-*`
   - `person`: Collect `@person` tag values
   - `tag`: Collect `#tag` values
   - `due`: Collect `#due:DATE` values
   - `start`: Collect `#start:DATE` values

2. Sort with `altodo--sort-dynamic-values`
   - `alpha`: Alphabetical order
   - `count`: Match count order
   - `reverse-count`: Reverse match count order

3. Limit with `altodo--limit-dynamic-values`
   - Limit to number specified by `:limit`
   - If `nil`, no limit

4. Generate `search-simple` entry from each value
   - Replace `%s` in `:title` with value
   - Auto-generate `:pattern` (e.g., `person:NAME`)


#### 6.4.1 altodo--get-entry-count

**Description**: Count number of tasks matching entry

**Input**:
- `entry`: Filter entry plist
- `source-buffer`: Source buffer
- `combined-predicate`: Combined filter predicate (optional)

**Process**:

1. Generate predicate based on entry `:type`
   - `search-simple`: Compile DSL pattern
   - `search-lambda`: Use lambda function as predicate
   - `dynamic`: Use expanded predicate

2. Traverse task lines in buffer
   - Count only task lines (`[ ]`, `[@]`, `[w]`, `[x]`, `[~]`)
   - Don't count comment lines (if `:count-exclude-others` is `t`)

3. Apply predicate and count matches
   - If `combined-predicate` is specified, apply both

**Return Value**: Number of matched tasks (integer)


#### 6.4.2 altodo--format-sidebar-title

**Description**: Format and return entry title

**Input**:
- `pattern-spec`: Filter entry plist
- `source-buffer`: Source buffer
- `combined-predicate`: Combined filter predicate (optional)
- `combine-mode`: Combination mode (`'and` or `'or`)

**Process**:

1. Detect `%n` in `:title`

2. If `%n` exists, calculate count
   - Get match count with `altodo--get-entry-count`

3. Apply face to count
   - Evaluate if `count-face-rules` is specified
   - Apply if `face-count` is specified
   - If neither specified, use `:face` or default

4. Replace `%n` with count number
   - Apply face property to count string

**Return Value**: Formatted title string


### 6.6 Compound Condition Filter

#### Processing for Multiple Selection

1. User selects multiple entries
2. Determine combination mode with `altodo-sidebar--combine-mode`
   - `'and`: Match all predicates
   - `'or`: Match any predicate

3. Combine predicates with `altodo--combine-predicates`
   - Collect predicates from all selected entries
   - Combine based on combination mode

4. Apply combined predicate to `altodo--filter-lines`


### 6.7 User Commands

| Command                             | Description                      |
|-------------------------------------|----------------------------------|
| `altodo-filter-clear`               | Clear all filters                |
| `altodo-filter-show-done-only`      | Show only done tasks             |
| `altodo-filter-show-progress-only`  | Show only progress tasks         |
| `altodo-filter-show-waiting-only`   | Show only waiting tasks          |
| `altodo-filter-show-open-only`      | Show only open tasks             |
| `altodo-filter-show-cancelled-only` | Show only cancelled tasks        |
| `altodo-filter-show-tag`            | Show tasks with specified tag    |
| `altodo-filter-show-priority`       | Show tasks with priority flag    |
| `altodo-filter-show-star`           | Show tasks with star flag        |
| `altodo-filter-show-overdue`        | Show overdue tasks               |
| `altodo-filter-show-person`         | Show tasks for specified person  |
| `altodo-filter-and`                 | Switch to AND mode               |
| `altodo-filter-or`                  | Switch to OR mode                |
| `altodo-filter-not`                 | Apply NOT condition              |


## 7. Sidebar Integration

### Filter Entry Structure

```elisp
(list
 :title "Filter Name"
 :predicate predicate-function
 :action filter-action
 :type nil  ; nil, "comment", "group-header", "dynamic"
 :nest 0
 :count-format nil
 :count-exclude-others t
 :face nil
 :face-rules nil)
```


### Dynamic Filter

**`:type "dynamic"`** entries auto-collect values on display:

- `@person` - List of assignees
- `#tag` - List of tags
- `#due` - List of due dates
- `#start` - List of start dates


### Compound Condition Filter

**`:type nil`** entries can be selected multiple:

- Switch AND/OR with `altodo-sidebar--combine-mode`
- Combine predicates with `altodo--combine-predicates`


## 8. Key Bindings

### Filter Operations

| Key       | Function             |
|-----------|----------------------|
| `C-c C-f` | Show filter menu     |
| `C-c C-c` | Clear filter         |

### Sidebar Operations

| Key       | Function             |
|-----------|----------------------|
| `C-SPC`   | Select/deselect filter |
| `C-c C-a` | Switch to AND mode   |
| `C-c C-o` | Switch to OR mode    |
| `C-c C-t` | Toggle AND/OR        |


## 9. Mode Line Display

### Filter Status Display

```
[Filter: done] [AND] (Single)
```

- **Filter: filter name** - Current filter
- **[AND]/[OR]** - Combination mode
- **(Single)/(Multiple)** - Selection mode


## 10. Performance

### Optimization

1. **predicate cache**: Reuse same predicate
2. **heading-range cache**: Cache heading ranges
3. **Line-by-line processing**: Process one line at a time, reduce unnecessary goto-char


### Benchmark Goals

- 5000-line buffer: Within 1 second
- Dynamic filter update: Within 100ms


## 11. Face Application Priority (Layer Structure)

### Layer 1: Selection (highest priority)

Applied to selected filter entry


### Layer 2: COUNT

Face application based on count (`:count-face-rules`)


### Layer 3: Default

If `:face` is specified in entry


### Layer 4: Type-based

Default face based on entry `:type`


### Layer 5: Non-clickable

Non-clickable entries (`"comment"`, `"group-header"`)


## 12. References

- `doc/design.md` - Overall design document
- `doc/altodo_spec.md` - Format specification
- `project.altodo` - Implementation plan
- `.kiro/memo/` - Development notes


## 13. altodo-filter-patterns Specification

### 13.1 Overview

`altodo-filter-patterns` is a list defining filter patterns to display in sidebar.
Set in `.altodo-locals.el` file or `altodo--default-filter-patterns` variable.


### 13.2 Entry Structure

Each filter entry is defined as plist (property list):

```elisp
(:title "Display Name" :type TYPE :nest 0 ...)
```


### 13.3 Common Properties

| Property                | Required   | Description                                                 |
|-------------------------|------------|-------------------------------------------------------------|
| `:title`                | Required   | Title to display in sidebar. `%n` displays match count     |
| `:type`                 | Required   | Entry type (described later)                                |
| `:nest`                 | Optional   | Indent level (default: 0)                                   |
| `:count-format`         | Optional   | `t` to replace `%n` with count (default: `t`)               |
| `:face`                 | Optional   | Face to apply                                               |
| `:face-count`           | Optional   | Face to apply to count part `%n`                            |
| `:display-context`      | Optional   | Display context (`'all`: all, `'heading-only`: headings only, `'none`: match lines only) |
| `:count-exclude-others` | Optional   | `t` to count only task lines (default: `nil`)               |


### 13.4 Entry Types (`:type`)

#### `"comment"` or `nil` (Comment Line)

Not clickable, no filter applied. Used for visual separators or explanatory text.

| Property                | Required/Optional | Description                    |
|-------------------------|-------------------|--------------------------------|
| `:face`                 | Optional          | Face to apply                  |
| `:count-exclude-others` | Optional          | `t` to count only task lines   |


#### `"group-header"` (Group Header)

Not clickable, visual separator

| Property | Required/Optional | Description                  |
|----------|-------------------|------------------------------|
| None     | -                 | Doesn't function as filter   |


#### `"dynamic"` (Dynamic Filter)

Auto-collect values on display

| Property             | Required/Optional | Description                                         |
|----------------------|-------------------|-----------------------------------------------------|
| `:dynamic-type`      | Required          | Collection target (`person`, `tag`, `due`, `start`) |
| `:exclude-person`    | Optional          | List of `@person` to exclude                        |
| `:exclude-tag`       | Optional          | List of `#tag` to exclude                           |
| `:exclude-tag-value` | Optional          | List of `#tag:value` to exclude                     |
| `:sort`              | Optional          | Sort method (`alpha`, `count`, `reverse-count`)     |
| `:limit`             | Optional          | Display limit (default: nil = unlimited)            |


#### `"search-simple"` (Simple Search)

DSL pattern match. Describe filter condition with DSL pattern string. See "13.5 DSL Syntax" for details

| Property   | Required/Optional | Description        |
|------------|-------------------|--------------------|
| `:pattern` | Required          | DSL pattern string |

**DSL Pattern Examples**:

```elisp
;; Done tasks
(:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)

;; Tasks with priority flag
(:title "Priority - %n" :type search-simple :pattern "priority" :count-format t :nest 1)

;; Compound condition (AND)
(:title "Open + Priority - %n"
 :type search-simple
 :pattern "(and open priority)"
 :count-format t
 :nest 1)
```


#### `"search-lambda"` (Lambda Search)

Directly specify predicate function. Lambda function is evaluated on current line with no arguments, returns t to show, nil to hide.

| Property   | Required/Optional | Description     |
|------------|-------------------|-----------------|
| `:pattern` | Required          | Lambda function |

**Example**:

```elisp
;; Due today and has priority flag
(:title "Due Today + Priority - %n"
 :type search-lambda
 :pattern (lambda ()
            (and (altodo--due-date-matches-p 'today)
                 (altodo--line-has-flag-p)))
 :count-format t
 :nest 1)
```

**Lambda Function Requirements**:
- No arguments
- Evaluated on current line
- Return value: `t` (show) or `nil` (hide)


#### `"separator"` (Separator Line)

Visual separator

| Property   | Required/Optional | Description                    |
|------------|-------------------|--------------------------------|
| `:pattern` | Optional          | Character to display in separator |


#### `"command"` (Command Execution)

Execute specified command on click

| Property   | Required/Optional | Description        |
|------------|-------------------|--------------------|
| `:command` | Required          | Function to execute |


**Example**:

```elisp
;; Clear filter
(:title "[Clear Filter]" :type command :command altodo-filter-clear :nest 0)

;; Execute custom command
(:title "[Archive Done]" :type command :command altodo-archive-done-tasks :nest 0)
```

**What can be specified for `:command`**:
- Function name (symbol) that can be called interactively
- That function is executed in source buffer on click


### 13.5 DSL Pattern Specification

#### 13.5.1 Simple Patterns

Specify directly with string:

| Pattern                   | Description                |
|---------------------------|----------------------------|
| `"done"`                  | Done tasks                 |
| `"progress"`              | In-progress tasks          |
| `"waiting"`               | Waiting tasks              |
| `"open"`                  | Open tasks                 |
| `"cancelled"`             | Cancelled tasks            |
| `"priority"`              | With priority flag         |
| `"star"`                  | With star flag             |
| `"has-multiline-comment"` | With multiline comment     |


#### 13.5.2 Patterns with Arguments

Specify in `(type value)` format:

| Type                         | Format                                   | Description                          |
|------------------------------|------------------------------------------|--------------------------------------|
| `tag`                        | `(tag "TAGNAME")`                        | Tasks with specified tag             |
| `person`                     | `(person "NAME")`                        | Tasks with specified assignee        |
| `text`                       | `(text "STRING")`                        | Tasks containing text                |
| `regexp`                     | `(regexp "PATTERN")`                     | Match regex                          |
| `level`                      | `(level N)`                              | Nest level N                         |
| `heading`                    | `(heading "PATTERN")`                    | Exists within heading                |
| `due-date`                   | `(due-date CONDITION)`                   | Filter by due date                   |
| `start-date`                 | `(start-date CONDITION)`                 | Filter by start date                 |
| `tag-value`                  | `(tag-value "KEY VALUE")`                | Filter by tag value                  |
| `parent-task-regexp`         | `(parent-task-regexp "PATTERN")`         | Parent task matches pattern          |
| `root-task-regexp`           | `(root-task-regexp "PATTERN")`           | Root parent task matches pattern     |
| `multiline-comment-contains` | `(multiline-comment-contains "PATTERN")` | Multiline comment contains pattern   |


#### 13.5.3 Date Conditions (due-date / start-date)

| Condition               | Description | Example                                      |
|-------------------------|-------------|----------------------------------------------|
| `'overdue`              | Overdue     | `(due-date 'overdue)`                        |
| `'today`                | Due today   | `(due-date 'today)`                          |
| `'this-week`            | Due this week | `(due-date 'this-week)`                    |
| `'this-month`           | Due this month | `(due-date 'this-month)`                  |
| `after:DATE`            | After DATE  | `(due-date "after:2024-01-01")`              |
| `before:DATE`           | Before DATE | `(due-date "before:2024-12-31")`             |
| `between:START:END`     | Within range | `(due-date "between:2024-01-01:2024-12-31")` |


#### 13.5.4 Logical Operations

| Operation | Format                | Description      |
|-----------|-----------------------|------------------|
| `and`     | `(and PAT1 PAT2 ...)` | Match all        |
| `or`      | `(or PAT1 PAT2 ...)`  | Match any        |
| `not`     | `(not PAT)`           | Don't match      |


#### 13.5.5 Tag Value Conditions (tag-value)

| Format                                  | Description                     |
|-----------------------------------------|---------------------------------|
| `(tag-value "key" "value")`             | Exact match                     |
| `(tag-value "key" ("value1" "value2"))` | Multiple values (OR)            |
| `(tag-value "key" (> 5))`               | Numeric comparison (>, <, =, >=, <=) |


### 13.6 face-rules and count-face-rules Specification

`:face-rules` and `:count-face-rules` can specify face based on count.

- face-rules: Entire filter line text
- count-face-rules: Applied only to count part `%n` of filter line. If this item doesn't exist, `:face-rules` or `:face` items are applied to `%n`


```elisp
:face-rules ((>= 5 (:foreground "red" :weight bold))
             (>= 3 (:foreground "orange"))
             (>= 1 (:foreground "green"))
             (= 0 (:foreground "gray")))
```

**Format**: `(condition face-spec)`

**Conditions**:
- `>= N` - N or more
- `> N` - Greater than N
- `= N` - Equal to N
- `<= N` - N or less
- `< N` - Less than N

__face-spec__ can be specified as follows:

- Face name (`:foreground "red"`)
- Face name list (`error`, `warning`, `success`)
- plist (`(:foreground "red" :weight bold)`)

If no match in face-rules, fallback to face specified by `:face`. If `:face` is not specified either, use default face.


### 13.7 Configuration Example

```elisp
;; .altodo-locals.el
(
 (altodo-filter-patterns .
  (
   ;; Group header
   (:title "Status" :type group-header :nest 0)
   
   ;; Normal filters
   (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
   (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
   
   ;; Dynamic filters
   (:title "@Person - %n" :type dynamic :dynamic-type person :count-format t :nest 1)
   (:title "#Tag - %n" :type dynamic :dynamic-type tag :count-format t :nest 1)
   
   ;; With face-rules
   (:title "Priority - %n" :type search-simple :pattern "priority" :count-format t :nest 1
    :face-rules ((>= 5 error)
                 (>= 1 warning)))
   
   ;; Compound condition
   (:title "Open + Priority - %n"
    :type search-simple
    :pattern "(and open priority)"
    :count-format t :nest 1)
   
   ;; Separator
   (:title "" :type separator :nest 0)
   
   ;; Command
   (:title "[Clear]" :type command :command altodo-filter-clear :nest 0)
   ))
)
```


### 13.8 Default Configuration

```elisp
altodo--default-filter-patterns = '(
 (:title "Status" :type group-header :nest 0)
 (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
 (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1)
 (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1)
 (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
 (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1)
 (:title "Flags" :type group-header :nest 0)
 (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1)
 (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1)
 (:title "[Clear Filter]" :type command :command altodo-filter-clear :nest 0)
)
```

---

**Last Updated**: 2026-03-07
**Version**: 2.1.0
