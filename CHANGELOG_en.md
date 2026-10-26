# Changelog

This file follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. The version number follows the header of `altodo.el` (currently 0.1.0).


## Unreleased

### Changes that affect compatibility

- `tag:`, `has-any-tag:`, `has-all-tags:` and `tag-value:` of the DSL use the same definition of a tag as the highlighting and the lists of dynamic filters. `#` comes at the beginning of the line or after a space, and the name is letters, digits, `_` and `-`. `tag:java` no longer matches `#java-x`, `x#java`, `(#java)` or `#java` in a URL
- `person:` and `has-any-person:` of the DSL match the whole name, which goes up to the next space. `person:bob` no longer matches `@bob,`, `@bob.` or `@bob.smith` (it still matches `@Bob`)
- The persons and the tags of dynamic filters are merged ignoring the case, in the spelling of the first use. `:sort-by "alpha"` also ignores the case
- Lines in a fenced code block do not match the state and flag patterns (`done`, `open`, `priority`, `star`, `state-any:`, `has-any-flag:`). A `# comment` there is not a heading
- A heading cuts the parent-child relation to the tasks above it. `parent-task-regexp:` and `root-task-regexp:` do not treat an indented task under a heading as a child of a task before the heading
- `N` of `level:N` must be an integer of 0 or more (before, `level:abc` worked as `level:0`)
- `(OP N)` of `tag-value:` takes `>`, `<`, `=`, `>=`, `<=` and a number only. `(!= 5)`, `(> abc)` and `(> 5 6)` are errors (before, they became a list of values or a condition that matches nothing)
- An empty operand of a logical operation (`and:open,,priority`, `and:open,priority,`) is an error. Spaces around an operand are removed (before, an operand with spaces was an error)
- An invalid regular expression is an error of the compilation also for `regexp:`, `parent-task-regexp:`, `root-task-regexp:` and `multiline-comment-contains:` (before, it was an error in the evaluation of each line, which stopped the filter)
- `:exclude-person`, `:exclude-tag` and `:exclude-tag-value` of a dynamic filter match the whole name (before, they matched a part of it, and `("id")` also left out `#idea`). The case is ignored, and a leading `#` or `@` may or may not be written. A value that is not a list makes the entry one that cannot be drawn
- `:dynamic-type "due"` and `"start"` of a dynamic filter collect the due dates (`-> DATE`) and the start dates (`DATE ->`) (before, they collected the values of the tags `#due:DATE` and `#start:DATE`, and the count of a selected entry was 0). `%s` of the list is a date in the format of `altodo-date-format`, and `:sort-by` works (`"alpha"` is chronological)
- `altodo-filter-show-overdue` does not show done and cancelled tasks (before, it included them)
- An unknown `:display-context` (such as `(quote all)`, written as `'all` in `.altodo-locals.el`) shows a message once and works as `heading-only` (before, it worked silently like `none`, and headings were not shown). Write the value without a quote
- With `:display-context` `heading-only` (the default) and `none`, the multi-line comments of matched lines are not displayed (before, the default `:multiline-comment t` displayed them). Only `all` displays them. An explicit `:multiline-comment` wins (`t` displays them with any value, `nil` hides them even with `all`). For an entry that should show the comments, give `:display-context all` or `:multiline-comment t`
- When `:count-format` is omitted in a sidebar entry, it is `t` (before: `nil` for an ordinary entry, `t` for dynamic filters and headings). `%n` in `:title` is replaced with the count. Give `:count-format nil` to keep `%n` as it is
- `:count-face-rules` applies to the digits of `%n` only. It no longer applies to the whole row when `:face-rules` is absent (as in section 13.6 of the design document)
- The internal variable `altodo-sidebar--active-entries` and the internal function `altodo-sidebar--update-active-entry` were removed. The clicked entry is held in `altodo-sidebar--selected-filters` (with `altodo-sidebar--selection-mode` `single`)
- Code written in `.altodo-locals.el` does not run by default: the lambda of `search-lambda`, `:count-pattern-lambda`, and a `:command` whose name does not start with `altodo-`. To run it, set `altodo-locals-code-policy` to `confirm` (runs only when the SHA-256 of the file is trusted) or `allow` (always runs). Code in `altodo-default-filter-patterns` runs as before
- The internal functions without a prefix, `sidebar-*`, are renamed to `altodo-sidebar--*` (`sidebar-display` is now `altodo-sidebar--display`). There are no compatibility aliases
- The built-in self-test functions (such as `altodo-run-full-test-suite`) are removed. Tests are unified as ERT tests in `test/`
- A date that does not exist (such as `2026-02-30`) is no longer treated as a date. It gets the plain date face and matches no date condition
- `:face-rules` evaluates only the operators `<`, `>`, `<=`, `>=`, `=` and `/=`
- The unit of moving a completed or cancelled task is now the subtree with its descendants (`altodo-move-unit` defaults to `subtree`). A task with a descendant that is not done is not moved. The batch and automatic moves handle only tasks without a parent. The older behavior is available with `altodo-move-unit` set to `line`, or with `C-c C-t D` (`altodo-move-done-task-alone`)
- `:limit 0` of a dynamic filter now means no limit (it used to give 0 rows). It is handled like `:limit nil`
- `heading:REGEXP` of the DSL is a regular expression searched in the heading text (it used to be a substring or a prefix match, depending on the state). Every heading with the same text counts. Write `C\+\+` instead of `C++`
- A child of a `#seq-tasks` task is blocked only while the sibling right above it is neither done nor cancelled (it used to be blocked if any earlier sibling was not done). The `#seq-tasks` parent is not shown as blocked
- The due date (`-> DATE`) and the start date (`DATE ->`) are recognized by one rule in the coloring, the filters, the calendar and the date input: in task lines, `///` comment lines and headings, not in multi-line comments or fenced code blocks, with a space around the date and the arrow (the filters used to accept `a->2026-01-01`)
- The settings `altodo-font-lock-maximum-decoration`, `altodo-move-single-line-comments-manually`, `altodo-sidebar-buffer-name` and `altodo-sidebar-auto-resize`, which had no effect, were removed
- `uuid` and `base62` of `altodo-insert-id-format` generate a UUIDv7 of RFC 9562 (the first 48 bits are the Unix time in milliseconds). The IDs made before are valid but do not sort by time together with the new ones
- The default of `altodo-week-start-day` is now Sunday (0) instead of Monday (1). The calendar of the sidebar, the calendar for entering dates, and the range of the date condition `this-week` start the week on Sunday. Set `altodo-week-start-day` to `1` for Monday. When the value is `nil`, the week also starts on Sunday
- The debug mechanism was rebuilt. `debug-helper.el`, `altodo-debug-mode`, `altodo-debug-log-file`, `altodo-debug-log-to-messages`, `altodo-debug-enable`, `altodo-debug-disable`, `altodo-debug-add-function`, `altodo-debug-remove-function`, `altodo-debug-clear-log` and `altodo-debug-view-log` were removed, and so was the redefinition of `message` for the whole Emacs when `altodo-debug-mode` was non-nil. Use the investigation commands of the optional file `altodo-debug.el` instead
- With `altodo-done-tag-datetime-format`, the value of `#done` is the result of the format alone (it used to get the time zone offset). A result with a space is double-quoted
- `:count-exclude-others nil` counts the lines other than tasks too (the setting used to be ignored)
- A save does not redraw the sidebar if it is not shown (it is drawn when it is shown)
- `C-c C-a`, `M-RET` and `RET` (on a task line or `///` line) add the task after the multi-line comment and descendant tasks of the task (they used to insert on the next line and push the children and the multi-line comment below the new task). `RET` does not split the line in the middle. `M-RET` adds the task as the last child
- `C-c C-f 1`, `2` and `3` remove the priority on a line that already has that priority (they used to leave it; the same as the toggle of the star flag)
- `C-c C-t @` (in progress) and `C-c C-t w` (waiting) remove the `#done` tag (they used to leave it)
- `M-<right>` and `M-<left>` move the multi-line comment of a task line or `///` line with it (it used to stay behind and attach to the previous task). Child tasks do not move (the user has yet to confirm this behavior: T20261024-14 in `project.altodo`)
- A state command does not change a line in a fenced code block
- `seq-tasks` is a special tag name. A tag that only starts with a special tag name, such as `#idea`, does not get the special tag color
- The star and priority flags of a `///` line are colored. A date and a tag in inline code are not colored. `@name` in a plain paragraph (not a multi-line comment) is not colored as a person. `#dep:` needs a space before it
- The faces `altodo-flag-priority-face` and `altodo-flag-priority-text-face` were removed (the old names stay as aliases of `altodo-flag-priority1-face` and `altodo-flag-priority1-text-face`)
- markdown-mode 2.6 or later is required (`Package-Requires`)


