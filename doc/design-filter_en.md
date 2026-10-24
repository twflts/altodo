# Filtering Feature Design Document

## 1. Overview

### Purpose

Implement filtering functionality in altodo-mode to filter tasks and comments based on conditions. Based on the filtering functionality, implement a sidebar (buffer) feature that makes it easy to select filters and displays status and filter counts.


### Feature List

- **Hide Filter**: Hide lines that don't match conditions
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


#### Selection state of the sidebar

```elisp
(defvar-local altodo-sidebar--selected-filters nil)
(defvar-local altodo-sidebar--selection-mode nil)
(defvar-local altodo-sidebar--current-combined-predicate nil)
```

**Description**: Buffer-local variables of the sidebar buffer. They hold the selection state
**Value**:
- `altodo-sidebar--selected-filters`: list of the selected filter entries
- `altodo-sidebar--selection-mode`: `single` (an entry was clicked; the list has one element), `multiple` (several entries were chosen with `s`), or `nil` (no selection)
- `altodo-sidebar--current-combined-predicate`: the combined predicate in `multiple` mode, used for the counts

**Update**: Only `altodo-sidebar--set-selection` changes the three variables. A click, a multiple selection, `altodo-filter-clear`, `altodo-filter-show-*` and `altodo-filter-by-pattern` all go through it, so the selection state does not disagree with the actual filter
**See also**: `altodo-sidebar--entry-state` returns the state of an entry (`selected`, `active` or `nil`). An entry of `single` mode is `active`, and an entry of `multiple` mode is `selected`


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
**Input**: `predicate` function. Optionally `show-multiline-comment` (`t`, `nil`, or the default `auto`; `:multiline-comment` of section 13.3) and `display-context` (section 13.3.1)
**Output**: None (the return value is not used). The overlays stay in `altodo--filter-overlays`


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

2. Build the title with `altodo--format-sidebar-title`. The number of `%n` has the face of the count part

3. Get the face of the whole row with `altodo-sidebar--get-face` and apply it to the characters of the title that have no face. A selected entry (`selected`, `active`) loses the faces of its title and has that face on the whole title

4. If clickable: make a button with `make-text-button`. If not clickable: no button, and the text is read-only. A separator has the face on the whole line

This is the only path that applies the face of the row.


#### altodo-sidebar--get-face

**Description**: Determine the face of the whole row of an entry (Layer structure)

**Processing Order**: Follows the Layer structure in section 11.1. The face of the count part (`%n`) is decided by `altodo--count-face` (section 11.2).

**Count**: The count that evaluates `:face-rules` is the same value as `%n` in the title (it is counted even without `%n`). In a multiple selection it is the count with the combined predicate.


#### altodo-sidebar--apply-filter

**Description**: Apply filter
**Process**:

1. Apply filter based on `:type`
   - `search-simple`: Compile DSL pattern to generate predicate
   - `search-lambda`: Use lambda function as predicate
   - `command`: Execute specified command
   - `heading-jump`: Jump to the heading
   - `nil`/`comment`/`group-header`/`separator`: No filter

2. `search-simple` and `search-lambda` set the selection state to `single` (the clicked entry only) and apply the predicate with `altodo--filter-lines`. `:display-context` and `:multiline-comment` apply to both types

3. The sidebar is drawn once. For `command`, a command that changes the filter clears the selection state itself


### 6.4 Dynamic Filter Expansion

#### altodo--expand-dynamic-filter

**Description**: Expand dynamic filter entry

**Process**:

1. Collect values from buffer with `altodo--collect-dynamic-values-with-exclude`
   - `person`: Collect `@person` tag values
   - `tag`: Collect `#tag` values
   - `due`: Collect the due dates (`-> DATE`)
   - `start`: Collect the start dates (`DATE ->`)
   - The task lines are collected (done and cancelled included); headings and `///` lines are not

2. Sort with `altodo--sort-dynamic-values`
   - `alpha`: ascending (chronological for dates)
   - `count`: most first (ascending among equal counts)

3. Limit with `altodo--limit-dynamic-values`
   - Limit to number specified by `:limit`
   - If `nil` or `0`, no limit

4. Generate `search-simple` entry from each value
   - Replace `%s` in `:title` with value (for `due` and `start`, the date in the format of `altodo-date-format`)
   - Auto-generate `:pattern` (e.g., `person:NAME`, `due-date:2026-03-05`)


#### altodo--expand-heading-filter

**Description**: Expand an entry with `:dynamic-type "heading"`

**Processing**:

1. `altodo--collect-headings` scans the buffer once and returns the text, level, position and number of unfinished tasks of each heading (ATX and Setext; lines in a code block are skipped)
2. The expansion narrows by `:level` and cuts from the top by `:limit`
3. It makes a `:type heading-jump` entry per heading. `:marker` is a marker at the start of the heading line. `:nest` is the `:nest` of the entry plus the steps of `:indent-by-level`

`altodo-sidebar--apply-filter` passes a `heading-jump` entry to `altodo-sidebar--jump-to-heading` outside `save-window-excursion`. That function does the following in order.

1. It checks that the marker's line is a heading. If not, it shows a message and stops
2. If a filter overlay hides the heading, it calls `altodo-filter-clear`
3. It selects the source window and puts the heading at the top with `recenter 0`

**Performance**: The scan including the count of unfinished tasks takes about 13 ms for a 10000-line buffer and about 60 ms for 50000 lines.


#### altodo--get-entry-count

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

