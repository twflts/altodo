# altodo Format Specification (Compact)

altodo: TODO format embeddable in Markdown/CommonMark. Extension: `.altodo`. MIT licensed (altodo format extensions only; Markdown/CommonMark parts follow their respective specifications).

## Line Grammar

```
TASK_LINE    := INDENT STATE SP [FLAG SP] BODY
COMMENT_LINE := INDENT "///" SP BODY
MULTILINE    := INDENT BODY  (where INDENT = parent INDENT + 4 spaces)
MARKDOWN     := any line not matching above patterns

STATE := "[ ]" | "[@]" | "[w]" | "[x]" | "[~]"
FLAG  := "+" | "!" | "!!" | "!!!"
SP    := " " (exactly one space)
INDENT := 0 or more spaces (multiples of 4 for nesting)
BODY  := text with optional inline elements (tags, dates, @person)
```

## States

`[ ]` open, `[@]` in-progress, `[w]` waiting, `[x]` done, `[~]` cancelled

## Flags

`+` star (important). `!`/`!!`/`!!!` priority 1-3 (4+ truncated to 3). Mutually exclusive with each other. Placed immediately after state mark + space.

## Nesting

Child indent = parent indent + 4 spaces. Unlimited depth. Applies to tasks, single-line comments, and multi-line comments.

## Multi-line Comments

Lines indented at parent indent + 4 spaces, following a task or single-line comment. Continue while indent is maintained. Blank lines with same indent are part of the comment. Ends when indent decreases.

## Inline Elements (in BODY of task lines, comment lines, and Markdown headings)

### Tags
`#name` or `#name:value` or `#name:"value with spaces"`. Name regex: `[a-zA-Z0-9_-]+`. Space required before `#` (or line start). Multiple per line.

### Dates
`YYYY-MM-DD ->` (start), `-> YYYY-MM-DD` (due), `YYYY-MM-DD -> YYYY-MM-DD` (both). Space required around dates and `->`.

### Person/Place
`@name` where name is any non-space chars. Space required before `@` (or line start). Multiple per line.

## Special Tags

- `#id:VALUE` — unique task identifier
- `#dep:VALUE` — dependency on `#id:VALUE` (blocked until target done; orphaned deps ignored)
- `#done:TIMESTAMP` — completion time (ISO 8601 / unix time; removed on reopen)
- `#seq-tasks` — children execute sequentially top-to-bottom (each child blocked by previous sibling)

## Markdown Integration

Non-task/comment lines are pure Markdown. Code blocks (fenced or indented) disable altodo syntax. Markdown inline formatting works in task body.

## Example

```
# Project Plan #project

Regular markdown text here.

[ ] + Root task #id:root-001
    /// Single-line comment
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
