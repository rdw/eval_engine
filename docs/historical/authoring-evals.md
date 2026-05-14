---
name: authoring-evals
description: Use when creating or modifying eval modules for testing LLM prompts or web scraping - ensures deterministic eval structure with proper inputs, expected outputs, and matchers. Run evals multiple times during authoring to verify quality (costs apply). For running evals, use using-evals skill.
---

# Authoring Evals

## Overview

**Eval modules test non-deterministic code (LLM prompts, web scraping) by comparing actual vs. expected outputs using matchers.** They must be deterministic and run multiple times during authoring.

**REQUIRED BACKGROUND:** See `.cursor/rules/eval_module_guide.mdc` for detailed patterns and file structure.

## When to Use

**Create eval when ALL of these are true:**
- Code has non-deterministic outputs (LLM, web scraping)
- Code will be used in production or maintained over time
- Regressions would be costly to discover later
- You'll make future changes that could break behavior

**Don't create for:**
- Deterministic code (use unit tests instead)
- Exploratory/prototype code that won't be deployed
- Debugging investigations (throw away after fixing)
- Code that will be deleted soon

**Decision metric:** Ask "Will I run this eval again in 3 months?" If no, skip it.

## Critical Requirements

### Must Be Deterministic

❌ **NEVER:** Database queries, uncached web requests, random numbers, time-based logic

✅ **ALWAYS:**
- `WebScraper.with_cache(Eval::PromptEvaluator.cache_dir('module_name'))`
- LLM temperature 0.0
- Sort array results: `result.sort_by { |item| item[:key] }`

### Run Multiple Times

**IMPORTANT:** Run eval 3+ times during authoring to verify consistency. LLM costs apply but this is essential for quality.

Workflow: Write → Run → Review scores → Refine → Run again → Repeat until stable

## Quick Reference

### Directory Structure
```
eval/
  module_name_eval.rb              # Implementation
  files/module_name_eval/
    inputs.yaml         # Test cases
    expected.yaml       # Expected outputs
    current.yaml        # Auto-generated results
    cache/             # Auto-created cache
```

### Module Implementation
```ruby
module Eval::ModuleNameEval
  def self.get_key(input)
    input["id"] || input.to_s
  end

  def self.generate(input)
    cache_dir = Eval::PromptEvaluator.cache_dir('module_name')
    result = WebScraper.with_cache(cache_dir) do
      YourClass.process(input)
    end
    result.sort_by { |i| i[:key] } if result.is_a?(Array)
    result
  end

  def self.matcher
    Eval::Matcher.boolean  # See Matcher Reference
  end
end
```

### File Formats

**inputs.yaml:**
```yaml
---
- "simple string input"
- id: example1
  data: "complex input"
```

**expected.yaml:**
```yaml
---
- key: example1
  result: { field: "expected value" }
```

## Matcher Reference

| Matcher | Use When | Example |
|---------|----------|---------|
| `boolean` | True/false results | Binary decisions |
| `integer(tolerance: N)` | Numbers, counts | IDs, quantities |
| `float(tolerance: N)` | Decimals | Prices, percentages |
| `fixed_string` | Exact text match | URLs, codes |
| `soft_string` | Fuzzy text match | LLM-generated text |
| `array(matcher)` | Ordered lists | Rankings, sequences |
| `unordered_array(matcher, key_proc:)` | Unordered lists | Sets, collections |
| `fixed_hash({field: matcher}, indifferent: true)` | Structured data | Objects, records |

**Weights:** All matchers support `weight: N` for importance tuning.

**Custom matchers:** If no matcher fits, STOP and discuss with user via AskUserQuestion.

### Common Matcher Patterns

```ruby
# LLM prompt output
Eval::Matcher.fixed_hash({
  answer: Eval::Matcher.soft_string,
  reasoning: Eval::Matcher.soft_string
}, indifferent: true)

# Web scraping
Eval::Matcher.fixed_hash({
  title: Eval::Matcher.soft_string,
  price: Eval::Matcher.float(tolerance: 0.01)
}, indifferent: true)

# Array of objects
Eval::Matcher.unordered_array(
  Eval::Matcher.fixed_hash({
    id: Eval::Matcher.integer,
    name: Eval::Matcher.soft_string
  }, indifferent: true),
  key_proc: ->(item) { item[:id] }
)
```

## Caching Strategies

Use caching when accessing websites, to keep things deterministic. Choose one of two based on what the code needs:

