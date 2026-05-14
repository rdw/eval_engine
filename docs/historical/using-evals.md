---
name: using-evals
description: Use when running eval modules, checking scores, comparing results, or investigating eval failures - explains cost-free checking workflow and command options for LLM-based evaluation systems
---

# Using Evals

## Overview

Eval modules test LLM-based code by comparing generated outputs against expected results. **Critical**: Checking scores is FREE, running generates new outputs and COSTS MONEY (LLM API calls).

## Core Workflow

**Typical pattern:**

1. Run once: `mise eval <name> --run` (costs money, updates current.yaml)
2. Check many times: `mise eval <name>` (free, shows scores only)
3. Test one example: `mise eval <name> --run --only <key>` (cheap, reevaluates only one example and reinserts it)
4. Investigate: `mise eval <name> --diff` (free, shows what changed)
5. Accept: `mise eval <name> --promote` (free, saves current as checkpoint)

**Most common mistake:** Using `--run` to "check if passing" - this costs money unnecessarily.

## Module Naming

**Always use module name WITHOUT the `_eval` suffix:**

- ✅ `mise eval select_main_variant`
- ❌ `mise eval select_main_variant_eval`

The runner finds `eval/select_main_variant_eval.rb` and `eval/files/select_main_variant_eval/` automatically.

## Quick Reference

| Task                 | Command                               | Cost    | Notes                                 |
| -------------------- | ------------------------------------- | ------- | ------------------------------------- |
| Check scores         | `mise eval <name>`                    | FREE    | Compares existing current vs expected |
| Generate new results | `mise eval <name> --run`              | COSTS $ | Runs LLM, updates current.yaml        |
| See what changed     | `mise eval <name> --diff`             | FREE    | Diffs current.yaml vs checkpoint.yaml |
| Detailed comparison  | `mise eval <name> --debug`            | FREE    | Shows per-example match scores        |
| Save as checkpoint   | `mise eval <name> --promote`          | FREE    | Moves current.yaml to checkpoint.yaml |
| Test one example     | `mise eval <name> --run --only <key>` | COSTS $ | Runs single test case                 |
| Run all evals        | `mise eval --run`                     | COSTS $ | Runs every eval module                |

## Understanding Scores

Output format:

```
Current: 0.85
Checkpoint: 0.92
```

- **Current**: How current.yaml matches expected.yaml (0.0 to 1.0)
- **Checkpoint**: How checkpoint.yaml matches expected.yaml
- **Lower current score**: Something regressed, use `--diff` to investigate
- **Higher current score**: Improvement, consider `--promote` to accept

## When To Use Each Command

**Just merged code changes?**

```bash
mise eval <name>  # Check if still passing (free)
```

**Modified the eval code itself?**

```bash
mise eval <name> --run  # Generate fresh results (costs money)
```

**Want to understand what changed?**

```bash
mise eval <name> --diff  # See exact differences (free)
mise eval <name> --debug  # See scoring details (free)
```

**Results look good, make it official?**

```bash
mise eval <name> --promote  # Save as new checkpoint (free)
```

**Debugging one specific test case?**

```bash
mise eval <name> --debug  # First check existing score (free)
mise eval <name> --run --only example_key  # Then re-run if needed (costs less)
```

## Common Mistakes

### ❌ Re-running to check scores

```bash
# User: "Did my code change break the eval?"
mise eval <name> --run  # WRONG: Costs money unnecessarily
```

### ✅ Check existing results first

```bash
mise eval <name>  # RIGHT: Free, shows if current.yaml still matches expected.yaml
```

**Why:** Most code changes don't affect eval output. Check first, run only if needed.

### ❌ Using \_eval suffix

```bash
mise eval select_main_variant_eval  # WRONG: Won't find module
```

### ✅ Use base name

```bash
mise eval select_main_variant  # RIGHT: Runner appends _eval automatically
```

## Real-World Example

Developer modifies `Prompts::SelectMainVariant` code:

```bash
# 1. Check if still passing (free)
mise eval select_main_variant
# Output: Current: 0.92, Checkpoint: 0.92 ✓

# 2. If scores dropped, investigate
mise eval select_main_variant --diff
# Shows exact differences in yaml files

# 3. If differences are expected (improved prompt)
mise eval select_main_variant --run  # Generate fresh baseline
mise eval select_main_variant --debug  # Verify new results
mise eval select_main_variant --promote  # Accept as new checkpoint
```

## File Structure Reference

For module `select_main_variant`:

```
eval/
  select_main_variant_eval.rb              # Module code
  files/
    select_main_variant_eval/
      inputs.yaml         # Test cases
      expected.yaml       # Expected outputs
      checkpoint.yaml     # Known good baseline
      current.yaml        # Generated results
```

Commands compare these YAML files, only `--run` executes the module code.
