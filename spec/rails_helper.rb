require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"

require "rspec/rails"

ActiveRecord::Migrator.migrations_paths = [
  File.expand_path("../spec/dummy/db/migrate", __dir__),
  File.expand_path("../db/migrate", __dir__)
]

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
