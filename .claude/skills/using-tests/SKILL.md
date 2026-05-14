---
name: using-tests
description: Use when writing, modifying, or debugging RSpec tests in this project - covers let/let! usage, assertion style, request specs, stubbing, and a matcher cheat sheet
---

# Using Tests

Tests are written in RSpec and located in the `spec/` directory.

## Running Tests

```bash
# Run all tests
mise rspec

# Run specific test file
mise rspec spec/test_spec.rb

# Run specific example
mise rspec spec/test_spec.rb:42
```

## Key Testing Principles

- ALWAYS FIX TEST FAILURES BEFORE CONCLUDING. It's wise to fix test failures as soon as they're discovered. It's possible they were preexisting, but, too bad, they're on your plate now!
- DO NOT fix test failures by weakening the assertions without very good evidence. Assertions are the core value of automated tests, so if you broaden or remove them it's undercutting the value of the entire test.
- Write failing tests before writing code for a task.
- Write tests for all public methods and test edge cases
- Keep tests focused and independent
- Use descriptive example names
- Split overly large test files into smaller, focused files

## Test first

 Write tests for the expected behavior *before* writing the implementation, and run them to confirm they fail **for the reason you expect**. If a new test passes before you've written any code, it isn't asserting the new behavior — fix the test before proceeding.
 
 Treat the tests as documentation.  Write APIs in a composable way, that makes the usage obvious.  Reinforce intended behaviors by adding tests with a it- or context-string describing *why* it should behave that way.
 
 Add *more* tests after implementation, once internal corner cases surface.
  
**Why:**

- Forces you to use the API from the caller's side before you commit to a shape. The code tends to come out more composable.
- Tests that exist before the code can't be forgotten after.

**Exploratory exception.** For work where you genuinely don't know the output shape yet (new scraper, prompt whose response format you're still discovering), prototype first to learn the contract — but tests must land in the same commit as the code, not as a follow-up. The exception reorders test-writing; it does not skip it.

**Not an exception:** "the setup is hard" — if setup is hard, fix it once (factory, harness, fixture), and test-first stays cheap afterward.

## Using let and let!

Use Rspec's `let/let!` functions to create objects used for multiple tests.

```ruby
let(:product) { create(:product) }
```

Prefer `let`, in test cases that directly use that variable in the first line

```ruby
it "has a name" do
  expect(product.name).to be_present
end
```

If you need to call a function or add an assertion that needs the variable to exist, switch to `let!`. This will force the variable to be created before the `it` block is entered.

```ruby
let!(:product) { create(:product) }
it "finds the product" do
  expect(Researcher.find('products').first).to eq product
end
```

DON'T force the variable to exist by referring to it in the test.

```ruby
it "finds the product" do
  product  # BAD
  expect(Researcher.find('products').first).to eq product
end
```

DON'T use a before block either.

```ruby
before { product }  # BAD
it "finds the product" do
  expect(Researcher.find('products').first).to eq product
end
```

## String Assertions

Prefer one `expect(result).to eq ...` over having multiple `expect(result).to include ...` asserts. The latter can produce false negatives when the result mixes up the ordering or adds extra text.

### Bad Example

```ruby
expect(result).to include('## Media Gallery')
expect(result).to include('![Photo 1](photo1.jpg)')
```

### Good Example

```ruby
expect(result).to eq "## Media Gallery\n![Photo 1](photo1.jpg"
```

## Object Attribute Assertions

When testing multiple attributes of an ActiveRecord object, prefer `have_attributes` over multiple individual expectations:

### Bad:

```ruby
expect(job_log.job_handle).to eq(job_handle)
expect(job_log.model).to eq(manufacturer)
expect(job_log.status).to eq('completed')
expect(job_log.error_message).to be_nil
```

### Good:

```ruby
expect(job_log).to have_attributes(
  job_handle: job_handle,
  model: manufacturer,
  status: 'completed',
  error_message: nil
)
```

**Note:** `have_attributes` only works with ActiveRecord objects.

## Hash Content Assertions

For hash objects, use the `include` matcher:

### Bad:

```ruby
expect(scheduled_jobs.first[:job_class]).to eq(ManufacturerJob)
expect(scheduled_jobs.first[:arguments]).to eq([manufacturer.id])
expect(scheduled_jobs.first[:reason]).to eq('never_run')
```

