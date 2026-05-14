# Development Guidelines for Eval Engine

This document contains the core development guidelines that apply to all work on this project. For context-specific rules, see the `.claude/rules/` directory.

## Goal

To produce a Rails Engine that makes developing using LLM evals easy and powerful.  The engine improves human productivity by providing a HTML UI that runs the evals and displays their results, and agent productivity with a simple but powerful CLI and Ruby API.

## The Workflow

### 1. Plan First

When asked to implement any feature, ALWAYS ask: **"Should I create a Plan for this task first?"**

If user agrees:

1. **Interview the user** to clarify:
  - Purpose & user problem
  - Success criteria
  - Scope & constraints
  - Technical considerations
  - Out of scope items

2. **Create the plan document** at `docs/plans/<date>-<name>.md`.
  - Make sure the document is unified and clear.  Always incorporate new information or changes into the body of the document, so that someone reading it later reads the information when it's most relevant.  Even after the code has been written, if you change the code, change the plan too.
  - Only write prose and maybe some short examples of code usage.  Avoid actually writing the code in the plan.
  - Write a short high-level set of tasks at the bottom of the document.  There should be less than 10 and they should be short, merely referencing the rest of the document.
  - To avoid fragmentation, always make sure questions are answered by the user, and incorporate the answers into the main sections of the document.  Use that technique to avoid "open questions" sections.
  - When we plan to make a decision _during_ plan execution, create a "Deferred Decisions" section, e.g. an experiment which determines which of two implementation options are chosen.  Each deferred decision should have 1) which task gets the information and 2) how that information will inform the decision.
    
    
3. **Critique with a subagent**: Ask a subagent to read the plan document, looking for confusing or contradictory places, and making sure that the proposed plan is congruent with the user request.  Take on board the feedback without treating it as gospel.  If the subagent is confused about something, that part of the plan definitely needs clarifying, but because it's confused, what it proposes based on its confusion may be incorrect.

4. **Present to the user**: Ask the user to review the doc, and ask any questions you still have at this point.  Any feedback or answers that they have should be incorporated into the document.

5. **Iterate** until user approves, then wait for the user to tell you explicitly to start implementation.

### 2. Execution

Load the plan's tasks into the TodoWrite tool at the start of implementation. Work one task at a time; mark each in_progress when you start and completed when it's done (don't batch).

If a task turns out to be blocked or no longer the right thing to do:
  1. Pause and consider the overall goals of the plan.  Consider minimal course changes.
  2. Ask before changing course under these two circumstances:
    - When changing course would change the plan's scope, skip a task the user explicitly asked for, add a task the user didn't, or pick a different technical approach than the plan specified. Small deviations (renaming a variable, restructuring a helper) don't need a check-in.
    - When a task is blocked on something outside your control. Mark it blocked in the todo list and surface it to the user rather than silently moving on.
  3. Update the plan doc after deciding on the new course.  Update Todo tasks if the Plan tasks change.
  4. Continue executing tasks.

## Coding Style

Follow the [Ruby Style Guide](https://rubystyle.guide/) for all Ruby code. Here are the key principles:

### Context-Specific Guides and Skills First

**BEFORE** writing code that might touch these areas, **ALWAYS CHECK** the relevant guide in `.claude/rules/`:

- Writing or fixing tests → Employ using-tests skill.
- Authoring or updating Playwright tests → Read the global skill for playwright-testing.
- Committing → Read pre-commit guide.

These guides contain critical patterns and common mistakes that will save you time and prevent bugs.

### Code Clarity

- Prefer conceptual simplicity.
- Prefer clear, descriptive variable and method names over comments
- AVOID COMMENTS. Code that requires a comment may be too confusing.
- Break down complex expressions into intermediate variables
- Keep methods small and focused on a single responsibility
- When modifying code that might have other callers/users, first look at what those callers/users are doing.  You might be able to simplify things a lot by making small changes to them too, or by discovering there are no callers/users.
- Be confident about improving APIs -- there are no external customers, we can find every call site, no backwards compatibility needed.

### Style Enforcement

- Run `mise rubocop` to check for style violations
- Fix all Rubocop offenses before committing
- Document any necessary Rubocop exceptions with inline comments

### Key Conventions

- Prefer to use double quotes (") instead of single quotes (') for strings.  Rubocop will enforce this.
- Use `&&/||` for boolean expressions, avoid `and/or`
- Prefer string enums over validations for fields with finite options.

### String Enums

For finite-value fields, use Rails enums instead of validations:
`enum :status, { pending: 'pending', running: 'running', ... }`

This gives you predicate methods (`status.pending?`) and scopes (`Model.pending`) for free.

## Testing

Ensure adequate test coverage when authoring or changing code.  Write a failing test before writing code to fix it.

**See using-tests skill when writing or running tests.**


## Directory Structure

Standard Rails Engine layout, to be packaged as a gem.

## Mise (Tool Version Management)

This project uses mise-en-place to control the versions of the tools we're using. This needs to be invoked explicitly for many shell commands to get the paths right (editor environments are a hassle to get right so this is our solution).

### Use Mise For All Commands

Run project tasks as `mise <task>` (e.g. mise rspec, mise check:rubocop). Run arbitrary commands through the toolchain with `mise exec --  <cmd>`. Task list: `.claude/rules/mise.md`.

## Pre-Commit Checklist

See .claude/rules/pre-commit.md — short version: `mise prettier; mise ci`.

### Commit Message Quoting

Don't pass multi-line commit messages via `git commit -m "$(cat <<'EOF' ... EOF)"`. The Bash tool wraps commands in a way that breaks on apostrophes and backticks inside the heredoc body, and you'll burn a turn on a syntax error. Instead, write the message to `tmp/commit-msg.txt` with the Write tool, then `git commit -F tmp/commit-msg.txt && rm tmp/commit-msg.txt`.

## Subagent Gotchas

- Always use a local directory such as `./tmp` for temporary files.  Permissions work better that way.  Do not use system '/tmp', it will fail.

### Component Development

- Components are located in `app/javascript/components/`
- Use TypeScript for component development
- No framework yet.
