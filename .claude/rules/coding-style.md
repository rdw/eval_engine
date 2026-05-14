---
description: Use when writing or reviewing Ruby and Rails code
---

# STYLE

Follow the [Ruby Style Guide](https://rubystyle.guide/) for all Ruby code. Here are the key principles:

## Code Clarity

- Prefer clear, descriptive variable and method names over comments
- AVOID COMMENTS. Code that requires a comment may be too confusing.
- Break down complex expressions into intermediate variables
- Keep methods small and focused on a single responsibility

### Example

#### Bad:

````ruby
# Extract json content if wrapped in a code block.
json_re = /```json\n(.*)\n```/m
msg.content.match?(json_re) ? JSON.parse(json_re.match(msg.content)[1]) : JSON.parse(msg.content)
````

#### Good:

````ruby
def unwrap_json_block(s)
  json_re = /```json\n(.*)\n```/m
  s = json_re.match(s)[1] if s.match?(json_re)
  JSON.parse(s)
end

unwrap_json_block(msg.content)
````

## Style Enforcement

- Run `mise rubocop` to check for style violations
- Fix all Rubocop offenses before committing
- Document any necessary Rubocop exceptions with inline comments

## Key Conventions

- Use two-space indentation (no tabs)
- Use `snake_case` for methods and variables
- Use `CamelCase` for classes and modules
- Prefer to use double quotes (") instead of single quotes (') for strings.
- Use `&&/||` for boolean expressions, avoid `and/or`
- Prefer string enums over validations for fields with finite options.

### String Enums

When a field has a finite set of possible values, use Rails string enums instead of validations:

#### Bad:

```ruby
validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

def completed?
  status == 'completed'
end

def failed?
  status == 'failed'
end
```

#### Good:

```ruby
enum :status, { pending: 'pending', running: 'running', completed: 'completed', failed: 'failed' }
# Automatically provides: pending?, running?, completed?, failed? methods
```

**Benefits:**

- Automatic predicate methods (`status.completed?`, `status.failed?`, etc.)
- Better performance (no validation overhead)
- Cleaner, more Rails-idiomatic code
- Built-in scopes (e.g., `Model.completed`, `Model.failed`)

For more details, refer to the [Ruby Style Guide](https://rubystyle.guide/).