### Good:

```ruby
expect(scheduled_jobs.first).to include(
  job_class: ManufacturerJob,
  arguments: [manufacturer.id],
  reason: 'never_run'
)
```

## Avoiding `allow_any_instance_of`

**Avoid `allow_any_instance_of`** - instead, stub the class's `new` method to return a double.

### Bad:

```ruby
allow_any_instance_of(Prompts::ManufacturerDiscoveryAgent).to receive(:run).and_return(discovered_manufacturers)
```

### Good:

```ruby
allow(Prompts::ManufacturerDiscoveryAgent).to receive(:new).and_return(double("manufacturer_discovery_agent", run: discovered_manufacturers))
```

### When you control instantiation of the object under test

If you're testing a class and need to stub one of its own methods, instantiate it yourself and stub on that instance directly:

```ruby
let(:job) { described_class.new }
before { allow(job).to receive(:some_method).and_return(value) }
it "..." do
  job.perform(...)
end
```

This is preferable to `allow_any_instance_of` because the stub is scoped to a known instance rather than applied globally.

### Other Options

- Consider refactoring the code under test to avoid the need for stubbing entirely. E.g. if a function would have some logic, then use a prompt, then process the results of the prompt, consider splitting that into three functions so the pre-prompt logic and the post-prompt logic can each be tested without stubbing.

## RSpec Cheat Sheet

### Equality

`expect(5).to eq value   # 5 == value`
`expect(5).to eql value   # 5.eql?(value)`
`expect(5).to equal value   # 5.equal?(value)`

### Numeric

`expect(5).to be < 6`
`expect(5).to == 5`
`expect(5).to be_between(4, 6).exclusive`
`expect(5).to be_between(5, 6).inclusive`
`expect(5).to be_within(0.05).of value`

### Objects

`expect(obj).to be_an_instance_of MyClass`
`expect(obj).to be_a_kind_of MyClass`
`expect(obj).to respond_to :save!`
`expect(obj).to have_attributes({ id: 1 })`

### Strings

`expect("derp").to start_with('d')`
`expect("derp").to end_with('p')`

### Arrays

`expect([2, 1]).to contain_exactly(1, 2)`
`expect([2, 1]).to match_array([1, 2])`
`expect([1, 2, 3]).to include(2)`

### Hashes

`expect({a: 1}).to have_key(:a)   # {a: 1}.has_key?(:a)`
`expect({a: 1}).to have_value(1)  # {a: 1}.has_value?(1)`
`expect({a: 1}).to include({a : 1})`

### Nesting

`expect({ a: [2, 1]}).to include({ a: an_array_matching([1, 2])})`
Also:
include: a_collection_including, a_string_including, a_hash_including, including
have_attributes: an_object_having_attributes
start_with: a_collection_starting_with, a_string_starting_with, starting_with
contain_exactly: a_collection_containing_exactly, containing_exactly

### Errors

`expect { user.save! }.to raise_error`
`expect { user.save! }.to raise_error(ExceptionName, /msg/)`
`expect { user.save! }.to throw :symbol`

### Predicate

`expect(x).to be_zero    # FixNum#zero?`
`expect(x).to be_empty   # Array#empty?`
`expect(x).to be_nil`

### Booleans

`expect(true).to be true`
`expect(false).to be false`
`expect('abc').to be_truthy`
`expect(nil).to be_falsey`
`expect(nil).to be_nil`

### Change Observation

`expect{ widget.has_cliche_name? }.not_to change(widget, :name)`
`expect{ widget.fifty_percent_off! }.to change(widget, :cost) # 80 -> 40`
`expect{ widget.fifty_percent_off! }.to change(widget, :cost).from(40).to(20)`
`expect{ widget.fifty_percent_off! }.to change(widget, :cost).by(-10) # 20 -> 10`
`expect { object.action }.to change(object, :value).by_at_least(minimum_delta)`
`expect { object.action }.to change(object, :value).by_at_most(maximum_delta)`

### Output

`expect{ puts 'hi' }.to output("hi\n").to_stdout`
`expect{ $stderr.puts 'hi' }.to output("hi\n").to_stderr`

## Request Specs

**Use request specs instead of controller specs** - RSpec has moved from controller specs to request specs for testing controllers and views. Request specs provide better integration testing by going through the full Rails stack including routing and middleware.