**Reuse**: In one drawing, each entry is counted once (the title and the face of the row use the same value). Without `combined-predicate`, and with a string (DSL) pattern, the result is kept in `altodo--count-memo` while the text of the buffer, the narrowing and today's date are the same. A click, a selection or a change of AND/OR does not count the buffer again. An entry whose pattern is a function is counted every time, because the function may read anything


#### altodo--format-sidebar-title

**Description**: Format and return entry title

**Input**:
- `pattern-spec`: Filter entry plist
- `source-buffer`: Source buffer
- `combined-predicate`: Combined filter predicate (optional)
- `combine-mode`: Combination mode (`'and` or `'or`)

**Process**:

1. Detect `%n` in `:title`. `%n` is not replaced when `:count-format` is `nil` (it is `t` when omitted)

2. If `%n` exists, calculate count
   - Get match count with `altodo--get-entry-count`

3. Decide the face of the count part with `altodo--count-face`
   - The face of the first matching rule of `:count-face-rules`
   - Otherwise `:face-count`
   - If neither exists, the count gets no face of its own (the face of the whole row applies)

4. Replace `%n` with count number
   - Apply face property to count string

**Return Value**: Formatted title string


### 6.5 Compound Condition Filter

#### Processing for Multiple Selection

1. User selects multiple entries
2. Determine combination mode with `altodo-sidebar--combine-mode`
   - `'and`: Match all predicates
   - `'or`: Match any predicate

3. Combine predicates with `altodo--combine-predicates`
   - Collect predicates from all selected entries
   - Combine based on combination mode

4. Apply combined predicate to `altodo--filter-lines`


### 6.6 User Commands

| Command                              | Description                            |
| ------------------------------------ | -------------------------------------- |
| `altodo-filter-clear`                | Clear all filters                      |
| `altodo-filter-by-pattern`           | Show only lines matching a DSL pattern |
| `altodo-filter-show-done-only`       | Show only done tasks                   |
| `altodo-filter-show-progress-only`   | Show only progress tasks               |
| `altodo-filter-show-waiting-only`    | Show only waiting tasks                |
| `altodo-filter-show-open-only`       | Show only open tasks                   |
| `altodo-filter-show-cancelled-only`  | Show only cancelled tasks              |
| `altodo-filter-show-tag`             | Show tasks with specified tag          |
| `altodo-filter-show-priority`        | Show tasks with priority flag          |
| `altodo-filter-show-star`            | Show tasks with star flag              |
| `altodo-filter-show-overdue`         | Show overdue tasks                     |
| `altodo-filter-show-person`          | Show tasks for specified person        |
| `altodo-sidebar-set-and-mode`        | Switch to AND mode                     |
| `altodo-sidebar-set-or-mode`         | Switch to OR mode                      |
| `altodo-sidebar-toggle-combine-mode` | Toggle AND/OR                          |

`altodo-filter-clear`, `altodo-filter-by-pattern` and `altodo-filter-show-*` clear the selection state of the sidebar and draw the sidebar again. `c` in the sidebar clears the filter of the buffer that the sidebar belongs to.


## 7. Sidebar Integration

### Filter Entry Structure

A filter entry is a plist. The properties are described in section 13.3, and the types (`:type`) in section 13.4.


### Dynamic Filter

**`:type dynamic`** entries auto-collect values on display:

- `@person` - List of assignees
- `#tag` - List of tags
- Due dates (`-> DATE`) - List of due dates
- Start dates (`DATE ->`) - List of start dates
- Headings - List of headings (selecting one moves to the heading line; the filter is not changed)


### Compound Condition Filter

Sidebar entries can be selected multiple times (`s` key, or Ctrl + left mouse button):

- Switch AND/OR with `altodo-sidebar--combine-mode`
- Combine predicates with `altodo--combine-predicates`
- Only entries of type `search-simple` and `search-lambda` can be selected. The other types, such as a heading (`heading-jump`) and `command`, cannot be selected, and a message is shown
- Counts (when `altodo-sidebar-dynamic-count-enabled` is `t`): with AND, the number of lines that match both the entry and the combined predicate. With OR, the count of the entry alone stays. The list of a dynamic filter is collected from the lines that match the combined predicate, with both AND and OR


### Sidebar Update

The sidebar is drawn again in these cases.

- When the file is saved (only while the sidebar is shown)
- `r` and `C-c C-v s r`
- When a filter is applied, a selection is made, AND/OR is switched, or the month of the calendar is moved

Editing the buffer alone does not change the counts. Save the file or update with `r`.


### Entries That Cannot Be Drawn

When the value of an entry is invalid and the entry cannot be drawn (a lambda that counts signals an error, `:nest` is not an integer, `:exclude-tag` is not a list, `:days` is not a number, and so on), only that entry is left out, and the message `altodo: ignored the sidebar entry ...` is shown once for each entry. The other entries are drawn.


## 8. Key Bindings

### Filter Operations

| Key           | Function        |
| ------------- | --------------- |
| `C-c C-v f c` | Clear filter    |
| `C-c C-v s t` | Toggle sidebar  |
| `C-c C-v s r` | Refresh sidebar |


### Sidebar Operations

| Key           | Function                                         |
| ------------- | ------------------------------------------------ |
| `RET`, `SPC`  | Apply filter                                     |
| `s`           | Select/deselect filter                           |
| `C-<mouse-1>` | Select/deselect filter                           |
| `c`           | Clear filter                                     |
| `r`           | Refresh sidebar                                  |
| `q`           | Close sidebar                                    |
| `?`, `h`      | Show the key bindings (`altodo-sidebar-help`)    |
| `}`, `{`, `.` | Calendar: next month, previous month, this month |
| `n`, `p`      | Move to next/previous line                       |
| `C-c C-a`     | Switch to AND mode                               |
| `C-c C-o`     | Switch to OR mode                                |
| `C-c C-t`     | Toggle AND/OR                                    |


