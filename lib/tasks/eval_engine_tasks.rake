namespace :eval_engine do
  namespace :install do
    Rake::Task["eval_engine:install:migrations"].clear if Rake::Task.task_defined?("eval_engine:install:migrations")

    desc "Copy EvalEngine migrations to the host app. Override destination with MIGRATIONS_PATH=db/evals_migrate."
    task migrations: :environment do
      source = EvalEngine::Engine.paths["db/migrate"].existent.first
      destination = ENV["MIGRATIONS_PATH"] || ActiveRecord::Tasks::DatabaseTasks.migrations_paths.first || "db/migrate"

      on_skip = ->(name, m, *) { puts "NOTE: Migration #{m.basename} from #{name} skipped (already exists)." }
      on_copy = ->(name, m, *) { puts "Copied #{m.basename} from #{name} to #{destination}/." }

      copied = ActiveRecord::Migration.copy(destination, { "eval_engine" => source }, on_skip:, on_copy:)

      puts "No new migrations to copy." if copied.empty?
    end
  end
end