### Added

- Investigation commands (`altodo-debug.el`): diagnose a line (`altodo-debug-describe-line`), diagnose a DSL pattern (`altodo-debug-explain-pattern`), trace a function (`altodo-debug-trace`), measure the performance (`altodo-debug-profile`) and the information for a bug report (`altodo-debug-report`). `scripts/debug-line.sh` and `scripts/debug-pattern.sh` run them in batch mode. See `doc/debug_en.md`
- `altodo-filter-by-pattern` shows only the lines that match a DSL pattern. `altodo-filter-show-*` use the DSL (`altodo-filter-show-overdue` no longer depends on `altodo-date-format`)
- `altodo-sidebar-focus-after-activation` works: when non-nil, the source window is selected after a filter is chosen in the sidebar
- `scripts/bench-fontlock.sh` measures the time of the fontification
- The star flag (`+`) and the priority flag (`!` to `!!!`) can be used on the same line
- Heading jump: `:dynamic-type "heading"` for `:type dynamic` in `altodo-filter-patterns`. Selecting a heading moves point to the heading line in the source buffer and shows it near the top of the window (the filter is not changed; if the heading is hidden, the filter is cleared). `:level`, `:limit` (`0` or `nil` is unlimited), `:indent-by-level` (`t`, an integer or `nil`) and `%s`, `%l`, `%n` (unfinished tasks per heading) in `:title` are available. A `Headings` group was added after `People` in the default patterns
- The month calendar (`calendar`) is now the first entry of the default sidebar patterns (`altodo-default-filter-patterns`). If the sidebar is too narrow (by default 20% of the frame), a note is shown instead. To remove the calendar, delete the `:type calendar` line from `altodo-default-filter-patterns`
- The weekday names of the `agenda` follow `altodo-calendar-day-names` when it is changed from the default (with the default they are `Tue` etc. as before)
- The sidebar entries `calendar` (month calendar) and `agenda` (list by day). They show the number of tasks with due and start dates with faces and buttons, and selecting a day filters by the tasks of that day. Weekends and holidays (the Japanese national holidays by default), today, due dates (red background), start dates (blue background), days with many due dates, and overdue tasks are shown with faces of the `altodo-calendar` group. The names of weekdays and months, the format of the title, the `<` `>` buttons, the holiday function, and the priority of due and start dates are options. The date format of the list (`agenda`; the same as `altodo-date-format`, the same as the `#done` tag, or an own format), the weekday, the strings "Today", "Tomorrow" and "Overdue", and a line break after the label are set with the properties of the entry (`:date-format`, `:show-weekday`, `:today-label`, `:tomorrow-label`, `:overdue-label`, `:label-newline`)
- The mini calendar library `altodo-calendar.el` (depends only on `calendar`). Put it in the same directory as altodo.el. `altodo-calendar-insert`, `altodo-calendar-japanese-holiday` and `altodo-calendar-emacs-holiday`
- Date input: `C-c C-e d` (`altodo-select-due-calendar`) and `C-c C-e s` (`altodo-select-start-calendar`) select the due or start date in a calendar window. `altodo-input-due-date` and `altodo-input-start-date` enter it in the minibuffer
- Sidebar help: `?` or `h` (`altodo-sidebar-help`) shows the key bindings
- `altodo-move-after-days`: the batch and automatic moves take only tasks whose `#done` date is N or more days ago
- New DSL patterns: `state-any`, `has-any-flag`, `has-any-tag`, `has-all-tags`, `has-any-person` (several values, separated by commas or `|`), `task`, `comment`, `multiline-comment`, `heading`, `empty-line` and `any-line`
- `#group-start` and `#group-due` are added to the specification
- If a buffer visits the done file, the entry is appended to that buffer
- In the automatic move, a failure in one buffer no longer stops the other buffers. A read-only buffer is skipped with a message
- Development scripts (`scripts/`): installing Emacs, tests, lint, benchmark, checking the names in the documents, and a local CI
- The list of tests (`test/INDEX.md`), common helpers, and a test that validates the sample files