## 9. Mode Line Display

### Filter Status Display

```
[AND] (Single)
```

- `[AND]` and `[OR]`: combination mode. Click to toggle. A multiple selection is kept and filtered again with the new mode (the same as `C-c C-t`)
- `(Single)` and `(Multiple)`: selection mode


## 10. Performance

### Optimization

1. **heading-range cache**: Cache the heading ranges
2. **Relative line movement**: Process line numbers in ascending order and move from the previous position, instead of counting lines from the beginning of the buffer (`altodo--goto-line`)
3. **Narrowed overlay search**: Examine only the overlays in the range of the target line (`overlays-in`)
4. **Reuse of counts**: While the buffer does not change, the count of each entry is reused (`altodo--get-entry-count`, section 6.4). A click takes about 1.4 s before and about 0.2 s after (second click on; the first takes about 0.75 s) for 5000 lines, the default patterns and 20 entries
5. **Batch processing of heading ranges and line numbers**: Find the heading ranges in one scan and convert them to line numbers. Do not check every heading for every matched line, and update the overlay list once at the end


### Measurement

`scripts/bench-filter.sh` measures the processing time for each number of lines, pattern, and display context.

- Guideline: within 1 second for a 5000-line buffer, and within 100ms for a dynamic filter update. Both are design-time guidelines, not upper limits. The shorter the processing time, the better
- The calculation of heading ranges (`altodo--compute-all-heading-ranges`) scans the buffer once (proportional to the number of lines).
- The calculation of display lines (`altodo--compute-display-lines`) converts the heading ranges to line numbers and walks the matched lines in ascending order to find the headings that contain each line. It does not check every heading for every matched line. The overlays are removed from the list `altodo--filter-overlays` once at the end of `altodo--filter-lines`
- Measured (`tag:work`, with display context): 10,000 lines take 0.36 s, and 20,000 lines take 0.85 s. Doubling the number of lines multiplies the time by about 2.4


## 11. Face Application Priority (Layer Structure)

The face of the whole row and the face of the count part (the digits of `%n`) are decided on separate axes.


### 11.1 Face of the whole row

`altodo-sidebar--get-face` checks the following in order and uses the first that applies.

1. Selected: an entry chosen with `s` in a multiple selection. `altodo-sidebar-selected-filter-face`
2. Active: the entry that was clicked. `altodo-sidebar-active-filter-face`
3. `:face-rules`: when `:count-format` is not `nil`, the face of the first rule that matches the count
4. `:face`
5. The default face of the type

A Selected or Active entry loses the faces of its title, and the whole title (the count included) gets that face. Any other entry gets the face of the row on the characters of the title that have no face.

The default faces of the types follow. Entries that are not clickable (`comment`, `group-header`, `separator`) are decided here too.

- `nil` and `comment`: `altodo-sidebar-comment-face`
- `group-header`: `altodo-sidebar-group-header-face`
- `search-simple` and `heading-jump`: `altodo-sidebar-search-simple-face`
- `search-lambda`: `altodo-sidebar-search-lambda-face`
- `command`: `altodo-sidebar-command-face`
- `separator`: `altodo-sidebar-separator-face`
- Otherwise: `default`


### 11.2 Face of the count part

The face of the digits of `%n` is decided in this order. It does not apply to a Selected or Active entry.

1. `:count-face-rules`: the face of the first rule that matches the count
2. `:face-count`
3. The face of the whole row (section 11.1)

`:count-face-rules` and `:face-count` apply to the digits only, never to the whole row.


### 11.3 Value of the count

The count that the conditions of `:face-rules` and `:count-face-rules` use is the same value as `%n` in the title. It is counted even when the title has no `%n`. In a multiple selection it is the value with the combined predicate (AND: both the entry and the combined predicate; OR: the entry only).


### 11.4 Forms of a face

The values of `:face`, `:face-count`, `:face-rules` and `:count-face-rules` are interpreted by one function (`altodo-sidebar--resolve-face`). Section 13.6 shows the accepted forms. A value that cannot be interpreted is treated as not given.


## 12. References

- `doc/design.md` - Overall design document
- `doc/altodo_spec.md` - Format specification


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

| Property                | Required | Description                                             |
| ----------------------- | -------- | ------------------------------------------------------- |
| `:title`                | Required | Title to display in sidebar. `%n` displays match count  |
| `:type`                 | Required | Entry type (described later)                            |
| `:nest`                 | Optional | Indent level (default: 0)                               |
| `:count-format`         | Optional | `nil` to leave `%n` as it is (default: `t`)             |
| `:face`                 | Optional | Face for the whole row (forms in 13.6)                  |
| `:face-count`           | Optional | Face to apply to count part `%n`                        |
| `:face-rules`           | Optional | Face of the whole row by count (see 13.6)               |
| `:count-face-rules`     | Optional | Face of the count part by count (see 13.6)              |
| `:display-context`      | Optional | Display context (see 13.3.1)                            |
| `:multiline-comment`    | Optional | `t` shows, `nil` hides (omitted: shown only with `all`) |
| `:count-exclude-others` | Optional | Count target (see 13.3.2, default: `t`)                 |


#### 13.3.1 `:display-context` - Display Context

