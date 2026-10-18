# altodo Text Format Specification

## License

__altodo__ is a custom extension of the __Markdown__ and __CommonMark__ format specifications. For the Markdown format, see https://daringfireball.net/projects/markdown/. For the CommonMark format, see https://commonmark.org/.
The MIT License applies to the altodo format specification (custom extensions). For details, see `doc/LICENSE-MIT`.


### References and Acknowledgments

altodo is partially based on and inspired by __[x]it!__ https://xit.jotaen.net/, which is licensed under Creative Commons CC0 1.0 Universal. We express our respect to Jan Heuermann, the author of [x]it!, and all contributors.


## 1. Overview

`altodo` is a TODO format that can be embedded in Markdown (CommonMark) files.
While it is designed to be embedded within Markdown, it is a custom extension based on Markdown, so text files containing tasks in this format are called "altodo" files (format).
altodo files have the `.altodo` file extension.

Format characteristics:

- Text format specification as a custom extension of Markdown (CommonMark)
    - Formats other than altodo follow the Markdown (CommonMark) format specification
- TODOs can be nested infinitely
- Single-line and multi-line comments are supported
- Tags, star flags, priority, start dates, due dates, and dependency tags can be assigned


## 2. Sample

Below is a sample of altodo format text embedded in a Markdown (CommonMark) file.

```
# altodo is a TODO format that can be embedded in Markdown

If the surrounding lines are not task lines, you can write __regular Markdown (CommonMark) text__ like this.

[ ] Task line starts here
[ ] You can embed inline `Markdown` formatting like __bold__ and ~~strikethrough~~ in tasks
[x] Task line ends here

Lines other than task and comment lines follow regular Markdown (CommonMark) format.


# Tags can be embedded in headings too #tag

## altodo file example #tag

Below is an example of tasks written in altodo format.

[@] Task in progress
    /// Single-line comment
    [ ] Child task A (indentation is typically 4 spaces)
        [x] Completed child task
            [~] Cancelled task
    [w] Waiting task @JohnDoe is handling
[ ] + Task with star flag
    [ ] ! High priority task
        [ ] !! Higher priority task
            [ ] !!! Highest priority task
[ ] Task
    Multi-line comment line 1
    Multi-line comment line 2
    [ ] Nested task A
        Multi-line comment for nested task A line 1
        Multi-line comment for nested task A line 2
        
        Nested task A multi-line comment line 4
        ※ The line between lines 2 and 4 has the same indentation as the previous line, so it continues the multi-line comment
[ ] Task with tag #home Space before and after tag is required
[ ] Task with start date 2025-01-01 -> starts from this date
    [ ] Task with due date -> 2025-12-31 must be completed by this date
    [ ] Task with both start and due date 2025-02-01 -> 2025-03-31 must be completed within this period
[ ] Task with key-value tag #key:value
[ ] Task with dependency (unique ID) #id:20250101-0000
[ ] Task with dependency reference #dep:20250101-0000
[ ] Another task with dependency reference #dep:20250101-0000
[ ] Task with person tag @JohnDoe or location tag @home
```


## 3. Format Specification

### 3.1 altodo Overview and Markdown (CommonMark)