### When to Use Request Specs

- **Controller actions** - Test that controller actions work correctly
- **View rendering** - Test that views render without errors
- **HTTP responses** - Test status codes, redirects, and response content
- **Full stack integration** - Test the complete request/response cycle

### Request Spec Structure

```ruby
require "rails_helper"

RSpec.describe "ControllerName", type: :request do
  describe "GET /action" do
    it "renders the view successfully" do
      get "/path"
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:action_name)
    end

    it "redirects to correct path" do
      post "/path", params: { model: { attribute: "value" } }
      expect(response).to redirect_to(model_path(assigns(:model)))
    end
  end
end
```

### Key Request Spec Matchers

- `expect(response).to have_http_status(:success)` - Test HTTP status codes
- `expect(response).to render_template(:action_name)` - Test view rendering
- `expect(response).to redirect_to(path)` - Test redirects
- `expect(response.body).to include("text")` - Test response content
- `expect(assigns(:variable)).to eq(value)` - Test instance variables

### View Rendering Tests

**Always test that views render without errors** for main pages (not partials):

```ruby
it "renders the index view" do
  get "/manufacturers"
  expect(response).to have_http_status(:success)
  expect(response).to render_template(:index)
end

it "renders the show view" do
  manufacturer = create(:manufacturer)
  get "/manufacturers/#{manufacturer.id}"
  expect(response).to have_http_status(:success)
  expect(response).to render_template(:show)
end
```

### Request Spec Best Practices

- **Test both success and error cases** - HTTP status codes, view rendering, redirects
- **Use descriptive example names** - "renders the view successfully", "redirects to correct path"
- **Test with realistic data** - Use factories to create test data
- **Group related tests** - Use `describe` blocks for different actions
- **Test edge cases** - Invalid parameters, missing records, authorization failures
- **Test ActiveJob failure cases and retries** - Use rspec-rails matchers: https://rspec.info/features/6-1/rspec-rails/job-specs/job-spec/

### File Organization

- **Location**: `spec/requests/`
- **Naming**: `controller_name_spec.rb` (e.g., `manufacturers_spec.rb`)
- **Admin controllers**: `spec/requests/admin/controller_name_spec.rb`

### Common Request Spec Patterns

```ruby
# Testing with parameters
get "/path", params: { filter: "value" }

# Testing with headers
get "/path", headers: { "ACCEPT" => "application/json" }

# Testing POST requests
post "/path", params: { model: { attribute: "value" } }

# Testing with authentication
before { sign_in user }
get "/protected_path"

# Testing error responses
it "returns 404 for missing record" do
  get "/manufacturers/999999"
  expect(response).to have_http_status(:not_found)
end
```

## Coverage

- Aim for 100% test coverage, but don't put in heroic effort to get over 98%.
- Run `mise rspec --format documentation` for detailed output
- Use `--tag focus` to run specific examples

## Debugging Test Failures

When tests fail, first check if the failure message provides a clear indication of the problem (e.g. syntax errors, undefined methods, or clear expectation mismatches). In these cases, the solution is often obvious and can be implemented directly.

However, if any of these are true:

- You've attempted a fix that seemed correct but didn't resolve the failure
- The test output shows unexpected values but the reason isn't clear
- Multiple components interact to produce the test result
- The failure seems associated with a different component than the one you're working on or testing

Then use print debugging to understand the system's behavior:

1. Add strategic `puts` statements to show:
   - Input values at key decision points
   - Intermediate calculation results
   - State changes and transformations
   - Final values before assertions
   - Make sure each statement has a unique textual output so you can quickly identify from the output where to look in the source.
2. Run the specific failing test (use line numbers for precision)
3. Analyze the output to understand the actual flow vs. expected behavior
4. After fixing the issue, remember to remove the debug statements. One good way to do this is to run the tests and look for any output other than the rspec output. Rspec prints a series of dots and then "Finished in X seconds". If there is any output interspersed amongst the dots, it indicates a rogue print statement.

Example:

```ruby
def calculate_score
  puts "\nInputs: value=#{value}, threshold=#{threshold}"
  result = complex_calculation
  puts "Intermediate result: #{result}"
  final = apply_weights(result)
  puts "Final value: #{final}"
  final
end
```
