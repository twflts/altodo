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

| Filter             | Description                                |
| ------------------ | ------------------------------------------ |
| State Filter       | done, progress, waiting, open, cancelled   |
| Tag Filter         | Filter by `#tag`                           |
| @person Filter     | Filter by `@person`                        |
| Priority Filter    | Filter by `!` flag                         |
| Due Date Filter    | Filter by overdue, within due date, etc.   |
| Dynamic Filter     | Auto-collect values from buffer and filter |
| Parent Task Filter | Filter by parent task conditions           |


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

| Method                       | Rejection Reason                                      |
| ---------------------------- | ----------------------------------------------------- |
| `keep-lines` / `flush-lines` | Destructive (deletes buffer contents)                 |
| `occur-mode`                 | Displays in separate buffer (doesn't change original) |
| text property                | Subject to undo/redo                                  |


### Performance Requirements

- The shorter the processing time, the better. No upper limit is set as a requirement
- The design-time guideline is within 1 second for a 5000-line buffer. Measure it with `scripts/bench-filter.sh`
- Filtering is excluded from undo/redo


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


### Errors in the predicate Function

If the predicate function signals an error on some line, all overlays created by that run are deleted (the filter is cleared), a message is shown, and the error is signaled again. Leaving only some lines hidden would look like a filter result.


### Helper Function Specification

**Naming Convention**: `altodo--line-*-p` - Determine if current line matches condition

**Return Value**: `t` (matches condition), `nil` (doesn't match condition)


### DSL Compiler Specification

`altodo--compile-filter-predicate`: Generate a predicate function from a filter entry (plist).

- When `:type` is `search-lambda`: return the function in `:pattern` as it is
- When `:type` is `search-simple`: compile the string in `:pattern` with `altodo--compile-simple-pattern`
- Otherwise: return a function that always returns `nil`

If compiling a string pattern fails (wrong syntax or unknown type), a message is displayed and a function that matches no line is returned. The pattern syntax is described in section 13.5.

**Example**: From the pattern string `"and:open,priority"`, a function is generated that returns `t` for lines that are open and have a priority flag.


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
├── Sidebar Functions (altodo-sidebar--*)
│   ├── altodo-sidebar--render       ; Sidebar rendering
│   ├── altodo-sidebar--insert-entry ; Entry insertion
│   ├── altodo-sidebar--get-face     ; Face retrieval
│   └── altodo-sidebar--apply-filter ; Filter application
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
altodo--filter-lines / altodo-sidebar--apply-filter
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

**Description**: Generate a predicate function from a filter entry
**Input**: Filter entry (plist)
**Output**: predicate function


#### altodo--combine-predicates

**Description**: Combine multiple predicates
**Input**: List of predicates, combination mode (`and`/`or`)
**Output**: Combined predicate function


### 6.3 Sidebar Rendering Process

#### altodo-sidebar--insert-entry

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


#### altodo-sidebar--get-face

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


#### altodo-sidebar--apply-filter

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

| Command                              | Description                     |
| ------------------------------------ | ------------------------------- |
| `altodo-filter-clear`                | Clear all filters               |
| `altodo-filter-show-done-only`       | Show only done tasks            |
| `altodo-filter-show-progress-only`   | Show only progress tasks        |
| `altodo-filter-show-waiting-only`    | Show only waiting tasks         |
| `altodo-filter-show-open-only`       | Show only open tasks            |
| `altodo-filter-show-cancelled-only`  | Show only cancelled tasks       |
| `altodo-filter-show-tag`             | Show tasks with specified tag   |
| `altodo-filter-show-priority`        | Show tasks with priority flag   |
| `altodo-filter-show-star`            | Show tasks with star flag       |
| `altodo-filter-show-overdue`         | Show overdue tasks              |
| `altodo-filter-show-person`          | Show tasks for specified person |
| `altodo-sidebar-set-and-mode`        | Switch to AND mode              |
| `altodo-sidebar-set-or-mode`         | Switch to OR mode               |
| `altodo-sidebar-toggle-combine-mode` | Toggle AND/OR                   |


## 7. Sidebar Integration

### Filter Entry Structure

A filter entry is a plist. The properties are described in section 13.3, and the types (`:type`) in section 13.4.


### Dynamic Filter

**`:type dynamic`** entries auto-collect values on display:

- `@person` - List of assignees
- `#tag` - List of tags
- `#due` - List of due dates
- `#start` - List of start dates


### Compound Condition Filter

Sidebar entries can be selected multiple times (`s` key, or Ctrl + left mouse button):

- Switch AND/OR with `altodo-sidebar--combine-mode`
- Combine predicates with `altodo--combine-predicates`


## 8. Key Bindings

### Filter Operations

| Key           | Function        |
| ------------- | --------------- |
| `C-c C-v f c` | Clear filter    |
| `C-c C-v s t` | Toggle sidebar  |
| `C-c C-v s r` | Refresh sidebar |


### Sidebar Operations

| Key           | Function                   |
| ------------- | -------------------------- |
| `RET`, `SPC`  | Apply filter               |
| `s`           | Select/deselect filter     |
| `C-<mouse-1>` | Select/deselect filter     |
| `c`           | Clear filter               |
| `r`           | Refresh sidebar            |
| `q`           | Close sidebar              |
| `n`, `p`      | Move to next/previous line |
| `C-c C-a`     | Switch to AND mode         |
| `C-c C-o`     | Switch to OR mode          |
| `C-c C-t`     | Toggle AND/OR              |


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

1. **heading-range cache**: Cache the heading ranges
2. **Relative line movement**: Process line numbers in ascending order and move from the previous position, instead of counting lines from the beginning of the buffer (`altodo--goto-line`)
3. **Narrowed overlay search**: Examine only the overlays in the range of the target line (`overlays-in`)
4. **Batch processing of heading ranges and line numbers**: Find the heading ranges in one scan and convert them to line numbers. Do not check every heading for every matched line, and update the overlay list once at the end


### Measurement

`scripts/bench-filter.sh` measures the processing time for each number of lines, pattern, and display context.

- Guideline: within 1 second for a 5000-line buffer, and within 100ms for a dynamic filter update. Both are design-time guidelines, not upper limits. The shorter the processing time, the better
- The calculation of heading ranges (`altodo--compute-all-heading-ranges`) scans the buffer once (proportional to the number of lines).
- The calculation of display lines (`altodo--compute-display-lines`) converts the heading ranges to line numbers and walks the matched lines in ascending order to find the headings that contain each line. It does not check every heading for every matched line. The overlays are removed from the list `altodo--filter-overlays` once at the end of `altodo--filter-lines`
- Measured (`tag:work`, with display context): 10,000 lines went from 2.99 s to 0.36 s, and 20,000 lines take 0.85 s. Doubling the number of lines multiplies the time by about 2.4


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

Non-clickable entries (`comment`, `group-header`)


## 12. References

- `doc/design.md` - Overall design document
- `doc/altodo_spec.md` - Format specification
- `project.altodo` - Implementation plan
- `.kiro/memo/` - Development notes


## 13. altodo-filter-patterns Specification

### 13.1 Overview

`altodo-filter-patterns` is a list defining filter patterns to display in sidebar.
Set in `.altodo-locals.el` file or `altodo-default-filter-patterns` variable.


### 13.2 Entry Structure

Each filter entry is defined as plist (property list):

```elisp
(:title "Display Name" :type TYPE :nest 0 ...)
```


### 13.3 Common Properties

| Property                | Required | Description                                                         |
| ----------------------- | -------- | ------------------------------------------------------------------- |
| `:title`                | Required | Title to display in sidebar. `%n` displays match count              |
| `:type`                 | Required | Entry type (described later)                                        |
| `:nest`                 | Optional | Indent level (default: 0)                                           |
| `:count-format`         | Optional | `t` to replace `%n` with count (default: `t`)                       |
| `:face`                 | Optional | Face to apply                                                       |
| `:face-count`           | Optional | Face to apply to count part `%n`                                    |
| `:display-context`      | Optional | Display context (see 13.3.1)                                        |
| `:multiline-comment`    | Optional | `nil` hides the multi-line comments of matched lines (default: `t`) |
| `:count-exclude-others` | Optional | Count target (see 13.3.2, default: `t`)                             |


#### 13.3.1 `:display-context` - Display Context

Controls which lines are displayed in addition to the matched lines when a filter is applied. The default is `'heading-only`.

| Value           | Description                                                                 |
| --------------- | --------------------------------------------------------------------------- |
| `'heading-only` | Matched lines and their headings (default)                                  |
| `'all`          | Matched lines, their headings, and the multi-line comments of matched lines |
| `'none`         | Matched lines only                                                          |

**Examples**:

```elisp
;; Show matched lines and headings (default)
(:title "Open - %n" :type search-simple :pattern "open" :display-context 'heading-only)

;; Show matched lines, headings, and multi-line comments
(:title "Open (all) - %n" :type search-simple :pattern "open" :display-context 'all)

;; Show matched lines only
(:title "Open (lines only) - %n" :type search-simple :pattern "open" :display-context 'none)
```


#### 13.3.2 `:count-exclude-others` - Count Target

Controls which types of lines to include when counting. When both task lines and comment lines exist, specify which should be counted.

| Value | Description                                             | Use Case                                                |
| ----- | ------------------------------------------------------- | ------------------------------------------------------- |
| `t`   | Count only task lines (exclude comment lines) (default) | Normal filtering. Multi-line comment lines are excluded |
| `nil` | Count all lines (both task lines and comment lines)     | When you want to include comment lines in the count     |

**Concrete Example**:

Given the following file:

```
[ ] Task 1
    /// Comment for Task 1
[ ] Task 2
    /// Comment for Task 2
```

- With `:count-exclude-others t`: Match count is **2** (task lines only)
- With `:count-exclude-others nil`: Match count is **4** (task lines + comment lines)

**Configuration Examples**:

```elisp
;; Count only task lines (default)
(:title "Open Tasks - %n" :type search-simple :pattern "open" :count-exclude-others t)

;; Count all lines
(:title "All Matches - %n" :type search-simple :pattern "open" :count-exclude-others nil)
```


### 13.4 Entry Types (`:type`)

#### `comment` or `nil` (Comment Line)

Not clickable, no filter applied. Used for visual separators or explanatory text.

| Property                | Required/Optional | Description                  |
| ----------------------- | ----------------- | ---------------------------- |
| `:face`                 | Optional          | Face to apply                |
| `:count-exclude-others` | Optional          | `t` to count only task lines |


#### `group-header` (Group Header)

Not clickable, visual separator

| Property | Required/Optional | Description                |
| -------- | ----------------- | -------------------------- |
| None     | -                 | Doesn't function as filter |


#### `dynamic` (Dynamic Filter)

Auto-collect values on display

| Property             | Required/Optional | Description                                                  |
| -------------------- | ----------------- | ------------------------------------------------------------ |
| `:dynamic-type`      | Required          | Collection target (`person`, `tag`, `due`, `start`)          |
| `:tag-mode`          | Optional          | Tag extraction mode (`"all"`, `"name-only"`, `"with-value"`) |
| `:exclude-person`    | Optional          | List of `@person` to exclude                                 |
| `:exclude-tag`       | Optional          | List of `#tag` to exclude                                    |
| `:exclude-tag-value` | Optional          | List of `#tag:value` to exclude                              |
| `:sort`              | Optional          | Sort method (`alpha`, `count`, `reverse-count`)              |
| `:limit`             | Optional          | Display limit (default: nil = unlimited)                     |

**`:tag-mode` Description**:

| Mode           | Description                                           | Example                                                  |
| -------------- | ----------------------------------------------------- | -------------------------------------------------------- |
| `"all"`        | Extract both tags without values and tags with values | `#java`, `#priority:high` → `["java", "priority:high"]` |
| `"name-only"`  | Extract tag names only (default)                      | `#java`, `#priority:high` → `["java", "priority"]`      |
| `"with-value"` | Extract only tags with values                         | `#priority:high` → `["priority:high"]`                  |

**Note**: `:tag-ignore-value` is deprecated. Use `:tag-mode` instead.


#### `search-simple` (Simple Search)

DSL pattern match. Describe filter condition with DSL pattern string. See "13.5 DSL Syntax" for details

| Property   | Required/Optional | Description        |
| ---------- | ----------------- | ------------------ |
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
 :pattern "and:open,priority"
 :count-format t
 :nest 1)
```


#### `search-lambda` (Lambda Search)

Directly specify predicate function. Lambda function is evaluated on current line with no arguments, returns t to show, nil to hide.

| Property   | Required/Optional | Description     |
| ---------- | ----------------- | --------------- |
| `:pattern` | Required          | Lambda function |

A lambda written in `.altodo-locals.el` does not run by default (`altodo-locals-code-policy`; see 4.5 of `doc/design.md`). A lambda written in `altodo-default-filter-patterns` always runs.

**Example**:

```elisp
;; Due today and has priority flag
(:title "Due Today + Priority - %n"
 :type search-lambda
 :pattern (lambda ()
            (and (altodo--due-date-matches-p 'today)
                 (altodo--line-has-priority-p)))
 :count-format t
 :nest 1)
```

**Lambda Function Requirements**:
- No arguments
- Evaluated on current line
- Return value: `t` (show) or `nil` (hide)


#### `separator` (Separator Line)

Visual separator

| Property   | Required/Optional | Description                       |
| ---------- | ----------------- | --------------------------------- |
| `:pattern` | Optional          | Character to display in separator |


#### `command` (Command Execution)

Execute specified command on click

| Property   | Required/Optional | Description         |
| ---------- | ----------------- | ------------------- |
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

#### 13.5.1 Pattern Syntax

A pattern is a string. There are three kinds.

- Simple pattern: a name only. Example: `"done"`
- Pattern with an argument: `type:argument`. Example: `"tag:java"`
- Logical operation pattern: `operation:pattern,pattern,...`. Example: `"and:open,priority"`

A pattern with a syntax error or an unknown type matches no line.


#### 13.5.2 Simple Patterns

| Pattern                   | Description             |
| ------------------------- | ----------------------- |
| `"done"`                  | Completed tasks         |
| `"progress"`              | In-progress tasks       |
| `"waiting"`               | Waiting tasks           |
| `"open"`                  | Open tasks              |
| `"cancelled"`             | Cancelled tasks         |
| `"priority"`              | With priority flag      |
| `"star"`                  | With star flag          |
| `"has-multiline-comment"` | With multi-line comment |


#### 13.5.3 Patterns with Arguments

| Type                         | Syntax                              | Description                                       |
| ---------------------------- | ----------------------------------- | ------------------------------------------------- |
| `tag`                        | `tag:NAME`                          | Lines with the specified tag                      |
| `person`                     | `person:NAME`                       | Lines with the specified person                   |
| `text`                       | `text:STRING`                       | Lines containing the string                       |
| `regexp`                     | `regexp:REGEXP`                     | Lines matching the regular expression             |
| `level`                      | `level:N`                           | Lines at nest level N                             |
| `heading`                    | `heading:REGEXP`                    | Task lines within the range of a heading          |
| `due-date`                   | `due-date:CONDITION`                | Filter by due date                                |
| `start-date`                 | `start-date:CONDITION`              | Filter by start date                              |
| `tag-value`                  | `tag-value:KEY VALUE`               | Filter by tag value                               |
| `parent-task-regexp`         | `parent-task-regexp:REGEXP`         | Parent task matches the regular expression        |
| `root-task-regexp`           | `root-task-regexp:REGEXP`           | Root parent task matches the regular expression   |
| `multiline-comment-contains` | `multiline-comment-contains:REGEXP` | Multi-line comment matches the regular expression |

The arguments of a logical operation are split at commas. Therefore, an argument that contains a comma cannot be written inside a logical operation.


#### 13.5.4 Date Conditions (due-date / start-date)

`CONDITION` of `due-date:CONDITION` is as follows. The format of `DATE` follows `altodo-date-format`.

| Condition           | Description                | Example                                  |
| ------------------- | -------------------------- | ---------------------------------------- |
| `overdue`           | Past the due date          | `due-date:overdue`                       |
| `today`             | Due today                  | `due-date:today`                         |
| `tomorrow`          | Due tomorrow               | `due-date:tomorrow`                      |
| `this-week`         | Due this week              | `due-date:this-week`                     |
| `this-month`        | Due this month             | `due-date:this-month`                    |
| `before:DATE`       | Before DATE                | `due-date:before:2024-12-31`             |
| `after:DATE`        | After DATE                 | `due-date:after:2024-01-01`              |
| `between:START:END` | Within the range           | `due-date:between:2024-01-01:2024-12-31` |
| `within:N`          | Within N days from today   | `due-date:within:7`                      |
| `past:N`            | N or more days ago         | `due-date:past:3`                        |
| `DATE`              | Matches the specified date | `due-date:2024-06-30`                    |

For `start-date:CONDITION`, use `passed` (the start date is in the past) and `not-yet` (the start date is in the future) instead of `overdue`. The other conditions are the same.

A line with a date that does not exist (such as `2026-02-30`) matches no date condition. Writing a date that does not exist in a condition is an error. Relative conditions (`today`, `overdue`, etc.) use the real date whatever `altodo-date-format` is.


#### 13.5.5 Logical Operations

| Operation | Syntax          | Description                                     |
| --------- | --------------- | ----------------------------------------------- |
| `and`     | `and:P1,P2,...` | Matches all                                     |
| `or`      | `or:P1,P2,...`  | Matches any                                     |
| `not`     | `not:P`         | Does not match (only the first pattern is used) |

- `not` also applies to lines other than task lines (headings and normal text)
- Nesting is limited to one level. A split is possible only when there are multiple operators at the same level. Example: `or:and:open,priority,and:progress,star` means "open and with priority" or "in progress and with star". Nesting of two or more levels is not supported


#### 13.5.6 Tag Value Conditions (tag-value)

| Syntax                  | Description                                    |
| ----------------------- | ---------------------------------------------- |
| `tag-value:KEY VALUE`   | Exact match                                    |
| `tag-value:KEY (V1 V2)` | Matches any of the values (OR)                 |
| `tag-value:KEY (OP N)`  | Numeric comparison (`>`, `<`, `=`, `>=`, `<=`) |

Example: `tag-value:priority (> 5)`


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
   ;; Status group
   (:title "Status" :type group-header :nest 0)
   (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   
   ;; Flags group
   (:title "Flags" :type group-header :nest 0)
   (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1
           :count-exclude-others t :face-rules ((>= 5 error) (>= 1 warning)))
   (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1
           :count-exclude-others t)
   
   ;; Due date group
   (:title "Due" :type group-header :nest 0)
   (:title "Overdue - %n"
           :type search-lambda
           :pattern (lambda ()
                      (and (altodo--due-date-matches-p 'overdue)
                           (not (or (altodo--line-state-p altodo-state-done)
                                    (altodo--line-state-p altodo-state-cancelled)))))
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 1 error)))
   (:title "Due Today - %n"
           :type search-lambda
           :pattern (lambda ()
                      (and (altodo--due-date-matches-p 'today)
                           (not (or (altodo--line-state-p altodo-state-done)
                                    (altodo--line-state-p altodo-state-cancelled)))))
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 1 error)))
   
   ;; Tags group
   (:title "Tags" :type group-header :nest 0)
   (:title "#%s - %n" :type dynamic :dynamic-type "tag" :count-format t :limit 5 :nest 1
           :exclude-tag ("id" "dep" "done") :tag-mode "name-only"
           :count-exclude-others t :display-context 'all)
   
   ;; People group
   (:title "People" :type group-header :nest 0)
   (:title "@%s - %n" :type dynamic :dynamic-type "person" :count-format t :limit 5 :nest 1
           :count-exclude-others t :display-context 'all)
   
   ;; Compound condition example
   (:title "Open + Priority - %n"
           :type search-simple
           :pattern "and:open,priority"
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 3 warning)))
   
   ;; Separator
   (:title "" :type separator :pattern "─" :nest 0)
   
   ;; Command
   (:title "[Clear Filter]" :type command :command altodo-filter-clear :nest 0)
   ))
)
```