### Changed

- `parent-task-regexp:` and `root-task-regexp:` are computed in one pass over the buffer. 5000 indented tasks without a parent took 57 s and now take 0.1 s or less
- `altodo-sidebar-size` (also the setting of the same name in `.altodo-locals.el`) is applied. Below 1 it is a ratio of the frame; 1 or more is the number of columns (rows for above and below). Before, the width was the Emacs default (a quarter of the frame width) for any value
- `altodo-sidebar-position` accepts `above` and `below` (before, they caused an error)
- `:dynamic-type` accepts the symbol `person` as well as the string `"person"`
- `heading:REGEXP` and `:display-context` handle Setext headings (before, only ATX headings)
- `start-date:tomorrow` can be used
- A click on `[AND]` or `[OR]` in the mode line keeps a multiple selection and filters again (the same as `C-c C-t`; before, it cleared all filters)
- With `s` in the sidebar, an entry other than `search-simple` and `search-lambda` (such as `command`) cannot be selected (before, selecting one hid all lines)
- An entry that cannot be drawn (a lambda that counts signals an error, `:nest` is not an integer, and so on) is left out with a message shown once. The other entries are drawn (before, the whole sidebar was not drawn)
- Among equal counts, `:sort-by "count"` of a dynamic filter sorts by name in ascending order
- The message for a logic operation with empty operands (`and:`) is `The logic operator has no operands` (before, an internal error)
- The README describes the behavior of the sidebar and the filter commands
- The expansion of dynamic filters (`:type dynamic`) and headings passes on the properties it does not use itself, such as `:face-rules`, `:count-face-rules`, `:count-exclude-others`, `:display-context` and `:multiline-comment`, to the expanded entries (before: only `:face`, `:face-count` and `:count-format`). `:face-rules` of a heading is evaluated with the number of unfinished tasks under the heading
- The values of `:face`, `:face-count`, `:face-rules` and `:count-face-rules` can be a face name, a list of face names, a plist (`(:foreground "red")`) or the defface style (`((t (:foreground "red")))`). `:face` ignored a plist before
- A rule of `:face-rules` or `:count-face-rules` with an invalid form is ignored alone, and a message is shown once (before: the whole sidebar was not drawn)
- The count that `:face-rules` uses in a multiple selection is the same value as `%n` in the title (with the combined predicate), also for a title without `%n`
- A click in the sidebar is faster. One click drew the sidebar twice and now draws it once, and the counts of the entries are reused while the buffer does not change. For 5000 lines and the default patterns, it takes about 0.2 s (second click on) instead of about 1.4 s
- The sidebar buffer has its own major mode, `altodo-sidebar-mode`, derived from `special-mode`. The key bindings of `special-mode` work too
- The due entries of the default patterns ("Open and Over Due" and so on) use DSL patterns instead of a `lambda`. The display and the counts are the same
- The `:count-face-rules` of "Star (+)" in the default patterns was removed (the count was shown in `error` from 5 and `warning` from 1). Like "Priority (!)", the count has no color
- Internal cleanup: unused functions (parts of the former filter, line number calculations, a duplicated matcher; about 20) and stale comments (references to files that do not exist, names of development phases) were removed. The 24 `lambda`s of the key map and the repetition in the five commands that set a state were reduced
- The multi-line comment rule follows the specification (the indentation of the previous task or `///` line plus 4 spaces). A deeper line or a completely empty line (0 characters) ends the comment
- The filter is faster. For 10,000 lines (`tag:work`, with display context) the time went from 2.99 s to 0.36 s. The limit of 10,000 lines is removed
- A syntax error, content that is not an alist, and invalid entries in the configuration file are reported with a warning and not used. The same warning is shown once each time the file is modified
- The done file is written through a temporary file and replaced. For a read-only buffer or a done file that cannot be written, nothing is moved and an error is signaled
- If a filter predicate signals an error, the filter is cleared
- `altodo-auto-move-interval` accepts only a positive number
- `scripts/bench-fontlock.sh` also measures the time to refontify after editing one line (edit-ms). The samples now include `contiguous`: few blank lines and many `///` lines
- The option `altodo-inline-code-cache` (default `t`). With `nil`, the search of the inline code spans while fontifying is left to markdown-mode
- The difference between dates is counted in calendar days. A day at the switch of summer time still counts as one day


