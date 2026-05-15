source "https://rubygems.org"

ruby file: '.ruby-version'

# Specify your gem's dependencies in eval_engine.gemspec.
gemspec

gem "rails", "~> 8.1"

gem "puma"

gem "sqlite3"

gem "propshaft"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Tests
  gem "rspec-rails", "~> 8.0"
  gem "rspec-expectations"

  # Debugging
  gem "pry", "~> 0.15.2"

  # Code formatting
  gem "syntax_tree", "~> 6.2"

  # Security auditing
  gem "bundler-audit", "~> 0.9.2"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "solargraph", "~> 0.59.0"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "factory_bot_rails", "~> 6.4"
  gem "database_cleaner-active_record", "~> 2.2"
end

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