Controls which lines are displayed in addition to the matched lines when a filter is applied. The default is `heading-only`.

| Value          | Description                                                                 |
| -------------- | --------------------------------------------------------------------------- |
| `heading-only` | Matched lines and their headings (default)                                  |
| `all`          | Matched lines, their headings, and the multi-line comments of matched lines |
| `none`         | Matched lines only                                                          |

- Headings are ATX headings and Setext headings (the title and the underline)
- The multi-line comments of matched lines: when `:multiline-comment` is omitted, only `all` displays them; `heading-only` and `none` do not. `:multiline-comment t` displays them with any value, and `nil` hides them even with `all`
- The value is a symbol written without a quote. A `'all` inside `.altodo-locals.el` or `altodo-default-filter-patterns` becomes the list `(quote all)`, which is an unknown value. An unknown value shows a message once and works as `heading-only`

**Examples**:

```elisp
;; Show matched lines and headings (default)
(:title "Open - %n" :type search-simple :pattern "open" :display-context heading-only)

;; Show matched lines, headings, and multi-line comments
(:title "Open (all) - %n" :type search-simple :pattern "open" :display-context all)

;; Show matched lines only
(:title "Open (lines only) - %n" :type search-simple :pattern "open" :display-context none)
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

With the pattern `any-line`:

- With `:count-exclude-others t`: Match count is **2** (task lines only)
- With `:count-exclude-others nil`: Match count is **4** (task lines + comment lines)

With a pattern that does not match comment lines, such as `open`, both are **2**. `nil` matters only for a pattern that also matches comment lines, such as `any-line`, `comment` and `text:STRING`.

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

| Property | Required/Optional | Description   |
| -------- | ----------------- | ------------- |
| `:face`  | Optional          | Face to apply |


#### `group-header` (Group Header)

Not clickable, visual separator. It doesn't function as filter.

| Property | Required/Optional | Description   |
| -------- | ----------------- | ------------- |
| `:face`  | Optional          | Face to apply |


#### `dynamic` (Dynamic Filter)

Auto-collect values on display

| Property             | Required/Optional | Description                                                                |
| -------------------- | ----------------- | -------------------------------------------------------------------------- |
| `:dynamic-type`      | Required          | Target (`"person"`, `"tag"`, `"due"`, `"start"`, `"heading"`; symbols too) |
| `:tag-mode`          | Optional          | Tag extraction mode (`"all"`, `"name-only"`, `"with-value"`)               |
| `:exclude-person`    | Optional          | List of persons to exclude                                                 |
| `:exclude-tag`       | Optional          | List of tag names to exclude                                               |
| `:exclude-tag-value` | Optional          | List of `name:value` to exclude                                            |
| `:sort-by`           | Optional          | Sort order (`"alpha"`: ascending (default), `"count"`: most first)         |
| `:limit`             | Optional          | Display limit (default: nil; nil or 0 is unlimited)                        |

An exclusion matches the whole name (not a part of it). The case is ignored, and a leading `#` or `@` may or may not be written. `("id")` leaves out `#id` and keeps `#idea`. A value that is not a list makes the entry one that cannot be drawn (section 4.4 of `doc/design.md`).

Persons and tags are merged ignoring the case, in the spelling of the first use (`@bob` and `@Bob`). The `"alpha"` order also ignores the case.

`:sort-by` applies to every `:dynamic-type`. `"alpha"` of `due` and `start` is the chronological order. For `due` and `start`, `%s` of the list is shown in the format of `altodo-date-format`, and the pattern is `due-date:DATE` or `start-date:DATE`. A date that does not exist (such as `2026-02-30`) is not listed.

**`:tag-mode` Description**:

| Mode           | Description                                           | Example                                                  |
| -------------- | ----------------------------------------------------- | -------------------------------------------------------- |
| `"all"`        | Extract both tags without values and tags with values | `#java`, `#priority:high` → `["java", "priority:high"]` |
| `"name-only"`  | Extract tag names only (default)                      | `#java`, `#priority:high` → `["java", "priority"]`      |
| `"with-value"` | Extract only tags with values                         | `#priority:high` → `["priority:high"]`                  |

**Note**: `:tag-ignore-value` is deprecated. Use `:tag-mode` instead.

The properties other than those in the table above and `:level` and `:indent-by-level` below (`:face`, `:face-count`, `:face-rules`, `:count-face-rules`, `:count-exclude-others`, `:display-context`, `:multiline-comment` and so on) are passed on to the expanded entries. An expanded entry works like an entry that is not dynamic.

`:dynamic-type "heading"` does not collect values to filter by. It expands to entries that jump to a heading (`:type heading-jump`). The properties for it are below. `:sort-by`, `:exclude-*` and `:tag-mode` are ignored.

- `:level` (optional): levels to list. An integer or a list of integers. All levels if omitted
- `:limit` (optional): maximum number of headings from the top of the buffer. `0` or `nil` is unlimited
- `:indent-by-level` (optional): `t` (default; level 1 is not indented), an integer N (levels up to N are not indented), `nil` (none)

In `:title`, `%s` is the heading text, `%l` the level, and `%n` the number of unfinished tasks (neither done nor cancelled) from the heading to the next heading. The number is counted only when `:count-format` is not `nil` and `:title` contains `%n`, or `:face-rules` or `:count-face-rules` exists. `:face-rules` and `:count-face-rules` are evaluated with this number.


#### `search-simple` (Simple Search)

DSL pattern match. Describe filter condition with DSL pattern string. See "13.5 DSL Syntax" for details

