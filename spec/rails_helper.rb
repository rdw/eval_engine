require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"

require "rspec/rails"

ActiveRecord::Migrator.migrations_paths = [
  File.expand_path("../spec/dummy/db/migrate", __dir__),
  File.expand_path("../db/migrate", __dir__)
]

ActiveRecord::MigrationContext.new(ActiveRecord::Migrator.migrations_paths).migrate

# Force sequential execution in specs so transactional fixtures contain all DB writes.
# Worker threads check out separate AR connections that wouldn't roll back with the test.
EvalEngine.configuration.parallelism = 1

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # rspec-rails only wraps typed specs (model/request/etc.) in transactions.
  # Wrap untyped specs (spec/lib/...) too so DB writes roll back between examples.
  config.around(:each) do |example|
    if example.example_group.include?(ActiveRecord::TestFixtures)
      example.run
    else
      ActiveRecord::Base.transaction do
        example.run
        raise ActiveRecord::Rollback
      end
    end
  end
end