### `WebScraper.with_cache` — HTML-only caching

Caches raw HTML responses in a simple file-per-URL format. Use when:
- Your eval only needs HTML content (no JavaScript rendering required)
- You use `WebScraper#process` to fetch pages

```ruby
WebScraper.with_cache(Eval::PromptEvaluator.cache_dir("my_module")) do
  scraper_page = WebScraper.new.process(url)
  MyPrompt.new.run(scraper_page)
end
```

### `WebScraper.with_billy_cache` — Full HTTP proxy caching (recommended for new evals)

Caches ALL HTTP requests (HTML, JS, CSS, images, API calls) as YAML files via a
local proxy. Playwright routes through this proxy, so pages render fully from cache.
Use when:

- You need a live Playwright `Page` object (e.g., for `getBoundingClientRect()`)
- The page uses JavaScript to load content
- You want rectangle/position data for images or elements
- You use `WebScraper#scrape_page` (returns a `Scraper::WebPage` with `.page`)

```ruby
WebScraper.with_billy_cache(Eval::PromptEvaluator.cache_dir("my_module")) do
  scraper_page = WebScraper.new.scrape_page(url)
  MyPrompt.new.run(scraper_page)  # scraper_page.page is a live Playwright page
end
```

**Key difference**: `with_billy_cache` + `scrape_page` provides `scraper_page.page` (a
Playwright `Page` object). Pass it as the first argument to extract images:
`HtmlImageExtractor.extract_images_with_context(scraper_page.page, ancestor_levels: N)`.

#### Cache file format

Billy stores one YAML file per URL, named `get_{host}_{sha1}.yml`:

```
eval/files/my_module_eval/cache/
  get_example.com_abc123.yml   # HTML response
  get_cdn.example.com_def456.yml  # Image/asset responses
```

#### Gotchas

- **IPv4 only**: Billy binds to `127.0.0.1`, not `localhost` (macOS resolves
  `localhost` to `::1` first). This is handled automatically — no action needed.
- **HTTPS**: Chromium is launched with `--ignore-certificate-errors` to accept
  Billy's self-signed MITM certificates for HTTPS pages.
- **First run is live**: The first eval run fetches live pages and populates cache.
  Subsequent runs replay from cache without network access.
- **Cache migration**: Existing evals using `with_cache` (FileContentCache) have
  separate `.html` cache files in a different format. They won't automatically use
  Billy's YAML cache — migration requires a re-scrape.



## Common Mistakes

### 1. Cache Directory
❌ `Rails.root.join("eval", "files", "my_eval", "cache")`
✅ `Eval::PromptEvaluator.cache_dir('my')`

### 2. RubyLLM API
❌ `RubyLLM.chat(messages: [...], system: "...")`
✅ `RubyLLM.chat.with_instructions("...").with_temperature(0.0).ask_retry("...")`

### 3. Response Parsing
❌ `response[:content]`
✅ `response.content`

### 4. Array Sorting
❌ `MyClass.get_results(input)` (order varies)
✅ `MyClass.get_results(input).sort_by { |i| i[:name] }`

## Authoring Workflow

1. **Create module** (`eval/module_name_eval.rb`) with get_key, generate, matcher
2. **Create inputs.yaml** with 3-5 test cases
3. **Run:** `mise eval module_name --run`
4. **Review current.yaml** outputs
5. **Create expected.yaml** from current.yaml structure
6. **Run and refine:** `mise eval module_name --run --debug`
7. **Iterate** 2-3+ times until scores are stable
8. **Promote:** `mise eval module_name --promote`

## Best Practices

1. Include diversity of test cases in `inputs.yaml`
2. Update `expected.yaml` whenever the expected behavior changes
3. Use `checkpoint.yaml` to track performance over time
4. Cache external requests using `WebScraper.with_billy_cache` for evals that will need a live Playwright page, or
   `WebScraper.with_cache` for code that only looks at the HTML
5. **ALWAYS** use `Eval::PromptEvaluator.cache_dir('your_module_name_eval')` to get the correct cache directory path - never construct it manually
6. Sort array results in `generate()` for consistent comparison (e.g., `result.sort_by { |item| item[:name] }`)
7. Use `unordered_array` matcher for arrays where order doesn't matter

## See Also

- **using-evals skill**: Running evals and interpreting scores
- `lib/eval/matcher.rb`: Matcher source code
