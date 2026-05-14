---
name: glab-ci-debugging
description: Patterns for debugging GitLab CI jobs using glab CLI
allowed-tools: Bash, Grep
---

# GitLab CI Debugging with glab

## When to Use

When you need to inspect failed CI jobs, debug timeouts, or get job details.

## Quick Reference

```bash
# Current branch pipeline status
glab ci status

# List recent pipelines across all branches
glab ci list

# Pipeline details with job IDs
glab ci get -p {pipeline_id} -d

# Read job logs (always pass a job ID — without one it opens an interactive menu)
glab ci trace {job_id} 2>&1 | tail -100
```

## Typical Workflow

1. `glab ci status` — see if the pipeline passed or failed, get the pipeline ID
2. `glab ci get -p {pipeline_id} -d` — find the failed job ID, name, and failure reason
3. `glab ci trace {job_id} 2>&1 | tail -100` — read the end of the log
4. Fix the issue locally, push, and re-check

## Debugging Timeouts

When `failure_reason` is `job_execution_timeout`:
- Check `glab ci trace {job_id} 2>&1 | tail -50` for the last output before timeout
- A task that started but has no "Finished in" marker likely hung
- Large timestamp gaps indicate a task running without output
