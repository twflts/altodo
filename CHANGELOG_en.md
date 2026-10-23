# Changelog

This file follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. The version number follows the header of `altodo.el` (currently 0.1.0).


## Unreleased

### Changes that affect compatibility

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
- The difference between dates is counted in calendar days. A day at the switch of summer time still counts as one day


### Fixed

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