| Property                | Required/Optional | Description                         |
| ----------------------- | ----------------- | ----------------------------------- |
| `:pattern`              | Required          | DSL pattern string                  |
| `:count-pattern-simple` | Optional          | DSL pattern used only to count `%n` |

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

| Property                | Required/Optional | Description                             |
| ----------------------- | ----------------- | --------------------------------------- |
| `:pattern`              | Required          | Lambda function                         |
| `:count-pattern-lambda` | Optional          | Lambda function used only to count `%n` |

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


#### `calendar` (Month Calendar)

Shows a month calendar in the sidebar. A separate library file, `altodo-calendar.el`, draws it with `altodo-calendar-insert`; altodo passes the faces and buttons of the days (`:day-function`). The face of a day cell changes with the number of tasks with due and start dates, and a day with tasks is a button that applies the filter of that day.

| Property           | Required/Optional | Description                                                                |
| ------------------ | ----------------- | -------------------------------------------------------------------------- |
| `:title`           | Optional          | Heading above the calendar. Not shown if empty                             |
| `:nest`            | Optional          | Indent level                                                               |
| `:calendar-target` | Optional          | Target: `due`, `start`, or `both` (default)                                |
| `:count-done`      | Optional          | `t` also counts done and cancelled tasks (they are not counted by default) |

- Kind of a day: only a day with tasks of the target kind is a button. If a day has both due and start dates, `altodo-calendar-priority` (`due` or `start`; default `due`) decides the face and the filter (`due-date:DATE` or `start-date:DATE`). If it has only one, that kind is used
- The buttons `<` and `>` on the first line move to the previous and next month, and the button with the month name returns to this month. With `altodo-calendar-show-nav` set to `nil`, `<` and `>` are not shown. In the sidebar, `}` (next month), `{` (previous month) and `.` (this month) also move the month
- The week starts on `altodo-week-start-day`. The names of the weekdays and months, the format of the title, and the holiday function are options of the `altodo-calendar` group (`altodo-calendar-day-names`, `-day-name-faces`, `-month-names`, `-title-format`, `-holiday-function`). All columns are as wide as the widest weekday name (at least 2 columns)
- The calendar needs 7 times the column width plus 6 separators (20 columns by default) and the indent. If the sidebar window is narrower, a note is shown instead
- A task with a date that does not exist (such as `2026-02-30`) is not counted
- Faces, from the highest precedence: the day being filtered (`altodo-calendar-selected-face`), overdue (`altodo-calendar-overdue-face`; bold and underlined, added to an unfinished due date in the past), `altodo-calendar-heavy-count` or more due dates (`altodo-calendar-due-heavy-face`), due (`altodo-calendar-due-face`), start (`altodo-calendar-start-face`), today (`altodo-calendar-today-face`), holiday (`altodo-calendar-holiday-face`), Sunday (`altodo-calendar-sunday-face`), Saturday (`altodo-calendar-saturday-face`), and a normal day (`altodo-calendar-day-face`). The title is `altodo-calendar-header-face`, `<` and `>` are `altodo-calendar-nav-face`, and the weekday names use `altodo-calendar-day-name-faces` (by default `altodo-calendar-weekday-face`, and the faces of Sunday and Saturday)

**Example**:

```elisp
(:title "" :type calendar :nest 1)
(:title "Due" :type calendar :calendar-target due :nest 1)
```


##### The Library altodo-calendar

`altodo-calendar.el` depends only on `calendar` and does not use any function of altodo. The main function is `(altodo-calendar-insert MONTH YEAR &rest OPTIONS)`, with the options `:indent`, `:week-start`, `:today`, `:day-function`, `:nav-function` and `:show-nav`. `:day-function` takes a date `(MONTH DAY YEAR)` and returns `nil` or `(:faces FACES :action FUNCTION :properties PLIST :help TEXT)`. A day with an `:action` is a button. Each day cell has the text property `altodo-calendar-date`.

The holiday function `altodo-calendar-japanese-holiday` follows the law on national holidays (in force since 1948). It handles the Mondays of Coming of Age Day, Marine Day, Respect for the Aged Day and Sports Day, the holidays of the accession in 2019, the moves for the Tokyo Olympics in 2020 and 2021, substitute holidays (since 2007 the next day that is not a holiday), and citizens' holidays (a day between two holidays). The equinox holidays are computed with an approximation formula for 1980 to 2099 only (the Cabinet Office explains that the National Astronomical Observatory announces the dates of the next year every February).


#### `agenda` (List by Day)

Shows the next days from today, one line per day, with the number of tasks with due (D) and start (S) dates. A line with tasks is a button that applies the filter of that day (only the kind of `altodo-calendar-priority` if the day has both).

| Property           | Required/Optional | Description                                                                                      |
| ------------------ | ----------------- | ------------------------------------------------------------------------------------------------ |
| `:title`           | Optional          | Heading above the list                                                                           |
| `:nest`            | Optional          | Indent level                                                                                     |
| `:days`            | Optional          | Number of days shown (default 7)                                                                 |
| `:calendar-target` | Optional          | `due`, `start`, or `both` (default)                                                              |
| `:count-done`      | Optional          | `t` also counts done and cancelled tasks                                                         |
| `:agenda-overdue`  | Optional          | `nil` hides the overdue line (by default it is shown if there are overdue tasks)                 |
| `:date-format`     | Optional          | Format of the date: `altodo` (default), `done-tag`, or a format string                           |
| `:show-weekday`    | Optional          | `nil` hides the weekday after the date (default `t`; see below for the names)                    |
| `:today-label`     | Optional          | Label of the line of today (default `"Today"`)                                                   |
| `:tomorrow-label`  | Optional          | Label of the line of tomorrow (default `"Tomorrow"`)                                             |
| `:overdue-label`   | Optional          | Label of the overdue line (default `"Overdue"`)                                                  |
| `:label-newline`   | Optional          | `t` puts a label on a line of its own, with the date and counts on the next line (default `nil`) |