### Fixed

- With more than 1000 candidates starting with `#` on lines that are not task lines and so on, the tags and persons after them were not colored (the limit on the number of repetitions of `altodo--tag-matcher`, `altodo--tag-with-value-matcher` and `altodo--person-tag-matcher` was removed)
- The result of a partial fontification (scrolling, editing) could differ from that of the whole buffer, and the colors of fenced code blocks were not restored. The fontified region is now returned to jit-lock, and the colors are restored in that region. For 2500 random documents, the share of partial fontifications that equal the whole fontification went from 44% to 91%
- In a buffer without fence marks (```, `~~~`) and YAML borders (`---`), the fenced block test took about 20% of the fontification time. The query to markdown-mode is now skipped
- The fontification of a region without `#dep:` repeated a failed search up to 1000 times, so Emacs froze for seconds when scrolling a large file. For a 2600-line buffer without any `#dep:`, the fontification of the whole buffer went from 2.1 seconds to 0.18 seconds (`altodo--dep-tag-matcher`)
- `:display-context all` also displayed the line after a multi-line comment (a line that does not match)
- A click on a `search-lambda` entry did not end a multiple selection. `:display-context` is applied too
- After `altodo-filter-by-pattern` or `altodo-filter-show-*`, the selection (color) of the sidebar did not match the actual filter. They now clear the selection of the sidebar and draw it again
- `c` in the sidebar did not clear the filter of the source buffer
- After the sidebar was hidden and shown again, the counts of a multiple selection returned to the total
- `C-c C-v f c`, `C-c C-v s t` and `C-c C-v s r` did not work on headings and plain text lines (the Markdown command ran instead); they now work on every line
- The time of the fontification was proportional to the square of the number of lines; fontifying a whole buffer of 5000 lines took 53 seconds
- With a format for `#done`, the tag got a time zone offset or was cut at a space
- Moving to the done file put a task of `# Work` under `# Workshop`
- Reading `.altodo-locals.el` binds `read-eval` to nil
- False detection of a person (`@name`): an `@` that is neither at the beginning of a line nor after a space, such as in `https://example.com/test@hogefuge` or `john@example.com`, was treated as a person by the dynamic filter `person`, the `person:NAME` pattern and `altodo-filter-show-person`
- The boundaries of the `this-week` and `this-month` date conditions (the week start day setting, the last day of the month)
- Relative conditions such as `today`, `overdue` and `this-week` gave wrong results when `altodo-date-format` was not `%Y-%m-%d`
- Prefix matching of `#id` values that contain a hyphen (`#id:T1` matched `#id:T1-2`), and `altodo-goto-dependency` jumping to `#id:A1` for `#id:A`
- Dates were encoded as 01:00 in time zones with summer time
- `altodo-toggle-comment` doubled the spaces and lost the indentation
- Moving a task with TAB did not move its multi-line comment. TAB on a normal text line recursed endlessly. `indent-tabs-mode` inserted TAB characters
- `altodo--filter-lines` could not hide multi-line comments (`nil` for `show-multiline-comment`)
- In the sidebar, switching AND/OR with no filter selected and selecting a `nil` entry signaled errors
- The `#seq-tasks` tag also matched part of a longer tag name (such as `#seq-tasks-x`)
- Removed the unused `altodo--update-seq-tasks-status`, which called the undefined `font-lock-fontify-line`
- Fixed the warnings of docstrings, byte-compile, checkdoc and package-lint (package-lint went from 17 to 5)
