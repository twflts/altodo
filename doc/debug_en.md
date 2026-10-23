# Investigation Commands

The commands that find out why altodo behaves as it does are in a separate file, `altodo-debug.el`. altodo itself does not load it, and the commands change no setting.

To use them, put the file next to `altodo.el` and `(require 'altodo-debug)`. The results go to the buffer `*altodo-debug*`, or to the standard output in batch mode.


## Diagnose a Line

`M-x altodo-debug-describe-line` (a prefix argument is the line number) shows what altodo sees in a line.

- The kind of the line (task, comment, multi-line comment, heading, inside a code block), the indent and the chain of headings
- The state, flags, tags, persons, due and start dates (and their distance to today), `#done` and `#id` of a task
- The result of `#dep` (blocked, ready, circular) and the state of `#seq-tasks`
- The faces of the first and the last character
- Whether a filter hides the line
- The result of each simple DSL pattern (`done`, `open`, `task`, ...)

A check that fails is shown as the text of its error. You can find out "why is this line shown as blocked" or "why is it not in the filter" without changing any setting.


## Diagnose a Pattern

`M-x altodo-debug-explain-pattern` shows how a DSL pattern is parsed and which lines it matches.

- The normalized structure (`simple`, `arg`, `logic`) and the result of the validation
- The reason why it cannot be compiled (the sidebar treats a pattern that cannot be compiled as one that matches nothing, without a reason)
- The number of matching lines, the first 20 line numbers and the time


## Trace and Measure

- `M-x altodo-debug-trace`: choose an altodo function and write its calls to `*trace-output*` (`trace-function-background`), with the arguments, the value and the depth. `M-x altodo-debug-untrace-all` stops it.
- `M-x altodo-debug-profile`: measure `fontify` (fontify the whole buffer), `sidebar` (draw the sidebar) or `filter` (apply a DSL pattern) with the CPU profiler, and show the report.
- For stepping use `edebug-defun`; for a backtrace on errors use `toggle-debug-on-error`.


## Information for a Bug Report

`M-x altodo-debug-report` shows the versions of Emacs, markdown-mode and altodo.el, the number of lines of the buffer, the state of `.altodo-locals.el` and of the sidebar, and the `altodo-` options that differ from the standard value. Paste it into a bug report.


## Batch Mode

The results go to the standard output. Use them to share a reproduction and for automation.

```
scripts/debug-line.sh FILE LINE
scripts/debug-pattern.sh FILE PATTERN
```

The exit code is 0 on success and 2 for a wrong argument. The performance is measured with `scripts/bench-filter.sh` (filters) and `scripts/bench-fontlock.sh` (fontification).