```
Overdue  1
Today    2026-03-10 Tue D2
Tomorrow 2026-03-11 Wed
         2026-03-12 Thu D1 S1
```

With `:label-newline t` (and `:date-format "%m/%d"`):

```
Overdue
  1
Today
  03/10 Tue D2
Tomorrow
  03/11 Wed
  03/12 Thu D1 S1
```

- The first line, "Overdue", shows the number of unfinished tasks whose due date is before today, and applies the `due-date:overdue` filter (when the target includes the due date)
- Weekday names: when `altodo-calendar-day-names` equals its default, `calendar-day-abbrev-array` (the abbreviation of the language of Emacs, such as `Tue`). When it is changed from the default, those names are used so that the calendar and the agenda match. Setting the default value explicitly also gives the abbreviation
- The date format (`:date-format`): `altodo` follows `altodo-date-format` (`%Y-%m-%d` if it is `nil`), `done-tag` follows `altodo-done-tag-datetime-format` (`%Y-%m-%d`, the date only, if it is `nil`). A string is a format for `format-time-string`; write `%a` to get the weekday (then set `:show-weekday nil`). The weekday names are those of `calendar-day-abbrev-array`
- The label column is aligned to the widest label in use only when the labels share a line with the date. A day with an empty label has a blank column (with all labels empty there is no column). Everything is set with the properties of the entry (`altodo-filter-patterns`); there are no separate option variables
- Faces: `altodo-agenda-overdue-face` for the overdue line, `altodo-agenda-today-face` for today, `altodo-agenda-empty-face` for a day without tasks, and `altodo-agenda-date-face` for the others. The counts also get `altodo-agenda-count-face`

**Example**:

```elisp
(:title "Next 7 days" :type agenda :days 7 :nest 1)
(:title "Soon" :type agenda :days 5 :date-format "%m/%d" :today-label "Now"
 :tomorrow-label "Next" :overdue-label "Late" :label-newline t :nest 1)
```


#### `separator` (Separator Line)

Visual separator

| Property   | Required/Optional | Description                                       |
| ---------- | ----------------- | ------------------------------------------------- |
| `:pattern` | Optional          | Character to display in separator (default: `─`) |
| `:title`   | Optional          | Text shown in the center of the separator         |


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

A pattern with a syntax error or an unknown type matches no line. The sidebar shows a message and treats the pattern as one that matches no line. `altodo-filter-by-pattern` signals a `user-error` and changes nothing.