altodo is a TODO format that can be embedded in Markdown (CommonMark).
The design avoids conflicts with other Markdown (CommonMark) syntax (headings, lists, code blocks, etc.), so Markdown (CommonMark) syntax including inline elements can be used as-is.
Text containing altodo syntax enclosed in backticks (`) for inline code or code blocks is treated the same as Markdown (CommonMark) code and does not have the effect of altodo syntax.
However, because altodo expresses nesting and multi-line comments with indentation, indented task lines, single-line comment lines, and multi-line comments are never treated as Markdown (CommonMark) indented code blocks, even right after a blank line.


### 3.2 Task Lines and Comment Lines (Single-line and Multi-line)

#### 3.2.1 Task Lines and Single-line Comment Lines

A task line must start with one of `[ ]`, `[x]`, `[@]`, `[w]`, or `[~]` (collectively called __task state marks__), which indicate the task status.
A single-line comment line starts with `///` (called __single-line comment mark__) and is treated as a detached note (a side remark, a review memo, etc.) that is not part of the task. A single-line comment line is a single line only.
Immediately after each mark, one space is required.
For subtasks, indentation with spaces is added from the beginning of the line.

__Example__

```
[ ] Task line
/// This is a single-line comment line
```


#### 3.2.2 Subtasks

Subtasks (child task lines or single-line comment lines) can be added to task lines and single-line comment lines.
For subtasks, they begin with the indentation of the previous task line or single-line comment line + 4 spaces.
Subtasks can be nested infinitely.

```
[ ] Task (parent)
    [ ] Subtask (child)
/// Single-line comment (parent)
    /// Single-line comment (child)
    [ ] Subtask (child)
        [ ] Subtask (grandchild)
    [ ] Subtask (child)
```


#### 3.2.3 Multi-line Comments

Multi-line comments are comment lines spanning multiple lines attached to a task line or single-line comment line.

- The first line of a multi-line comment begins with the indentation of the previous task line or single-line comment line + 4 spaces, and attaches to that previous line. This rule applies without exception.
- Every line with the same indentation as the first line, other than a task line, is part of the multi-line comment. This includes Markdown lists, links (`[text](URL)`), and fenced code blocks.
- Subsequent lines of a multi-line comment have the same indentation as the previous multi-line comment line. A line that keeps the indentation but contains only spaces is also part of the multi-line comment.
- A multi-line comment ends with a line whose indentation is different (shallower or deeper), or a completely empty line (zero characters). There is no exception: a more deeply indented line, such as a nested Markdown list item, is not part of the multi-line comment.
- A line starting with a task state mark is always a task line. To write text that starts with a task state mark as-is in a multi-line comment, enclose it in a fenced code block.

__Example__

```
[ ] Task
    Multi-line comment line 1
    Multi-line comment line 2
    
    Multi-line comment line 4
    ※ The line between lines 2 and 4 has the same indentation as the previous line, so it continues the multi-line comment
    [ ] Subtask
        Multi-line comments can also be specified for subtasks
```

__Examples that are not multi-line comments__

```
[ ] Task
    [ ] Subtask
    A line with the same indentation as the subtask. Not the subtask's indentation + 4 spaces, so it is normal Markdown text
            A line with the subtask's indentation + 8 spaces. Not + 4 spaces, so it is normal Markdown text
```


#### 3.2.4 Choosing Between Multi-line Comments and Single-line Comments

Both multi-line comments and single-line comments can be written under a task. Choose according to whether the text is part of the task.

- Multi-line comment (no mark): the description or rationale of the task itself, as part of the task definition. Write a task description as a multi-line comment, even if it is a single line.
- Single-line comment (`///`): a detached note (a side remark, a review memo, etc.) that is not part of the task. It can be indented under a task for grouping, but it is not part of the task definition. The `///` mark takes a single line, but it can be followed by a multi-line comment without a mark. In this case, the text is also treated as a detached note.

Do not stack multiple `///` lines to write a task description. Use a multi-line comment without a mark.

```
[ ] Task
    Description of this task (part of the task)
    /// Side note: revisit the naming once the API is frozen (a note that is not part of the task)
```


### 3.3 Task Line Types (Open, Completed, In Progress, etc.)

Task state marks for task lines are of the following types:

| Mark | Type        | Category           | Details                                     |
| ---- | ----------- | ------------------ | ------------------------------------------- |
| [ ]  | Open        | Open (In Progress) | Task not yet started                        |
| [@]  | In Progress | Open (In Progress) | Task currently in progress or being handled |
| [w]  | Waiting     | Open (In Progress) | Task on hold (waiting state)                |
| [x]  | Completed   | Completed          | Task completed (after execution)            |
| [~]  | Cancelled   | Completed          | Task cancelled before completion            |


### 3.4 Flags

The string immediately after the task state mark of a task line or the single-line comment mark of a single-line comment line is called a __flag__.
After the flag, one space is required.

__Example__

```
[ ] + Task with star flag
[ ] +NG Example line. Intended to add a star flag, but missing one space. Treated as normal text.
/// ! Flags can also be added to single-line comment lines
```


#### 3.4.1 Star

A task can be designated as having a star (particularly high importance).
When the flag is `+`, the task becomes a star. A star indicates a task of particularly high importance.

__Example__

```
[ ] + Task with star flag indicating particularly high importance
```


#### 3.4.2 Priority

Tasks can be prioritized according to importance.
When the flag `!` is added, the more `!` characters, the higher the importance of the task.
Compared to star `+`, which has higher priority is up to the user.
Four or more `!` characters are truncated to 3 internally and treated equivalently.

__Example__

```
[ ] ! High priority task
[ ] !! Higher priority task
[ ] !!! Even higher priority task
[ ] !!!!!! Even higher priority task, but treated the same as 3 `!` (`!!!`) by the application
```


#### 3.4.3 Using a Star and a Priority Together

A star `+` and a priority `!` can be used together, in either order (`+ !! Task`, `!! + Task`). Each kind can appear at most once on a line. Each flag must be followed by one space.
When the application writes the flags, it writes the star first, then the priority.

__Example__

```
[ ] + !! Task with a star and a priority
[ ] !!! + The order can be swapped
/// + ! A single-line comment can use both too
```


### 3.5 Inline Elements

Inline elements specific to the altodo format are described below. For Markdown inline formatting, refer to the Markdown specification.
altodo inline elements can be embedded in altodo task lines, single-line comment lines, and Markdown headings.
When placed elsewhere, they are treated as normal text.


#### 3.5.1 Tags

Like social media hashtags, tasks can have properties.
Tags start with `#` and must match the regular expression `[-_a-zA-Z0-9]+` for ASCII strings.
However, by enclosing only the value in double quotes (`"`), ASCII strings other than half-width characters can be used, including spaces.
Tags can be embedded in the body or in headings.
Multiple tags can be specified for a task.
Space before and after tag is required. However, if a tag comes at the end of a line, the space at the end of the line is not required.
Tags can be key-value type properties in the format `#key:value`.

__Example__

```
[ ] #home Task to be done at home
[w] Waiting for specification submission #work-by:john
[x] #work #company #clock:8AM Regular task
[ ] When a tag is specified at the end of a line, no space at the end is required #end-of-line
[ ] To use multi-byte characters as values, enclose in double quotes #char:"日本語"
[ ] By enclosing in double quotes, #tag:"space can be included" is possible
```


#### 3.5.2 Start Date and Due Date

Start date and due date can be specified for a task. Date notation is in `YYYY-MM-DD` format, but any format can be specified. For example, `YYYY/MM/DD` format.
Space before and after start date and due date is required. However, if a date comes at the end of a line, the space at the end of the line is not required.

- Start date specification: `YYYY-MM-DD ->`
- Due date specification: `-> YYYY-MM-DD`
- Both specifications: `YYYY-MM-DD -> YYYY-MM-DD`

```
[ ] Task starting on June 1, 2000 2000-06-01 ->
[ ] Task with due date of December 31, 2001 -> 2001-12-31
[ ] Task starting January 1, 2002 with due date of March 31 of the same year 2002-01-01 -> 2002-03-31
    [ ] This task must be completed by -> 2002-02-15, etc., can be placed anywhere


## Project 2003-04-01 -> 2004-03-31

Can also be applied to headings
```


### 3.6 Special Tags

Special tags that have special properties and have special effects on tasks are described below.


#### 3.6.1 ID #id

A tag with a unique identifier of arbitrary length can be created.
Add `#id:[value]` to a task line, and other task lines can reference this ID.
`[value]` can be any value, but typically a unique ID should be assigned.

__Example__

```
[ ] This task has #id:20010101_abc
[ ] UUID #id:7d444840-9dc0-11d1-b245-5ffdce74fad2 is also acceptable
```


#### 3.6.2 Dependency #dep

A tag indicating a dependency can be created. For tasks with dependencies, a dependent task cannot be executed unless the dependency is completed.
Specify the value of the referenced ID with `#dep:[value]`.
It is possible to specify a non-existent ID value, but no dependency is set and the task becomes a task without dependencies.

```
[ ] Task with assigned ID #id:20030120_abcd
[ ] Task with dependency (dependent task) #dep:20030120_abcd
[ ] Task with dependency specification but no dependency. Isolated, so no dependency #dep:19990101_xyz
```

Isolated tasks without dependencies may occur when the dependency is completed and removed from the list, etc.


#### 3.6.3 Person/Location Tag @person

A special tag representing a person or location. After `@`, specify any string (excluding spaces).
Space before and after tag is required. However, if a tag comes at the end of a line, the space at the end of the line is not required.

__Example__

```
[ ] Task @smith to confirm
[ ] Meeting @田中 @会社 2026-02-15
[ ] Shopping @school nearby
[ ] Review request @john @mary
```

__Usage__

- Specify assignee
- Specify location
- Use as filter condition


#### 3.6.4 Task Completion/Cancellation Time #done

A tag recording the time when a task was completed or cancelled. Adding this tag is optional.
※ Expected to be automatically added by the application.

The value is in ISO 8601 format by default (`YYYY-MM-DDTHH:MM:SS+HH:MM`).
`YYYY-MM-DD` or unixtime are also acceptable. User discretion is fine.
If a task becomes open again, remove the `#done` tag.

__Example__

```
[x] Document creation #done:2003-01-15
    [~] Conduct review #person:john #done:1042624800
```


#### 3.6.5 Group Start Date and Due Date #group-start, #group-due

Tags indicating the start date and due date of a "group" made of a task and its subtasks. Add them to the parent task; they represent the start date and due date of the parent task and all its subtasks. They are used to specify the dates of all subtasks at once on the parent task, instead of adding a start date and due date to each subtask.
The value is a date, in the same format as the start date and due date in 3.5.2.

__Example__

```
[ ] Project A #group-start:2026-03-01 #group-due:2026-06-30
    [ ] Design
    [ ] Implementation
```


#### 3.6.6 Sequential Execution of Subtasks #seq-tasks

A tag that makes subtasks execute from top to bottom. When `#seq-tasks` is added to a parent task, each child task cannot be executed until the preceding sibling task is completed (`[x]`) or cancelled (`[~]`).

__Example__

```
[@] Parent task executed sequentially #seq-tasks
    [ ] Step 1 (can be executed)
    [ ] Step 2 (cannot be executed until step 1 is finished)
    [ ] Step 3 (cannot be executed until step 2 is finished)
```


### 3.7 Literal Text and Escaping

A way to write `#`, `@`, or `->` as-is, without the effect of a tag, person tag, or date (escaping with `\`), is not supported at present. Support is planned for the future.
For now, work around it with the rule on surrounding spaces (`foo@bar` is not a person tag) or with a fenced code block.
