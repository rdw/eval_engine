---
name: bugfix-pass
description: Use when asked explicitly to perform a bugfix pass.
---

Use `glab ci status` to see if there are any errors in the latest CI run. If so, look at the logs and try to fix the error.  Use the `glab` skill.  Ignore if it's running.

Whenever you apply a fix for this sort of build, spin up a review subagent to read through the code fix and suggest improvements.  Don't take its advice blindly, as it won't have the same context for the fix as you do, but do take it seriously and consider whether your fix could be made clearer in its intent or if you're truly tackling the root problem or just papering over a symptom.  Do not commit, wait for human review as well.