- Names of operations and patterns are lowercase only (`AND:open` and `Open` are errors)
- Spaces around an argument are removed for the arguments of a logical operation and for the patterns that take several values. For the arguments of the other patterns (`text:`, the value of `tag-value:` and so on), spaces are part of the content
- The patterns that take a regular expression (`regexp`, `heading`, `parent-task-regexp`, `root-task-regexp`, `multiline-comment-contains`) report an invalid regular expression as an error when the pattern is compiled
- Lines in a fenced code block (`` ``` `` and `~~~`) are not tasks, comments or headings. This is common to the state and flag patterns (`done`, `open`, `priority`, `star` and so on), `task`, `comment`, `heading` and the date conditions. Indented code blocks are not handled (indentation means nesting)


#### 13.5.2 Simple Patterns

| Pattern                   | Description                                                                     |
| ------------------------- | ------------------------------------------------------------------------------- |
| `"done"`                  | Completed tasks                                                                 |
| `"progress"`              | In-progress tasks                                                               |
| `"waiting"`               | Waiting tasks                                                                   |
| `"open"`                  | Open tasks                                                                      |
| `"cancelled"`             | Cancelled tasks                                                                 |
| `"priority"`              | With priority flag (any level)                                                  |
| `"star"`                  | With star flag                                                                  |
| `"has-multiline-comment"` | With multi-line comment                                                         |
| `"task"`                  | Task line                                                                       |
| `"comment"`               | Line that starts with `/// `                                                    |
| `"multiline-comment"`     | Line of a multi-line comment                                                    |
| `"heading"`               | Heading line (ATX heading, or the title of a Setext heading; not the underline) |
| `"empty-line"`            | Empty line (including a line with only spaces)                                  |
| `"any-line"`              | Every line                                                                      |


#### 13.5.3 Patterns with Arguments

| Type                         | Syntax                              | Description                                          |
| ---------------------------- | ----------------------------------- | ---------------------------------------------------- |
| `tag`                        | `tag:NAME`                          | Lines with the specified tag (see below)             |
| `person`                     | `person:NAME`                       | Lines with the specified person (see below)          |
| `text`                       | `text:STRING`                       | Lines containing the string                          |
| `regexp`                     | `regexp:REGEXP`                     | Lines matching the regular expression                |
| `level`                      | `level:N`                           | Lines at nest level N                                |
| `heading`                    | `heading:REGEXP`                    | Task lines within the range of a heading (see below) |
| `due-date`                   | `due-date:CONDITION`                | Filter by due date                                   |
| `start-date`                 | `start-date:CONDITION`              | Filter by start date                                 |
| `tag-value`                  | `tag-value:KEY VALUE`               | Filter by tag value                                  |
| `state-any`                  | `state-any:S1,S2,...`               | Line with any of the states                          |
| `has-any-flag`               | `has-any-flag:F1,F2,...`            | Line with any of the flags                           |
| `has-any-tag`                | `has-any-tag:T1,T2,...`             | Line with any of the tags                            |
| `has-all-tags`               | `has-all-tags:T1,T2,...`            | Line with all of the tags                            |
| `has-any-person`             | `has-any-person:P1,P2,...`          | Line with any of the persons                         |
| `parent-task-regexp`         | `parent-task-regexp:REGEXP`         | Parent task matches REGEXP (see below)               |
| `root-task-regexp`           | `root-task-regexp:REGEXP`           | Root parent task matches REGEXP (see below)          |
| `multiline-comment-contains` | `multiline-comment-contains:REGEXP` | Multi-line comment matches the regular expression    |

The arguments of a logical operation are split at commas. Therefore, an argument that contains a comma cannot be written inside a logical operation.

`tag`, `person`, `text`, `regexp`, `has-any-tag`, `has-all-tags` and `has-any-person` match only task lines and `///` lines. They do not match headings or normal text. They are not case-sensitive.

- Tag: the same definition as the highlighting and the lists of dynamic filters. `#` comes at the beginning of the line or after a space, and the name is letters, digits, `_` and `-`. `tag:java` matches `#java` and `#java:value`, and does not match `#java-x`, `x#java` or `(#java)`. `tag:priority:high` matches the tag with a value `#priority:high`
- Person: `@` comes at the beginning of the line or after a space, and the name goes up to the next space. `person:bob` matches `@bob` and `@Bob`, and does not match `@bob,` or `@bob.smith` (their names are `bob,` and `bob.smith`)
- Level: `N` of `level:N` is an integer of 0 or more. The level is the quotient of the number of indentation columns divided by 4 (rounded down). A value that is not an integer is an error
- Priority: `priority` matches `!`, `!!` and `!!!`. To select one level, use `regexp:` (e.g. `regexp:^\[.\] !! `)
- Comment: `comment` allows spaces and tabs as indentation. A line of `///` alone and `///x` are not comments
- State mark: the judgment of a task line also accepts `[]` (no mark) and `[ ]foo` (no space after `]`), and the state patterns such as `done` treat `[X]` like `[x]`. Write the marks as the specification defines them
- Parent task: the parent of `parent-task-regexp` is the direct task above with less indentation. The pattern matches the parent task and its children (including `///` lines and multi-line comments). The text matched is the whole line of the parent (state mark, flags and tags included). `root-task-regexp` matches the nearest task above without indentation in the same way. A heading cuts the relation to the tasks above it: an indented task under a heading has neither a parent nor a root


The multi-value patterns `state-any`, `has-any-flag`, `has-any-tag`, `has-all-tags` and `has-any-person` separate the values with commas or vertical bars (`|`). The arguments of a logic operation are split by commas, so use bars inside a logic operation. Example: `and:open,has-any-tag:a|b`. The values of `state-any` are `done`, `progress`, `waiting`, `open` and `cancelled`; those of `has-any-flag` are `star` and `priority`. An unknown value shows a message and gives a pattern that matches no line.


`REGEXP` of `heading:REGEXP` is a regular expression searched in the text of each heading (it is not anchored). Anchor it with `^` and `$` (`^Work$`) to leave out `Workshop`. Write `C\+\+` for a heading with a special character such as `C++`. Every heading with a match counts, and the range of a heading includes the lines under its child headings. Headings are ATX and Setext headings. The matching lines are the task lines, `///` lines and multi-line comment lines in the range. An invalid regular expression is an error when the pattern is compiled.


#### 13.5.4 Date Conditions (due-date / start-date)

The due date (`-> DATE`) and the start date (`DATE ->`) are recognized by the same rule in the coloring, the filters, the sidebar calendar and agenda, and the date input.

- Lines: task lines, `///` comment lines and headings. A date is not recognized in a multi-line comment, in plain text or in a fenced code block
- Spaces: a space is needed around the date and around the arrow (the beginning and the end of the line count as spaces). `a->2026-01-01` and `2026-01-01x ->` are not dates

`CONDITION` of `due-date:CONDITION` is as follows. The format of `DATE` follows `altodo-date-format`.

| Condition           | Description                        | Example                                  |
| ------------------- | ---------------------------------- | ---------------------------------------- |
| `overdue`           | Past the due date                  | `due-date:overdue`                       |
| `today`             | Due today                          | `due-date:today`                         |
| `tomorrow`          | Due tomorrow                       | `due-date:tomorrow`                      |
| `this-week`         | From today to the end of the week  | `due-date:this-week`                     |
| `this-month`        | From today to the end of the month | `due-date:this-month`                    |
| `before:DATE`       | Before DATE                        | `due-date:before:2024-12-31`             |
| `after:DATE`        | After DATE                         | `due-date:after:2024-01-01`              |
| `between:START:END` | Within the range                   | `due-date:between:2024-01-01:2024-12-31` |
| `within:N`          | Within N days from today           | `due-date:within:7`                      |
| `past:N`            | N or more days ago                 | `due-date:past:3`                        |
| `DATE`              | Matches the specified date         | `due-date:2024-06-30`                    |

For `start-date:CONDITION`, use `passed` (the start date is in the past) and `not-yet` (the start date is in the future) instead of `overdue`. The other conditions are the same.

A line with a date that does not exist (such as `2026-02-30`) matches no date condition. Writing a date that does not exist in a condition is an error. Relative conditions (`today`, `overdue`, etc.) use the real date whatever `altodo-date-format` is.


#### 13.5.5 Logical Operations

| Operation | Syntax          | Description                                     |
| --------- | --------------- | ----------------------------------------------- |
| `and`     | `and:P1,P2,...` | Matches all                                     |
| `or`      | `or:P1,P2,...`  | Matches any                                     |
| `not`     | `not:P`         | Does not match (only the first pattern is used) |

- `not` also applies to lines other than task lines (headings and normal text)
- Operators can be nested to any depth when there is one operator at each level. Example: `and:and:open,priority,star`
- When several operators are placed side by side, only the first level is split. Example: `or:and:open,priority,and:progress,star` means "open and with priority" or "in progress and with star". Placing operators side by side at the second level or deeper is not supported
- A pattern with no operands after the operator (`and:`) and a pattern with an empty operand (`and:open,,priority`, `and:open,priority,`) are errors. Spaces around an operand are removed


#### 13.5.6 Tag Value Conditions (tag-value)

| Syntax                  | Description                                    |
| ----------------------- | ---------------------------------------------- |
| `tag-value:KEY VALUE`   | Exact match                                    |
| `tag-value:KEY (V1 V2)` | Matches any of the values (OR)                 |
| `tag-value:KEY (OP N)`  | Numeric comparison (`>`, `<`, `=`, `>=`, `<=`) |

Write it like `tag-value:priority (> 5)`.

- Write `(OP N)` with `>`, `<`, `=`, `>=`, `<=` and a number only. Other forms that start with an operator (`(!= 5)`, `(> abc)`, `(> 5 6)`) are errors
- For a value with spaces, write the tag as `#owner:"john doe"` and match it with `tag-value:owner john doe` (the quotes are removed for the comparison)
- When a tag appears several times, the first one is used. The tag name is not case-sensitive, and the comparison of the value is. The definition of a tag is the same as for `tag`


### 13.6 face-rules and count-face-rules Specification

`:face-rules` and `:count-face-rules` can specify face based on count.

- `:face-rules`: The whole text of the filter row. It is not evaluated when `:count-format` is `nil`
- `:count-face-rules`: Only the count part `%n` of the filter row, never the whole row. If this item doesn't exist, `%n` gets `:face-count`, or the face of the whole row if that does not exist either

The count is the same value as `%n` in the title (section 11.3).


```elisp
:face-rules ((>= 5 (:foreground "red" :weight bold))
             (>= 3 (:foreground "orange"))
             (>= 1 (:foreground "green"))
             (= 0 (:foreground "gray")))
```

**Format**: `(condition N face-spec)`

**Conditions**:
- `>= N` - N or more
- `> N` - Greater than N
- `= N` - Equal to N
- `<= N` - N or less
- `/= N` - Not equal to N
- `< N` - Less than N

The rules are evaluated from the top, and the face of the first matching rule is used. If no rule matches, the whole row uses `:face`, or the default face of the type if `:face` does not exist. The count part uses `:face-count`, or the face of the whole row if that does not exist.

A rule with an invalid form (a condition other than the six above, an N that is not a number, or not three elements) is ignored alone, and the message `altodo: ignored the invalid face rule ...` is shown once for each rule. A list of rules that is not a list is ignored in the same way. The drawing of the sidebar does not fail.

__face-spec__ can be specified as follows. The values of `:face` and `:face-count` take the same forms.

- Face name (`error`)
- List of face names (`(bold error)`)
- plist (`(:foreground "red" :weight bold)`)
- defface style (`((t (:foreground "red")))`). The attributes of the `t` clause are used

A value that cannot be interpreted (such as a plist with an odd number of elements) is treated as not given.


### 13.7 Configuration Example

```elisp
;; .altodo-locals.el
(
 (altodo-filter-patterns .
  (
   ;; Status group
   (:title "Status" :type group-header :nest 0)
   (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1
           :count-exclude-others t :display-context all)
   (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1
           :count-exclude-others t :display-context all)
   (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1
           :count-exclude-others t :display-context all)
   (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1
           :count-exclude-others t :display-context all)
   (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1
           :count-exclude-others t :display-context all)
   
   ;; Flags group
   (:title "Flags" :type group-header :nest 0)
   (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1
           :count-exclude-others t :face-rules ((>= 5 error) (>= 1 warning)))
   (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1
           :count-exclude-others t)
   
   ;; Due date group
   (:title "Due" :type group-header :nest 0)
   (:title "Open and Over Due - %n" :type search-simple
           :pattern "and:due-date:overdue,not:state-any:done|cancelled"
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 1 error)))
   (:title "Open and Due Today - %n" :type search-simple
           :pattern "and:due-date:today,not:state-any:done|cancelled"
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 1 error)))
   
   ;; Tags group
   (:title "Tags" :type group-header :nest 0)
   (:title "#%s - %n" :type dynamic :dynamic-type "tag" :count-format t :limit 5 :nest 1
           :exclude-tag ("id" "dep" "done") :tag-mode "name-only"
           :count-exclude-others t :display-context all)
   
   ;; People group
   (:title "People" :type group-header :nest 0)
   (:title "@%s - %n" :type dynamic :dynamic-type "person" :count-format t :limit 5 :nest 1
           :count-exclude-others t :display-context all)

   ;; Headings group
   (:title "Headings" :type group-header :nest 0)
   (:title "%s - %n" :type dynamic :dynamic-type "heading" :count-format t :nest 1)
   
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
