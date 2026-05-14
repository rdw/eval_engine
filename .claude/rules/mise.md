---
description: Use when running development tasks, tests, or code quality checks via mise
---

# Mise

This project uses mise-en-place to control the versions of the tools we're using. This needs to be invoked explicitly for many shell commands to get the paths right (editor environments are a hassle to get right so this is our solution).

## Development Tasks

### Testing

- `mise rspec` - Run RSpec tests, use as a prefix when trying to execute a single test, e.g. `mise rspec spec/<file_within_spec_directory>.rb`
- `mise vitest` - Run JavaScript tests

### Development

- `mise dev` - Start development server
- `mise console` - Open Rails console
- `mise script` - Run Rails runner (e.g., `mise script script/my_script.rb`)
- `mise switched` - Setup after switching branches (install deps, migrate DB)

### Code Quality

- `mise rubocop` - Run Rubocop with auto-correct
- `mise check:tsc` - TypeScript type checking
- `mise eslint` - ESLint with auto-fix
- `mise prettier` - Format code with Prettier
- `mise ci` - Run all checks and tests (rubocop, eslint, tsc, brakeman, vitest, rspec)
- `mise prepre` - Run prettier and vitest first, then `mise ci`. Use this before committing.

## Other Commands

For an arbitrary command that doesn't have its own task, run it with the prefix `mise exec --`. You only need to do this for commands that invoke Ruby or Node or whatever tools we're depending on, but it will not hurt if you run normal unix commands through it.

Examples:

- `mise exec -- bundle install`
- `mise exec -- bundle add <gem>`
- `mise exec -- uv run <python stuff>`
