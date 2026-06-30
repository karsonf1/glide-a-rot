# Sessions

One file per session: `YYYY-MM-DD.md`. If multiple sessions happen the same day, append to the
existing file rather than creating a second one.

Template:

```markdown
# Session — YYYY-MM-DD

## Shipped
- [list of completed items]

## In Progress
- [list of items started but not finished, with next step noted]

## Decisions Made
- [any design/architecture decisions resolved today — link to the decisions/ file created]

## Blockers / Open Questions
- [anything that came up and isn't resolved — add to open-questions.md too if it's a real
  design fork, not just a one-off task blocker]

## Notes
[anything else worth remembering — context that doesn't fit the above]
```

This folder is a journal, not a status board — project-state.md is the live snapshot, this is the
history of how it got there. Useful for retracing reasoning later, or just satisfying as a record
of progress.
