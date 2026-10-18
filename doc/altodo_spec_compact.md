# altodo Format Specification (Compact)

altodo: TODO format embeddable in Markdown/CommonMark. Extension: `.altodo`. MIT licensed (altodo format extensions only; Markdown/CommonMark parts follow their respective specifications).


## Line Grammar

```
TASK_LINE    := INDENT STATE SP {FLAG SP} BODY
COMMENT_LINE := INDENT "///" SP {FLAG SP} BODY   ; detached note (NOT part of the task); single line only
MULTILINE    := INDENT BODY            ; INDENT = indent of the task/"///" line above + 4 spaces
MARKDOWN     := any line not matching above patterns

STATE := "[ ]" | "[@]" | "[w]" | "[x]" | "[~]"
FLAG  := "+" | "!" | "!!" | "!!!"   ; at most one star and one priority, in any order
SP    := " " (exactly one space)
INDENT := 0 or more spaces (multiples of 4 for nesting)
BODY  := text with optional inline elements (tags, dates, @person/place)
```


## States

`[ ]` open, `[@]` in-progress, `[w]` waiting, `[x]` done, `[~]` cancelled


## Flags

`+` star (important). `!`/`!!`/`!!!` priority 1-3 (4+ truncated to 3). A star and a priority can be used together in either order (`+ !! text`, `!! + text`); each kind at most once. Placed immediately after the state mark + space (task lines) or after `///` + space (comment lines).


## Nesting

Child indent = parent indent + 4 spaces. Unlimited depth. Applies to tasks, single-line comments, and multi-line comments.


## Multi-line Comments

The first line of a multi-line comment is indented by exactly the indent of the line above it (a task line or a `///` comment) + 4 spaces, and it attaches to that line. Both a task line and a `///` comment can carry a multi-line comment. Every line at that indent that is not a task line is comment text, including Markdown lists, `[text](url)` links, and fenced code blocks. Following lines keep the same indent as the previous multi-line comment line. A line keeping that indent (including a blank line with trailing spaces) is comment text; a fully blank line (zero chars) ends the comment, and so does any line with a different indent. There is no exception: a more deeply indented line, such as a nested Markdown list item, is not part of the comment. A line starting with a STATE mark is always a task, never comment text; to include such text verbatim, wrap it in a fenced code block.

```
[ ] parent
    comment for parent  <- parent indent 0 + 4: attaches to [ ] parent
    [ ] child
        comment for child  <- child indent 4 + 4: attaches to [ ] child
    /// note
        text for note  <- note indent 4 + 4: attaches to the /// note above
```

NOT multi-line comments (plain Markdown text):

```
[ ] parent
    [ ] child
    same indent as child  <- not child indent + 4
            too deep  <- not child indent + 4 (+8)
```


## Comment Types: when to use which

Both forms sit under a task; choose by whether the text is PART OF the task.

- Multi-line comment (no marker): the task's own description or rationale — part of the task definition. Use it for any explanation of the task, even one line.
- `///` comment: a detached note (side remark, review memo) that is NOT part of the task. The `///` marker itself takes one line, though it may be followed by a no-marker multi-line comment (which stays a detached note too). It may be indented under a task for grouping but never joins the task's definition.

Do NOT stack `///` lines to write a task's description; use the no-marker form instead.


## Inline Elements (in BODY of task lines, comment lines, and Markdown headings)

### Tags

`#name` or `#name:value` or `#name:"value with spaces"`. Name regex: `[a-zA-Z0-9_-]+`. Space required before `#` (or line start) and after the tag (not required at end of line). Multiple per line.


### Dates

`YYYY-MM-DD ->` (start), `-> YYYY-MM-DD` (due), `YYYY-MM-DD -> YYYY-MM-DD` (both). Space required around dates and `->`.


### Person/Place

`@name` where name is any non-space chars. Space required before `@` (or line start) and after the name (not required at end of line). Multiple per line.


### Literal text / escaping

Writing `#`, `@`, or `->` literally is NOT supported yet (`\` escaping is planned). For now rely on the space-before rule (`foo@bar` is not a mention) or a fenced code block.


## Special Tags

- `#id:VALUE` — unique task identifier
- `#dep:VALUE` — dependency on `#id:VALUE` (blocked until target done; orphaned deps ignored)
- `#done:TIMESTAMP` — completion time (ISO 8601 / unix time; removed on reopen)
- `#group-start:DATE`, `#group-due:DATE` — put on a parent task: start/due date of the whole group (the task and its subtasks), specified once on the parent instead of on each subtask
- `#seq-tasks` — children execute sequentially top-to-bottom (each child blocked by previous sibling)


## Markdown Integration

Non-task/comment lines are pure Markdown. Fenced code blocks and inline code disable altodo syntax. Indented task lines, `///` comment lines, and multi-line comments are never treated as Markdown indented code blocks (altodo uses indentation for nesting), even right after a blank line. Markdown inline formatting works in task body.


## Example

```
# Project Plan #project

Regular markdown text here.

[ ] + Root task #id:root-001
    This task sets up the project skeleton.
    It must finish before any child task starts.
    /// side note: revisit naming once the API is frozen
    [ ] ! Child task @john #work -> 2026-12-31
        [x] Grandchild done #done:2026-01-15
        [ ] Grandchild open #dep:root-001
    [ ] Child with multi-line comment
        Comment line 1
        Comment line 2
        
        Comment line 4 (blank line 3 preserved)
[@] Sequential parent #seq-tasks
    [ ] Step 1 (ready)
    [ ] Step 2 (blocked by step 1)
    [ ] Step 3 (blocked by step 2)
[w] Waiting for @mary @designer
[~] Cancelled task
[ ] Tagged task #home #priority:high #owner:"john doe" 2026-01-01 -> 2026-06-30
```
